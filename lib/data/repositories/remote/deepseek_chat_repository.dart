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

/// Exception khusus untuk kesalahan layanan DeepSeek AI — Fase R4 & S1.
class DeepSeekChatException extends AiChatException {
  DeepSeekChatException(
    super.message, {
    super.statusCode,
    super.retryAfter,
    super.isTimeout = false,
    super.isSocket = false,
  }) : super(providerName: 'DeepSeek');
}

/// Implementasi ChatRepository menggunakan DeepSeek REST API (OpenAI-compatible) — Fase R4 & S1.
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

  String get id => 'deepseek';
  String get displayName => 'DeepSeek ($_deepSeekModel)';

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

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    void Function(String status)? onStatusUpdate,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = (apiKey ?? Env.deepseekApiKey).trim();
    if (key.isEmpty) {
      throw DeepSeekChatException(
        'Kunci DeepSeek tidak ditemukan, periksa DEEPSEEK_API_KEY.',
        statusCode: 401,
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
          .timeout(timeout);

      final retryAfter = parseRetryAfter(response.headers['retry-after']);

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

        // Tahan banting: finishReason == length / MAX_TOKENS tetap mengembalikan teks jika ada
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }

        return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
      }

      // Pemetaan error HTTP
      if (response.statusCode == 400) {
        throw DeepSeekChatException(
          'Permintaan tidak valid ke DeepSeek. Konfigurasi AI belum benar.',
          statusCode: 400,
          retryAfter: retryAfter,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw DeepSeekChatException(
          'Kunci DeepSeek ditolak, periksa DEEPSEEK_API_KEY.',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
        );
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('[DeepSeek] Endpoint tidak ditemukan (HTTP 404). '
              'Periksa base URL atau model: $_deepSeekModel');
        }
        throw DeepSeekChatException(
          'Layanan DeepSeek tidak ditemukan, coba lagi nanti.',
          statusCode: 404,
          retryAfter: retryAfter,
        );
      } else if (response.statusCode == 402) {
        throw DeepSeekChatException(
          'Saldo akun DeepSeek habis (Insufficient Balance).',
          statusCode: 402,
          retryAfter: retryAfter,
        );
      } else if (response.statusCode == 429) {
        throw DeepSeekChatException(
          'Kuota DeepSeek habis, coba lagi nanti.',
          statusCode: 429,
          retryAfter: retryAfter,
        );
      } else if (response.statusCode >= 500 && response.statusCode < 600) {
        throw DeepSeekChatException(
          'Server DeepSeek sedang sibuk (${response.statusCode}), silakan coba lagi nanti.',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
        );
      } else {
        throw DeepSeekChatException(
          'Terjadi kesalahan pada layanan DeepSeek (${response.statusCode}).',
          statusCode: response.statusCode,
          retryAfter: retryAfter,
        );
      }
    } on TimeoutException {
      throw DeepSeekChatException(
        'Koneksi ke DeepSeek timeout. Periksa jaringan Anda.',
        isTimeout: true,
      );
    } on SocketException catch (e) {
      throw DeepSeekChatException(
        'Gagal menghubungi server DeepSeek: ${e.message}',
        isSocket: true,
      );
    } catch (e) {
      if (e is DeepSeekChatException) rethrow;
      throw DeepSeekChatException(
        'Terjadi kesalahan saat memproses jawaban DeepSeek: $e',
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
