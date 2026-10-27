import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:storyloka/data/repositories/remote/ai_chat_exception.dart';
import 'package:storyloka/data/repositories/remote/circuit_breaker.dart';
import 'package:storyloka/data/repositories/remote/deepseek_chat_repository.dart';
import 'package:storyloka/data/repositories/remote/fallback_chat_repository.dart';
import 'package:storyloka/data/repositories/remote/gemini_chat_repository.dart';

String _deepSeekOk(String text, {String finishReason = 'stop'}) => jsonEncode({
      'choices': [
        {
          'finish_reason': finishReason,
          'message': {'role': 'assistant', 'content': text},
        }
      ],
    });

String _geminiOk(String text, {String finishReason = 'STOP'}) => jsonEncode({
      'candidates': [
        {
          'finishReason': finishReason,
          'content': {
            'role': 'model',
            'parts': [
              {'text': text}
            ],
          },
        }
      ],
    });

void main() {
  setUp(() {
    CircuitBreaker.reset();
  });

  group('Fase S1: Unit Test Stabilitas AI Chat', () {
    test('1. Retry: urutan 503, 503, 200 berhasil pada percobaan ke-3', () async {
      int attemptCount = 0;
      final delays = <Duration>[];

      final client = MockClient((req) async {
        attemptCount++;
        if (attemptCount < 3) {
          return http.Response('{"error":"overloaded"}', 503);
        }
        return http.Response(_geminiOk('Berhasil setelah retry!'), 200);
      });

      final repo = FallbackChatRepository.chain(
        providers: [
          GeminiChatRepository(
            client: client,
            apiKey: 'test-key',
            model: 'gemini-3.5-flash-lite',
          ),
        ],
        delayFn: (d) async => delays.add(d),
      );

      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Berhasil setelah retry!');
      expect(attemptCount, 3);
      expect(delays.length, 2); // 2 kali jeda retry
    });

    test('2. Fallback: DeepSeek 401 langsung beralih ke Gemini tanpa retry berulang', () async {
      int dsAttempts = 0;
      bool geminiCalled = false;

      final dsClient = MockClient((req) async {
        dsAttempts++;
        return http.Response('{"error":"unauthorized"}', 401);
      });

      final gmClient = MockClient((req) async {
        geminiCalled = true;
        return http.Response(_geminiOk('Halo dari Gemini!'), 200);
      });

      final repo = FallbackChatRepository.chain(
        providers: [
          DeepSeekChatRepository(client: dsClient, apiKey: 'bad-key'),
          GeminiChatRepository(client: gmClient, apiKey: 'good-key'),
        ],
        delayFn: (_) async {},
      );

      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Halo dari Gemini!');
      expect(dsAttempts, 1, reason: '401 auth error tidak boleh di-retry 3x');
      expect(geminiCalled, isTrue);
    });

    test('3. Fallback: Gemini model utama 503 beralih ke model cadangan', () async {
      int primaryAttempts = 0;
      bool fallbackModelCalled = false;

      final primaryClient = MockClient((req) async {
        primaryAttempts++;
        return http.Response('{"error":"overloaded"}', 503);
      });

      final fallbackClient = MockClient((req) async {
        fallbackModelCalled = true;
        return http.Response(_geminiOk('Halo dari Gemini Cadangan!'), 200);
      });

      final repo = FallbackChatRepository.chain(
        providers: [
          GeminiChatRepository(
            client: primaryClient,
            apiKey: 'test-key',
            model: 'gemini-3.5-flash-lite',
          ),
          GeminiChatRepository(
            client: fallbackClient,
            apiKey: 'test-key',
            model: 'gemini-3.5-flash',
          ),
        ],
        delayFn: (_) async {},
      );

      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Halo dari Gemini Cadangan!');
      expect(primaryAttempts, 3, reason: 'Model utama di-retry 3 kali sebelum fallback');
      expect(fallbackModelCalled, isTrue);
    });

    test('4. Semua provider gagal mengembalikan pesan ramah "Layanan AI sedang ramai..."', () async {
      final client503 = MockClient((req) async =>
          http.Response('{"error":"unavailable"}', 503));

      final repo = FallbackChatRepository.chain(
        providers: [
          GeminiChatRepository(client: client503, apiKey: 'key-1', model: 'model-a'),
          GeminiChatRepository(client: client503, apiKey: 'key-2', model: 'model-b'),
        ],
        delayFn: (_) async {},
      );

      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(isA<AiChatException>().having(
          (e) => e.message,
          'message',
          'Layanan AI sedang ramai, coba lagi sebentar.',
        )),
      );
    });

    test('5. Semua provider offline mengembalikan pesan "Tidak ada koneksi internet..."', () async {
      final clientOffline = MockClient((req) async =>
          throw const SocketException('No route to host'));

      final repo = FallbackChatRepository.chain(
        providers: [
          DeepSeekChatRepository(client: clientOffline, apiKey: 'key-1'),
          GeminiChatRepository(client: clientOffline, apiKey: 'key-2'),
        ],
        delayFn: (_) async {},
      );

      await expectLater(
        () => repo.sendMessage('Halo', []),
        throwsA(isA<AiChatException>().having(
          (e) => e.message,
          'message',
          'Tidak ada koneksi internet. Periksa jaringan Anda dan coba lagi.',
        )),
      );
    });

    test('6. Header Retry-After dihormati oleh delay backoff', () async {
      int attempt = 0;
      Duration? capturedDelay;

      final client = MockClient((req) async {
        attempt++;
        if (attempt == 1) {
          return http.Response(
            '{"error":"rate limit"}',
            429,
            headers: {'retry-after': '5'},
          );
        }
        return http.Response(_geminiOk('Sukses setelah Retry-After'), 200);
      });

      final repo = FallbackChatRepository.chain(
        providers: [
          GeminiChatRepository(client: client, apiKey: 'test-key'),
        ],
        delayFn: (d) async => capturedDelay = d,
      );

      final result = await repo.sendMessage('Halo', []);
      expect(result, 'Sukses setelah Retry-After');
      expect(capturedDelay, const Duration(seconds: 5));
    });

    test('7. Circuit Breaker in-memory: auth failure cooldown 10 menit, transient 60 detik', () async {
      // Setup: DeepSeek auth failure
      int dsCalls = 0;
      final dsClient = MockClient((req) async {
        dsCalls++;
        return http.Response('{"error":"unauthorized"}', 401);
      });

      int gmCalls = 0;
      final gmClient = MockClient((req) async {
        gmCalls++;
        return http.Response(_geminiOk('Gemini OK'), 200);
      });

      final repo = FallbackChatRepository.chain(
        providers: [
          DeepSeekChatRepository(client: dsClient, apiKey: 'bad-key'),
          GeminiChatRepository(client: gmClient, apiKey: 'good-key'),
        ],
        delayFn: (_) async {},
      );

      // Panggilan 1: DeepSeek dipanggil 1x -> 401 -> Circuit Breaker trip 10 menit -> Gemini menjawab
      final res1 = await repo.sendMessage('Pesan 1', []);
      expect(res1, 'Gemini OK');
      expect(dsCalls, 1);
      expect(gmCalls, 1);

      // Panggilan 2: DeepSeek harus di-skip langsung karena circuit breaker aktif
      final res2 = await repo.sendMessage('Pesan 2', []);
      expect(res2, 'Gemini OK');
      expect(dsCalls, 1, reason: 'DeepSeek tidak boleh dipanggil lagi selama cooldown 10 menit');
      expect(gmCalls, 2);

      // Reset circuit breaker: DeepSeek bisa dicoba lagi
      CircuitBreaker.reset();
      final res3 = await repo.sendMessage('Pesan 3', []);
      expect(res3, 'Gemini OK');
      expect(dsCalls, 2, reason: 'Setelah reset, DeepSeek kembali dicoba');
    });

    test('8. Tahan banting respons: finishReason MAX_TOKENS tetap mengembalikan teks parsial', () async {
      final geminiClient = MockClient((req) async {
        return http.Response(
          _geminiOk('Paragraf satu buku ini...', finishReason: 'MAX_TOKENS'),
          200,
        );
      });

      final repo = GeminiChatRepository(client: geminiClient, apiKey: 'key');
      final result = await repo.sendMessage('Ceritakan buku', []);
      expect(result, 'Paragraf satu buku ini...');
    });

    test('9. Tahan banting respons: candidates kosong mengembalikan pesan ramah', () async {
      final geminiClient = MockClient((req) async {
        return http.Response(jsonEncode({'candidates': []}), 200);
      });

      final repo = GeminiChatRepository(client: geminiClient, apiKey: 'key');
      final result = await repo.sendMessage('Ceritakan buku', []);
      expect(result, contains('Aku belum bisa menjawab itu, coba pertanyaan lain.'));
    });

    test('10. Status callback: onStatusUpdate mengirim "Mencoba lagi..." saat retry/fallback', () async {
      int attempt = 0;
      final statuses = <String>[];

      final client = MockClient((req) async {
        attempt++;
        if (attempt == 1) return http.Response('{"error":"busy"}', 503);
        return http.Response(_geminiOk('Sukses'), 200);
      });

      final repo = FallbackChatRepository.chain(
        providers: [
          GeminiChatRepository(client: client, apiKey: 'test-key'),
        ],
        delayFn: (_) async {},
      );

      final result = await repo.sendMessage(
        'Halo',
        [],
        onStatusUpdate: (s) => statuses.add(s),
      );
      expect(result, 'Sukses');
      expect(statuses, contains('Mencoba lagi...'));
    });

    test('11. Tahan banting respons DeepSeek: finish_reason length tetap mengembalikan teks parsial', () async {
      final dsClient = MockClient((req) async {
        return http.Response(
          _deepSeekOk('Paragraf satu dari DeepSeek...', finishReason: 'length'),
          200,
        );
      });

      final repo = DeepSeekChatRepository(client: dsClient, apiKey: 'key');
      final result = await repo.sendMessage('Ceritakan buku', []);
      expect(result, 'Paragraf satu dari DeepSeek...');
    });
  });
}
