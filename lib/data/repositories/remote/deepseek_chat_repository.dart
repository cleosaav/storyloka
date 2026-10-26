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

/// Exception khusus untuk kesalahan layanan DeepSeek AI — Fase R4.
class DeepSeekChatException implements Exception {
  final String message;
  final int? statusCode;

  DeepSeekChatException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Implementasi ChatRepository menggunakan DeepSeek REST API (OpenAI-compatible) — Fase R4.
///
/// DeepSeek menggunakan format OpenAI chat completions:
/// POST https://api.deepseek.com/chat/completions
/// Header: `Authorization: Bearer key`
/// Model utama: deepseek-chat
class DeepSeekChatRepository implements ChatRepository {
  final http.Client _client;
  final DatabaseHelper _dbHelper;
  final Future<String> Function()? userIdProvider;
  final String? apiKey;
  static const _uuid = Uuid();

  static const String _deepSeekBaseUrl = 'https://api.deepseek.com';
  static const String _deepSeekModel = 'deepseek-chat';

  static const String _systemPrompt =
      'Kamu adalah asisten StoryLoka, teman membaca yang ramah. Bantu pengguna '
      'dengan rekomendasi buku, ringkasan, penjelasan tema/penulis, dan tips membaca. '
      'Jawab dengan bahasa yang dipakai pengguna, ringkas dan jelas. Jika pertanyaan '
      'di luar topik buku/membaca, tolak dengan sopan dan arahkan kembali. Jangan '
      'mengarang judul, penulis, atau fakta; jika tidak yakin, katakan tidak yakin.';

  DeepSeekChatRepository({
    http.Client? client,
    DatabaseHelper? dbHelper,
    this.userIdProvider,
    this.apiKey,
  })  : _client = client ?? http.Client(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> _getUserId() async {
    final provider = userIdProvider;
    if (provider != null) return await provider();
    return 'default_user';
  }

  @override
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final key = (apiKey ?? Env.deepseekApiKey).trim();
    if (key.isEmpty) {
      throw DeepSeekChatException(
        'Kunci DeepSeek tidak ditemukan, periksa DEEPSEEK_API_KEY.',
      );
    }

    final endpoint = Uri.parse('$_deepSeekBaseUrl/chat/completions');

    // Batasi 10 riwayat terakhir — konsisten dengan GeminiChatRepository §9.3
    final recentHistory =
        history.length > 10 ? history.sublist(history.length - 10) : history;

    // Format OpenAI-compatible: messages array dengan role system/user/assistant
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
    ];
    for (final chat in recentHistory) {
      messages.add({
        'role': chat.role == 'model' ? 'assistant' : 'user',
        'content': chat.content,
      });
    }
    // Tambahkan pesan pengguna saat ini jika belum ada di history
    if (messages.isEmpty ||
        messages.last['role'] != 'user' ||
        messages.last['content'] != message) {
      messages.add({'role': 'user', 'content': message});
    }

    final requestBody = {
      'model': _deepSeekModel,
      'messages': messages,
      'max_tokens': 800,
      'temperature': 0.7,
      'stream': false,
    };

    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        final firstChoice = choices[0] as Map<String, dynamic>;
        final finishReason = firstChoice['finish_reason'] as String?;
        if (finishReason == 'content_filter') {
          return 'Maaf, respons tidak dapat ditampilkan karena terdeteksi mengandung konten sensitif. Silakan tanyakan hal lain seputar buku.';
        }

        final msgObj = firstChoice['message'] as Map<String, dynamic>?;
        final reply = msgObj?['content'] as String?;
        if (reply == null || reply.trim().isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }
        return reply.trim();
      }

      // Pemetaan error HTTP — konsisten dengan GeminiChatRepository
      if (response.statusCode == 400) {
        throw DeepSeekChatException(
          'Permintaan tidak valid ke DeepSeek. Konfigurasi AI belum benar.',
          statusCode: 400,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw DeepSeekChatException(
          'Kunci DeepSeek ditolak, periksa DEEPSEEK_API_KEY.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('[DeepSeek] Endpoint tidak ditemukan (HTTP 404). '
              'Periksa base URL atau model: $_deepSeekModel');
        }
        throw DeepSeekChatException(
          'Layanan DeepSeek tidak ditemukan, coba lagi nanti.',
          statusCode: 404,
        );
      } else if (response.statusCode == 402) {
        throw DeepSeekChatException(
          'Saldo akun DeepSeek habis (Insufficient Balance).',
          statusCode: 402,
        );
      } else if (response.statusCode == 429) {
        throw DeepSeekChatException(
          'Kuota DeepSeek habis, coba lagi nanti.',
          statusCode: 429,
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        throw DeepSeekChatException(
          'Server DeepSeek sedang sibuk (${response.statusCode}), silakan coba lagi nanti.',
          statusCode: response.statusCode,
        );
      } else {
        throw DeepSeekChatException(
          'Terjadi kesalahan pada layanan DeepSeek (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw DeepSeekChatException(
        'Koneksi ke DeepSeek timeout. Periksa jaringan Anda.',
      );
    } on SocketException {
      throw DeepSeekChatException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
      );
    } on DeepSeekChatException {
      rethrow;
    } catch (e) {
      if (e is DeepSeekChatException) rethrow;
      throw DeepSeekChatException(
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
