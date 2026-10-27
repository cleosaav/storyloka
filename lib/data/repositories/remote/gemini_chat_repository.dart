import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../database_helper.dart';
import '../../models/chat_message.dart';
import '../chat_repository.dart';
import 'ai_chat_exception.dart';

/// Exception khusus untuk kesalahan layanan Gemini AI — Fase R3 & S1.
class GeminiChatException extends AiChatException {
  GeminiChatException(
    super.message, {
    super.statusCode,
    super.retryAfter,
    super.isTimeout = false,
    super.isSocket = false,
    String? modelName,
  }) : super(providerName: modelName != null ? 'Gemini ($modelName)' : 'Gemini');
}

/// Implementasi nyata ChatRepository menggunakan Google Gemini REST API — PRD §9.3, Fase R3, & S1.
class GeminiChatRepository implements ChatRepository {
  final http.Client _client;
  final DatabaseHelper _dbHelper;
  final Future<String> Function()? userIdProvider;
  final String? apiKey;
  final String? model;
  static const _uuid = Uuid();

  static const String _systemPrompt =
      'Kamu adalah asisten StoryLoka, teman membaca yang ramah. Bantu pengguna '
      'dengan rekomendasi buku, ringkasan, penjelasan tema/penulis, dan tips membaca. '
      'Jawab dengan bahasa yang dipakai pengguna, ringkas dan jelas. Jika pertanyaan '
      'di luar topik buku/membaca, tolak dengan sopan dan arahkan kembali. Jangan '
      'mengarang judul, penulis, atau fakta; jika tidak yakin, katakan tidak yakin.';

