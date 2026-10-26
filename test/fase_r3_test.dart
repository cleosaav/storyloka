import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:storyloka/core/config/env.dart';
import 'package:storyloka/data/models/chat_message.dart';
import 'package:storyloka/data/repositories/remote/gemini_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Env.reset();
  });

  tearDown(() {
    Env.reset();
  });

  group('Fase R3: GeminiChatRepository (Perbaikan AI Chat & Pemetaan Error)', () {
    test('1. Menggunakan model default gemini-3.5-flash-lite dan mengirim key via header x-goog-api-key', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Halo! Saya asisten membaca StoryLoka.'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'rahasia-gemini-key',
      );

      final reply = await repo.sendMessage('Halo asisten', []);

      expect(reply, equals('Halo! Saya asisten membaca StoryLoka.'));
      // Model default adalah gemini-3.5-flash-lite (bukan gemini-1.5-flash)
      expect(capturedUri.path, contains('models/gemini-3.5-flash-lite:generateContent'));
      // Kunci TIDAK ADA di query parameters URL
      expect(capturedUri.queryParameters.containsKey('key'), isFalse);
      // Kunci dikirim lewat header x-goog-api-key
      expect(capturedHeaders['x-goog-api-key'], equals('rahasia-gemini-key'));
      expect(capturedHeaders['Content-Type'], equals('application/json'));
    });

    test('2. Menggunakan custom model dari Env.geminiModel apa adanya tanpa diubah ke gemini-1.5-flash', () async {
      Env.setMockValues({
        'GEMINI_API_KEY': 'dummy-key',
        'GEMINI_MODEL': 'gemini-2.0-flash',
      });

      late Uri capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [{'text': 'Siap membantu!'}]
                }
              }
            ]
          }),
          200,
        );
      });

      final repo = GeminiChatRepository(client: mockClient);
      await repo.sendMessage('Tes model', []);

      expect(capturedUri.path, contains('models/gemini-2.0-flash:generateContent'));
    });

    test('3. Mempertahankan systemInstruction asisten buku dan batas 10 riwayat', () async {
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [{'text': 'Rekomendasi novel fiksi'}]
                }
              }
            ]
          }),
          200,
        );
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'key-123',
      );

      // Buat 16 pesan riwayat
      final history = List<ChatMessage>.generate(
        16,
        (i) => ChatMessage(
          id: 'id-$i',
          userId: 'user1',
          role: i % 2 == 0 ? 'user' : 'model',
          content: 'Pesan ke-$i',
          createdAt: DateTime.now(),
        ),
      );

      await repo.sendMessage('Buku apa yang bagus?', history);

      // Verifikasi systemInstruction
      expect(capturedBody['systemInstruction'], isNotNull);
      final systemText =
          capturedBody['systemInstruction']['parts'][0]['text'] as String;
      expect(systemText, contains('asisten StoryLoka'));
      expect(systemText, contains('teman membaca yang ramah'));

      // Riwayat dibatasi 10 + 1 prompt saat ini
      final contents = capturedBody['contents'] as List<dynamic>;
      expect(contents.length, equals(11));
      expect(contents.last['parts'][0]['text'], equals('Buku apa yang bagus?'));
    });

    test('4. Pemetaan error 400: permintaan atau format kunci tidak valid', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": {"message": "Invalid request"}}', 400);
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'invalid-key',
      );

      expect(
        () => repo.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 400 &&
            e.message.toLowerCase().contains('permintaan atau format kunci tidak valid'))),
      );
    });

    test('5. Pemetaan error 401 dan 403: kunci ditolak', () async {
      final mockClient401 = MockClient((request) async {
        return http.Response('{"error": {"message": "Unauthorized"}}', 401);
      });
      final repo401 = GeminiChatRepository(
        client: mockClient401,
        apiKey: 'wrong-key',
      );

      expect(
        () => repo401.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 401 &&
            e.message.toLowerCase().contains('kunci ditolak'))),
      );

      final mockClient403 = MockClient((request) async {
        return http.Response('{"error": {"message": "Forbidden"}}', 403);
      });
      final repo403 = GeminiChatRepository(
        client: mockClient403,
        apiKey: 'wrong-key',
      );

      expect(
        () => repo403.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 403 &&
            e.message.toLowerCase().contains('kunci ditolak'))),
      );
    });

    test('6. Pemetaan error 404: model tidak tersedia — tidak ada network call tambahan', () async {
      bool listModelsCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('generateContent')) {
          return http.Response('{"error": {"message": "Model not found"}}', 404);
        }
        // Endpoint /models tidak boleh dipanggil (menghindari double-timeout)
        if (request.url.path.endsWith('/models')) {
          listModelsCalled = true;
          return http.Response('{}', 200);
        }
        return http.Response('Not found', 404);
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'valid-key',
        model: 'model-jadul',
      );

      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 404 &&
            e.message.contains('Model tidak tersedia, periksa GEMINI_MODEL'))),
      );

      // Endpoint /models TIDAK boleh dipanggil — perbaikan timeout double-request Fase R3+
      await Future.delayed(const Duration(milliseconds: 50));
      expect(listModelsCalled, isFalse);
    });

    test('7. Pemetaan error 429: kuota habis', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": {"message": "Quota exceeded"}}', 429);
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'valid-key',
      );

      expect(
        () => repo.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 429 &&
            e.message.toLowerCase().contains('kuota habis'))),
      );
    });

    test('8. Pemetaan error 5xx: server AI sedang sibuk', () async {
      final mockClient500 = MockClient((request) async {
        return http.Response('{"error": "Internal Server Error"}', 500);
      });
      final repo500 = GeminiChatRepository(
        client: mockClient500,
        apiKey: 'valid-key',
      );

      expect(
        () => repo500.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 500 &&
            e.message.toLowerCase().contains('server ai sedang sibuk'))),
      );

      final mockClient503 = MockClient((request) async {
        return http.Response('{"error": "Service Unavailable"}', 503);
      });
      final repo503 = GeminiChatRepository(
        client: mockClient503,
        apiKey: 'valid-key',
      );

      expect(
        () => repo503.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.statusCode == 503 &&
            e.message.toLowerCase().contains('server ai sedang sibuk'))),
      );
    });

    test('9. Pemetaan Timeout dan SocketException', () async {
      final mockTimeoutClient = MockClient((request) async {
        throw TimeoutException('Request timeout 20s');
      });
      final repoTimeout = GeminiChatRepository(
        client: mockTimeoutClient,
        apiKey: 'valid-key',
      );

      expect(
        () => repoTimeout.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.message.toLowerCase().contains('timeout'))),
      );

      final mockSocketClient = MockClient((request) async {
        throw const SocketException('Connection reset by peer');
      });
      final repoSocket = GeminiChatRepository(
        client: mockSocketClient,
        apiKey: 'valid-key',
      );

      expect(
        () => repoSocket.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is GeminiChatException &&
            e.message.toLowerCase().contains('tidak ada koneksi internet'))),
      );
    });

    test('10. Menangani respons diblokir oleh finishReason SAFETY dengan pesan ramah', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'finishReason': 'SAFETY',
                'content': {
                  'parts': []
                }
              }
            ]
          }),
          200,
        );
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'valid-key',
      );

      final reply = await repo.sendMessage('Pertanyaan sensitif', []);
      expect(reply, contains('konten sensitif'));
      expect(reply, contains('seputar buku'));
    });

    test('11. Menangani respons diblokir oleh promptFeedback blockReason SAFETY dengan pesan ramah', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'promptFeedback': {
              'blockReason': 'SAFETY'
            },
            'candidates': []
          }),
          200,
        );
      });

      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'valid-key',
      );

      final reply = await repo.sendMessage('Pertanyaan tidak aman', []);
      expect(reply, contains('konten sensitif'));
    });

    test('12. Menangani candidates kosong atau respons kosong dengan pesan ramah', () async {
      final mockEmptyCandidates = MockClient((request) async {
        return http.Response(jsonEncode({'candidates': []}), 200);
      });
      final repoEmpty = GeminiChatRepository(
        client: mockEmptyCandidates,
        apiKey: 'valid-key',
      );

      final reply1 = await repoEmpty.sendMessage('Pertanyaan misteri', []);
      expect(reply1, equals('Aku belum bisa menjawab itu, coba pertanyaan lain.'));

      final mockEmptyParts = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {'parts': []}
              }
            ]
          }),
          200,
        );
      });
      final repoEmptyParts = GeminiChatRepository(
        client: mockEmptyParts,
        apiKey: 'valid-key',
      );

      final reply2 = await repoEmptyParts.sendMessage('Pertanyaan misteri 2', []);
      expect(reply2, equals('Aku belum bisa menjawab itu, coba pertanyaan lain.'));
    });
  });
}
