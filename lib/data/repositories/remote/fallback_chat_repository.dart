import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';
import '../chat_repository.dart';
import 'ai_chat_exception.dart';
import 'circuit_breaker.dart';
import 'deepseek_chat_repository.dart';
import 'gemini_chat_repository.dart';

/// Repository AI Chat dengan rantai penyedia (Provider Chain), retry backoff,
/// dan circuit breaker in-memory — PRD §9.3 & Fase S1.
///
/// Urutan Rantai Penyedia:
/// 1. DeepSeek
/// 2. Gemini Model Utama (Env.geminiModel)
/// 3. Gemini Model Cadangan (Env.geminiModelFallbacks)
class FallbackChatRepository implements ChatRepository {
  final List<ChatRepository> providers;
  final Future<void> Function(Duration delay)? delayFn;

  FallbackChatRepository({
    required ChatRepository primary,
    required ChatRepository fallback,
    List<ChatRepository>? additionalFallbacks,
    this.delayFn,
  }) : providers = [
          primary,
          fallback,
          ...?additionalFallbacks,
        ];

  FallbackChatRepository.chain({
    required this.providers,
    this.delayFn,
  }) : assert(providers.isNotEmpty, 'Providers tidak boleh kosong.');

  ChatRepository get primary => providers.first;
  ChatRepository get fallback => providers.length > 1 ? providers[1] : providers.first;

  String _getProviderId(ChatRepository repo) {
    if (repo is DeepSeekChatRepository) return repo.id;
    if (repo is GeminiChatRepository) return repo.id;
    return repo.runtimeType.toString();
  }

  String _getProviderDisplayName(ChatRepository repo) {
    if (repo is DeepSeekChatRepository) return repo.displayName;
    if (repo is GeminiChatRepository) return repo.displayName;
    return repo.runtimeType.toString();
  }

  Duration _calculateBackoff(int attempt, Duration? retryAfter) {
    if (retryAfter != null && retryAfter > Duration.zero) {
      return retryAfter;
    }
    // 0.8s, 1.6s, 3.2s
    final baseMs = 800 * (1 << (attempt - 1));
    final random = Random();
    // Jitter +/- 15%
    final jitter = (baseMs * 0.15 * (random.nextDouble() * 2 - 1)).round();
    return Duration(milliseconds: (baseMs + jitter).clamp(400, 10000));
  }

  Future<void> _sleep(Duration d) async {
    if (delayFn != null) {
      await delayFn!(d);
    } else {
      await Future.delayed(d);
    }
  }

  bool _isOfflineException(Object e) {
    if (e is SocketException) return true;
    if (e is AiChatException && e.isSocket) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('tidak ada koneksi internet') ||
        msg.contains('network is unreachable');
  }

  bool _isAuthConfigError(Object e) {
    if (e is AiChatException) return e.isAuthConfigOrBalance;
    final msg = e.toString().toLowerCase();
    return msg.contains('konfigurasi ai belum benar') ||
        msg.contains('kunci ditolak') ||
        msg.contains('kunci deepseek tidak ditemukan') ||
        msg.contains('insufficient balance');
  }

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    void Function(String status)? onStatusUpdate,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    const maxTotalDuration = Duration(seconds: 45);
    final failures = <Object>[];

