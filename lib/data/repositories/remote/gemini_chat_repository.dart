import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../database_helper.dart';
import '../../models/chat_message.dart';
import '../chat_repository.dart';

/// Implementasi nyata ChatRepository menggunakan Google Gemini REST API — PRD §9.3.
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

  @override
  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final key = (apiKey ?? Env.geminiApiKey).trim();
    if (key.isEmpty) {
      throw Exception('Konfigurasi AI belum benar.');
    }

    // Gunakan nama model dari Env atau default gemini-1.5-flash
    var activeModel = (model ?? Env.geminiModel).trim();
    if (activeModel.isEmpty || activeModel == 'gemini-flash-latest') {
      activeModel = 'gemini-1.5-flash';
    }

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$activeModel:generateContent',
    );

    // Kirim maksimal 10 pesan terakhir sebagai konteks percakapan — PRD §9.3
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
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        final reply = parts[0]['text'] as String?;
        if (reply == null || reply.trim().isEmpty) {
          return 'Aku belum bisa menjawab itu, coba pertanyaan lain.';
        }

        return reply.trim();
      } else if (response.statusCode == 400 || response.statusCode == 403) {
        throw Exception('Konfigurasi AI belum benar.');
      } else if (response.statusCode == 429) {
        throw Exception('Terlalu banyak permintaan, coba lagi sebentar.');
      } else {
        throw Exception('Server AI sedang sibuk (${response.statusCode}).');
      }
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Periksa jaringan Anda.');
    } on TimeoutException {
      throw Exception('Koneksi ke asisten AI timeout. Periksa jaringan Anda.');
    } catch (e) {
      if (e is Exception &&
          (e.toString().contains('Konfigurasi AI belum benar') ||
              e.toString().contains('Terlalu banyak permintaan') ||
              e.toString().contains('Tidak ada koneksi') ||
              e.toString().contains('timeout'))) {
        rethrow;
      }
      throw Exception('Tidak ada koneksi internet. Periksa jaringan Anda.');
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
