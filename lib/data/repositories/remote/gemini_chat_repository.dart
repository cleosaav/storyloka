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

/// Exception khusus untuk kesalahan layanan Gemini AI — Fase R3.
class GeminiChatException implements Exception {
  final String message;
  final int? statusCode;

  GeminiChatException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Implementasi nyata ChatRepository menggunakan Google Gemini REST API — PRD §9.3 & Fase R3.
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

  Future<String> _getUserId() async {
    final provider = userIdProvider;
    if (provider != null) {
      return await provider();
    }
    return 'default_user';
  }

  /// Mengambil daftar model yang didukung Gemini API — Fase R3 (hanya dipanggil saat 404 di debug mode).
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
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final key = (apiKey ?? Env.geminiApiKey).trim();
    if (key.isEmpty) {
      throw GeminiChatException(
        'Kunci ditolak, periksa GEMINI_API_KEY. Konfigurasi AI belum benar.',
      );
    }

    // 1. Pakai Env.geminiModel apa adanya. Default tetap 'gemini-3.5-flash-lite' — Fase R3 & R4
    final modelCandidate = (model != null && model!.trim().isNotEmpty)
        ? model!.trim()
        : Env.geminiModel.trim();
    final activeModel =
        modelCandidate.isNotEmpty ? modelCandidate : 'gemini-3.5-flash-lite';

    // 2. Kunci dikirim via header x-goog-api-key (BUKAN query string di URL) — Fase R3
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$activeModel:generateContent',
    );

    // 5. Pertahankan batas maksimal 10 pesan riwayat terakhir sebagai konteks percakapan — PRD §9.3
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

    // 5. Pertahankan systemInstruction asisten buku — PRD §9.3
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
          .timeout(const Duration(seconds: 30));

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
        // Respons diblokir (finishReason SAFETY) -> tampilkan pesan ramah — Fase R3
        if (finishReason != null && finishReason.toUpperCase() == 'SAFETY') {
          return 'Maaf, respons tidak dapat ditampilkan karena terdeteksi mengandung konten sensitif. Silakan tanyakan hal lain seputar buku.';
        }

        final content = firstCandidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        final reply = parts[0]['text'] as String?;
        if (reply == null || reply.trim().isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        return reply.trim();
      }

      // 3 & 4. Pemetaan error kode status HTTP — Fase R3
      if (response.statusCode == 400) {
        throw GeminiChatException(
          'Permintaan atau format kunci tidak valid. Konfigurasi AI belum benar.',
          statusCode: 400,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw GeminiChatException(
          'Kunci ditolak, periksa GEMINI_API_KEY. Konfigurasi AI belum benar.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 404) {
        // Catat model yang tidak ditemukan di debug log tanpa network call tambahan — Fase R3+
        if (kDebugMode) {
          debugPrint(
              '[Gemini] Model "$activeModel" tidak ditemukan (HTTP 404). '
              'Periksa GEMINI_MODEL di .env. '
              'Model yang direkomendasikan: gemini-2.0-flash-lite, gemini-1.5-flash');
        }
        throw GeminiChatException(
          'Model tidak tersedia, periksa GEMINI_MODEL di pengaturan.',
          statusCode: 404,
        );
      } else if (response.statusCode == 429) {
        throw GeminiChatException(
          'Kuota habis, coba lagi nanti. Terlalu banyak permintaan, coba lagi sebentar.',
          statusCode: 429,
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        throw GeminiChatException(
          'Server AI sedang sibuk (${response.statusCode}), silakan coba lagi nanti.',
          statusCode: response.statusCode,
        );
      } else {
        throw GeminiChatException(
          'Terjadi kesalahan pada layanan AI (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw GeminiChatException(
        'Koneksi ke asisten AI timeout. Periksa jaringan Anda.',
      );
    } on SocketException {
      throw GeminiChatException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
      );
    } on GeminiChatException {
      rethrow;
    } catch (e) {
      if (e is GeminiChatException) {
        rethrow;
      }
      throw GeminiChatException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
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