    for (var i = 0; i < providers.length; i++) {
      final provider = providers[i];
      final providerId = _getProviderId(provider);
      final providerName = _getProviderDisplayName(provider);

      // 1. Cek Circuit Breaker di memori
      if (!CircuitBreaker.isAvailable(providerId)) {
        if (kDebugMode) {
          debugPrint(
            '[ProviderChain] Provider "$providerName" sedang dalam cooldown '
            'circuit breaker. Dilewati.',
          );
        }
        continue;
      }

      // 2. Cek batas total durasi satu pesan (45 detik)
      if (overallStopwatch.elapsed >= maxTotalDuration) {
        if (kDebugMode) {
          debugPrint('[ProviderChain] Batas total 45 detik terlampaui.');
        }
        break;
      }

      var providerFailed = false;

      // 3. Kebijakan retry: maksimal 3 percobaan per penyedia
      for (var attempt = 1; attempt <= 3; attempt++) {
        final remainingTime = maxTotalDuration - overallStopwatch.elapsed;
        if (remainingTime <= Duration.zero) {
          providerFailed = true;
          break;
        }

        // Timeout percobaan maks 20 detik atau sisa waktu yang tersedia
        final attemptTimeout = remainingTime < const Duration(seconds: 20)
            ? remainingTime
            : const Duration(seconds: 20);

        try {
          if (kDebugMode) {
            debugPrint(
              '[ProviderChain] Mengirim ke "$providerName" '
              '(Percobaan $attempt/3, sisa waktu: ${remainingTime.inSeconds}s)...',
            );
          }

          final response = await (provider is DeepSeekChatRepository
              ? provider.sendMessage(
                  message,
                  history,
                  onStatusUpdate: onStatusUpdate,
                  timeout: attemptTimeout,
                )
              : provider is GeminiChatRepository
                  ? provider.sendMessage(
                      message,
                      history,
                      onStatusUpdate: onStatusUpdate,
                      timeout: attemptTimeout,
                    )
                  : provider.sendMessage(message, history));

          // Berhasil! Pulihkan circuit breaker dan kembalikan hasil
          CircuitBreaker.recordSuccess(providerId);
          return response;
        } catch (e) {
          failures.add(e);

          final isAuth = _isAuthConfigError(e);

          if (isAuth) {
            // Auth / Config / 402 error -> trip circuit breaker 10 menit dan langsung fallback tanpa retry
            if (kDebugMode) {
              debugPrint(
                '[ProviderChain] "$providerName" gagal auth/config/saldo: $e. '
                'Langsung beralih ke penyedia berikutnya.',
              );
            }
            CircuitBreaker.recordFailure(providerId, isAuthConfigOrBalance: true);
            onStatusUpdate?.call('Mencoba lagi...');
            providerFailed = true;
            break; // Jangan retry lagi untuk auth/config error
          }

          // Error sementara (5xx, 429, timeout, network)
          if (attempt < 3 && overallStopwatch.elapsed < maxTotalDuration) {
            Duration? retryAfter;
            if (e is AiChatException) retryAfter = e.retryAfter;

            final backoff = _calculateBackoff(attempt, retryAfter);
            if (kDebugMode) {
              debugPrint(
                '[ProviderChain] "$providerName" percobaan $attempt gagal ($e). '
                'Menunggu ${backoff.inMilliseconds}ms sebelum mencoba lagi...',
              );
            }
            onStatusUpdate?.call('Mencoba lagi...');
            await _sleep(backoff);
          } else {
            // Gagal setelah 3 percobaan -> trip circuit breaker 60 detik
            CircuitBreaker.recordFailure(providerId, isAuthConfigOrBalance: false);
            onStatusUpdate?.call('Mencoba lagi...');
            providerFailed = true;
            break;
          }
        }
      }

      if (providerFailed && i < providers.length - 1) {
        if (kDebugMode) {
          debugPrint(
            '[ProviderChain] Provider "$providerName" gagal sepenuhnya. '
            'Beralih ke fallback "${_getProviderDisplayName(providers[i + 1])}"...',
          );
        }
        onStatusUpdate?.call('Mencoba lagi...');
      }
    }

    // 4. Jika seluruh penyedia dalam rantai gagal, klasifikasikan error ke pengguna
    if (failures.every(_isOfflineException)) {
      throw AiChatException(
        'Tidak ada koneksi internet. Periksa jaringan Anda dan coba lagi.',
        isSocket: true,
      );
    }

    if (failures.every(_isAuthConfigError)) {
      throw AiChatException(
        'Konfigurasi AI belum benar. Periksa API key di pengaturan.',
        statusCode: 400,
      );
    }

    // Default ramah saat server/semua layanan sibuk atau timeout
    throw AiChatException(
      'Layanan AI sedang ramai, coba lagi sebentar.',
      statusCode: 503,
    );
  }

  @override
  Future<List<ChatMessage>> getHistory() => primary.getHistory();

  @override
  Future<void> saveMessage(ChatMessage message) => primary.saveMessage(message);

  @override
  Future<void> clearHistory() => primary.clearHistory();
}
