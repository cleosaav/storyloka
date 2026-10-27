import 'package:flutter/foundation.dart';

/// Circuit breaker sederhana di memori untuk rantai penyedia AI — Fase S1.
///
/// Kebijakan:
/// - Penyedia yang gagal karena auth/config/402 di-skip selama 10 menit.
/// - Penyedia yang gagal sementara (5xx / 429 berulang) di-skip selama 60 detik.
/// - State hanya disimpan di memori dan di-reset saat aplikasi dibuka ulang.
class CircuitBreaker {
  CircuitBreaker._();

  static final Map<String, DateTime> _trippedUntil = {};

  /// Cek apakah penyedia dengan [providerId] sedang aktif (tidak dalam cooldown).
  static bool isAvailable(String providerId, {DateTime? now}) {
    final until = _trippedUntil[providerId];
    if (until == null) return true;
    final currentTime = now ?? DateTime.now();
    if (currentTime.isAfter(until)) {
      _trippedUntil.remove(providerId);
      return true;
    }
    return false;
  }

  /// Catat kegagalan penyedia dan tentukan durasi cooldown.
  static void recordFailure(
    String providerId, {
    required bool isAuthConfigOrBalance,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final duration = isAuthConfigOrBalance
        ? const Duration(minutes: 10)
        : const Duration(seconds: 60);
    final cooldownUntil = currentTime.add(duration);
    _trippedUntil[providerId] = cooldownUntil;
    if (kDebugMode) {
      debugPrint(
        '[CircuitBreaker] Provider "$providerId" masuk cooldown '
        'selama ${duration.inSeconds} detik (hingga $cooldownUntil).',
      );
    }
  }

  /// Catat keberhasilan penyedia untuk menghapus status cooldown.
  static void recordSuccess(String providerId) {
    _trippedUntil.remove(providerId);
  }

  /// Reset seluruh status circuit breaker di memori.
  static void reset() {
    _trippedUntil.clear();
  }

  @visibleForTesting
  static Map<String, DateTime> get snapshot => Map.unmodifiable(_trippedUntil);
}
