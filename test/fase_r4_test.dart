import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:storyloka/data/models/chat_message.dart';
import 'package:storyloka/data/repositories/remote/deepseek_chat_repository.dart';
import 'package:storyloka/data/repositories/remote/fallback_chat_repository.dart';
import 'package:storyloka/data/repositories/remote/gemini_chat_repository.dart';

// ---------------------------------------------------------------------------
// Helper builders
// ---------------------------------------------------------------------------

String _deepSeekOk(String text) => jsonEncode({
      'choices': [
        {
          'finish_reason': 'stop',
          'message': {'role': 'assistant', 'content': text},
        }
      ],
    });

String _geminiOk(String text) => jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'role': 'model',
            'parts': [
              {'text': text}
            ],
          },
        }
      ],
    });

DeepSeekChatRepository _deepSeekRepo(MockClient client, {String? apiKey}) =>
    DeepSeekChatRepository(client: client, apiKey: apiKey ?? 'test-ds-key');

GeminiChatRepository _geminiRepo(MockClient client, {String? apiKey}) =>
    GeminiChatRepository(client: client, apiKey: apiKey ?? 'test-gm-key');

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fase R4: DeepSeekChatRepository', () {
    test('1. Mengembalikan respons teks dari DeepSeek saat sukses (200)', () async {
      final client = MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer test-ds-key');
        expect(req.headers['Content-Type'], 'application/json');
        expect(req.url.toString(),
            contains('api.deepseek.com/chat/completions'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-chat');
        expect(body['stream'], false);
        return http.Response(_deepSeekOk('Halo, ada yang bisa aku bantu?'), 200);
      });

      final repo = _deepSeekRepo(client);
      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Halo, ada yang bisa aku bantu?');
    });

    test('2. Menyertakan systemPrompt sebagai role=system di messages', () async {
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        expect(messages.first['role'], 'system');
        expect((messages.first['content'] as String).contains('StoryLoka'), isTrue);
        return http.Response(_deepSeekOk('ok'), 200);
      });
      final result = await _deepSeekRepo(client).sendMessage('test', []);
      expect(result, 'ok');
    });

    test('3. Memetakan role model menjadi assistant di messages', () async {
      final history = [
        ChatMessage(
            id: '1',
            userId: 'u',
            role: 'model',
            content: 'Jawaban AI',
            createdAt: DateTime.now()),
      ];
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        // messages[0] = system, messages[1] = history (model → assistant)
        expect(messages[1]['role'], 'assistant');
        expect(messages[1]['content'], 'Jawaban AI');
        return http.Response(_deepSeekOk('ok'), 200);
      });
      await _deepSeekRepo(client).sendMessage('Lanjut', history);
    });

    test('4. Pemetaan error 401: kunci ditolak', () async {
      final client = MockClient((_) async =>
          http.Response('{"error": {"message": "Unauthorized"}}', 401));
      await expectLater(
        () => _deepSeekRepo(client).sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is DeepSeekChatException &&
            e.statusCode == 401 &&
            e.message.contains('DEEPSEEK_API_KEY'))),
      );
    });

    test('5. Pemetaan error 429: kuota habis', () async {
      final client = MockClient((_) async =>
          http.Response('{"error": {"message": "Rate limit"}}', 429));
      await expectLater(
        () => _deepSeekRepo(client).sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is DeepSeekChatException &&
            e.statusCode == 429 &&
            e.message.contains('Kuota DeepSeek'))),
      );
    });

    test('5b. Pemetaan error 402: saldo akun habis (Insufficient Balance)', () async {
      final client = MockClient((_) async =>
          http.Response('{"error": {"message": "Insufficient Balance"}}', 402));
      await expectLater(
        () => _deepSeekRepo(client).sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is DeepSeekChatException &&
            e.statusCode == 402 &&
            e.message.contains('Saldo akun DeepSeek habis'))),
      );
    });

    test('6. Pemetaan error 500: server sibuk', () async {
      final client = MockClient((_) async =>
          http.Response('{"error": {"message": "Internal error"}}', 500));
      await expectLater(
        () => _deepSeekRepo(client).sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is DeepSeekChatException &&
            e.statusCode == 500 &&
            e.message.contains('Server DeepSeek sedang sibuk'))),
      );
    });

    test('7. Menangani finish_reason=content_filter dengan pesan ramah', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'content_filter',
                  'message': {'role': 'assistant', 'content': ''},
                }
              ],
            }),
            200,
          ));
      final result = await _deepSeekRepo(client).sendMessage('pertanyaan sensitif', []);
      expect(result.contains('konten sensitif'), isTrue);
    });

    test('8. Menangani choices kosong dengan pesan ramah', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'choices': []}),
            200,
          ));
      final result = await _deepSeekRepo(client).sendMessage('Halo', []);
      expect(result, contains('coba pertanyaan lain'));
    });

    test('9. Kunci kosong melempar DeepSeekChatException tanpa network call', () async {
      bool called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('ok', 200);
      });
      final repo = DeepSeekChatRepository(client: client, apiKey: '');
      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(isA<DeepSeekChatException>()),
      );
      expect(called, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Fase R4: FallbackChatRepository (DeepSeek → Gemini)', () {
    test('10. Menggunakan DeepSeek jika berhasil (tidak memanggil Gemini)', () async {
      bool geminiCalled = false;
      final dsClient = MockClient((_) async =>
          http.Response(_deepSeekOk('Dari DeepSeek'), 200));
      final gmClient = MockClient((_) async {
        geminiCalled = true;
        return http.Response(_geminiOk('Dari Gemini'), 200);
      });

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Dari DeepSeek');
      expect(geminiCalled, isFalse);
    });

    test('11. Fallback ke Gemini saat DeepSeek timeout (null statusCode)', () async {
      final dsClient = MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw DeepSeekChatException('Koneksi ke DeepSeek timeout.');
      });
      final gmClient = MockClient((_) async =>
          http.Response(_geminiOk('Dari Gemini (fallback)'), 200));

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Dari Gemini (fallback)');
    });

    test('12. Fallback ke Gemini saat DeepSeek error 429', () async {
      final dsClient = MockClient((_) async =>
          http.Response('{"error":"rate limit"}', 429));
      final gmClient = MockClient((_) async =>
          http.Response(_geminiOk('Dari Gemini (setelah rate limit DS)'), 200));

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Dari Gemini (setelah rate limit DS)');
    });

    test('13. Fallback ke Gemini saat DeepSeek error 500', () async {
      final dsClient = MockClient((_) async =>
          http.Response('{"error":"server error"}', 500));
      final gmClient = MockClient((_) async =>
          http.Response(_geminiOk('Dari Gemini (setelah 500 DS)'), 200));

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Dari Gemini (setelah 500 DS)');
    });

    test('14. TIDAK fallback saat DeepSeek error 401 (auth error — lempar ke UI)', () async {
      bool geminiCalled = false;
      final dsClient = MockClient((_) async =>
          http.Response('{"error":"unauthorized"}', 401));
      final gmClient = MockClient((_) async {
        geminiCalled = true;
        return http.Response(_geminiOk('ok'), 200);
      });

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(isA<DeepSeekChatException>()),
      );
      expect(geminiCalled, isFalse);
    });

    test('15. TIDAK fallback saat DeepSeek error 400 (config error)', () async {
      bool geminiCalled = false;
      final dsClient = MockClient((_) async =>
          http.Response('{"error":"bad request"}', 400));
      final gmClient = MockClient((_) async {
        geminiCalled = true;
        return http.Response(_geminiOk('ok'), 200);
      });

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(isA<DeepSeekChatException>()),
      );
      expect(geminiCalled, isFalse);
    });

    test('16. Melempar error Gemini jika kedua provider gagal', () async {
      final dsClient = MockClient((_) async =>
          throw DeepSeekChatException('Timeout DS'));
      final gmClient = MockClient((_) async =>
          http.Response('{"error":"quota"}', 429));

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(isA<GeminiChatException>()),
      );
    });

    test('17. Fallback ke Gemini saat DeepSeek error 402 (saldo habis)', () async {
      final dsClient = MockClient((_) async =>
          http.Response('{"error":"Insufficient Balance"}', 402));
      final gmClient = MockClient((_) async =>
          http.Response(_geminiOk('Dari Gemini (setelah saldo DS habis)'), 200));

      final repo = FallbackChatRepository(
        primary: _deepSeekRepo(dsClient),
        fallback: _geminiRepo(gmClient),
      );
      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Dari Gemini (setelah saldo DS habis)');
    });
  });
}