  GeminiChatRepository({
    http.Client? client,
    DatabaseHelper? dbHelper,
    this.userIdProvider,
    this.apiKey,
    this.model,
  })  : _client = client ?? http.Client(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  String get activeModel {
    final candidate = (model != null && model!.trim().isNotEmpty)
        ? model!.trim()
        : Env.geminiModel.trim();
    return candidate.isNotEmpty ? candidate : 'gemini-3.5-flash-lite';
  }

  String get id => 'gemini:$activeModel';
  String get displayName => 'Gemini ($activeModel)';

  Future<String> _getUserId() async {
    final provider = userIdProvider;
    if (provider != null) {
      final id = await provider();
      if (id.isNotEmpty && id != 'default_user' && id != 'demo_user' && id != 'demo') {
        return id;
      }
    }
    throw StateError('NO_AUTHENTICATED_USER: Sesi pengguna tidak ditemukan.');
  }

  /// Mengambil daftar model yang didukung Gemini API — Fase R3 & S1.
  Future<List<String>> listAvailableModels({required String apiKey}) async {
    final listModelsUri =
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models');
    final response = await _client.get(
      listModelsUri,
      headers: {'x-goog-api-key': apiKey},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final modelsList = json['models'] as List<dynamic>? ?? [];
    return modelsList
        .map((m) =>
            (m as Map)['name']?.toString().replaceFirst('models/', '') ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    void Function(String status)? onStatusUpdate,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = (apiKey ?? Env.geminiApiKey).trim();
    if (key.isEmpty) {
      throw GeminiChatException(
        'Kunci ditolak, periksa GEMINI_API_KEY. Konfigurasi AI belum benar.',
        statusCode: 401,
        modelName: activeModel,
      );
    }

    final targetModel = activeModel;
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$targetModel:generateContent',
    );

    // Batasi maksimal 10 riwayat pesan terakhir sebagai konteks percakapan — PRD §9.3
    final recentHistory =
        history.length > 10 ? history.sublist(history.length - 10) : history;

    final contents = <Map<String, dynamic>>[];
    for (final chat in recentHistory) {
      contents.add({
        'role': chat.role == 'model' ? 'model' : 'user',
        'parts': [
          {'text': chat.content}
        ],
      });
    }

    // Tambahkan prompt pengguna saat ini jika belum ada di history
    if (contents.isEmpty ||
        contents.last['role'] != 'user' ||
        contents.last['parts'][0]['text'] != message) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ],
      });
    }

    final requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 800,
      },
    };

    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'x-goog-api-key': key,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      final retryAfter = parseRetryAfter(response.headers['retry-after']);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // Cek pemblokiran promptFeedback (SAFETY)
        final promptFeedback =
            json['promptFeedback'] as Map<String, dynamic>?;
        final blockReason = promptFeedback?['blockReason'] as String?;
        if (blockReason != null && blockReason.toUpperCase() == 'SAFETY') {
          return 'Maaf, pertanyaan tidak dapat diproses karena terdeteksi mengandung konten sensitif. Silakan tanyakan hal lain seputar buku.';
        }

        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        final firstCandidate = candidates[0] as Map<String, dynamic>;
        final finishReason = firstCandidate['finishReason'] as String?;
        // Respons diblokir (finishReason SAFETY) -> tampilkan pesan ramah
        if (finishReason != null && finishReason.toUpperCase() == 'SAFETY') {
          return 'Maaf, respons tidak dapat ditampilkan karena terdeteksi mengandung konten sensitif. Silakan tanyakan hal lain seputar buku.';
        }

        final content = firstCandidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        // Tahan banting: rangkai seluruh parts teks jika finishReason MAX_TOKENS atau chunk terpisah
        final textBuffer = StringBuffer();
        for (final p in parts) {
          if (p is Map && p['text'] != null) {
            textBuffer.write(p['text'].toString());
          }
        }
        final reply = textBuffer.toString().trim();
        if (reply.isNotEmpty) {
          return reply;
        }

        return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
      }

      // Pemetaan error kode status HTTP
      if (response.statusCode == 400) {
        throw GeminiChatException(
          'Permintaan atau format kunci tidak valid. Konfigurasi AI belum benar.',
          statusCode: 400,
          retryAfter: retryAfter,
          modelName: targetModel,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw GeminiChatException(
          'Kunci ditolak, periksa GEMINI_API_KEY. Konfigurasi AI belum benar.',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
          modelName: targetModel,
        );
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint(
            '[Gemini] Model "$targetModel" tidak ditemukan (HTTP 404). '
            'Periksa GEMINI_MODEL atau GEMINI_MODEL_FALLBACKS di .env.',
          );
        }
        throw GeminiChatException(
          'Model tidak tersedia, periksa GEMINI_MODEL di pengaturan.',
          statusCode: 404,
          retryAfter: retryAfter,
          modelName: targetModel,
        );
      } else if (response.statusCode == 429) {
        throw GeminiChatException(
          'Kuota habis, coba lagi nanti. Terlalu banyak permintaan, coba lagi sebentar.',
          statusCode: 429,
          retryAfter: retryAfter,
          modelName: targetModel,
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        throw GeminiChatException(
          'Server AI sedang sibuk (${response.statusCode}), silakan coba lagi nanti.',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
          modelName: targetModel,
        );
      } else {
        throw GeminiChatException(
          'Terjadi kesalahan pada layanan AI (${response.statusCode}).',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
          modelName: targetModel,
        );
      }
    } on TimeoutException {
      throw GeminiChatException(
        'Koneksi ke asisten AI timeout. Periksa jaringan Anda.',
        isTimeout: true,
        modelName: targetModel,
      );
    } on SocketException catch (e) {
      throw GeminiChatException(
        'Tidak ada koneksi internet. Periksa jaringan Anda: ${e.message}',
        isSocket: true,
        modelName: targetModel,
      );
    } catch (e) {
      if (e is GeminiChatException) rethrow;
      throw GeminiChatException(
        'Tidak ada koneksi internet. Periksa jaringan Anda: $e',
        modelName: targetModel,
      );
    }
  }

  @override
  Future<List<ChatMessage>> getHistory() async {
    final db = await _dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    final db = await _dbHelper.database;
    final userId = await _getUserId();

    final messageToSave = message.userId.isEmpty || message.userId == 'demo'
        ? ChatMessage(
            id: message.id.isEmpty ? _uuid.v4() : message.id,
            userId: userId,
            role: message.role,
            content: message.content,
            createdAt: message.createdAt,
          )
        : message;

    await db.insert('chat_messages', messageToSave.toMap());
  }

  @override
  Future<void> clearHistory() async {
    final db = await _dbHelper.database;
    final userId = await _getUserId();

    await db.delete(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
