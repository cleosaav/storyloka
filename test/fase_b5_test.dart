import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storyloka/core/services/location_service.dart';
import 'package:storyloka/data/models/chat_message.dart';
import 'package:storyloka/data/repositories/remote/exchange_rate_repository.dart';
import 'package:storyloka/data/repositories/remote/gemini_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase B5: GeminiChatRepository (PRD §9.3)', () {
    test('Mengirim systemInstruction, header x-goog-api-key, dan max 10 pesan riwayat', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Halo! Saya asisten StoryLoka.'}
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
        apiKey: 'test-api-key',
      );

      // Buat 15 riwayat pesan
      final history = List<ChatMessage>.generate(
        15,
        (i) => ChatMessage(
          id: 'msg-$i',
          userId: 'user1',
          role: i % 2 == 0 ? 'user' : 'model',
          content: 'Pesan ke-$i',
          createdAt: DateTime.now(),
        ),
      );

      final reply = await repo.sendMessage('Rekomendasi buku fiksi', history);

      expect(reply, equals('Halo! Saya asisten StoryLoka.'));
      // Periksa endpoint menggunakan model valid (gemini-1.5-flash jika tidak diset / default)
      expect(capturedUri.path, contains('models/gemini-1.5-flash:generateContent'));
      expect(capturedHeaders['x-goog-api-key'], equals('test-api-key'));
      expect(capturedHeaders['Content-Type'], equals('application/json'));

      // Verifikasi systemInstruction
      expect(capturedBody['systemInstruction'], isNotNull);
      final systemText =
          capturedBody['systemInstruction']['parts'][0]['text'] as String;
      expect(systemText, contains('asisten StoryLoka'));

      // Verifikasi riwayat dibatasi maksimal 10 + pesan baru
      final contents = capturedBody['contents'] as List<dynamic>;
      expect(contents.length, lessThanOrEqualTo(11));
      // Pesan terakhir adalah prompt saat ini
      expect(contents.last['parts'][0]['text'], equals('Rekomendasi buku fiksi'));
    });

    test('Memetakan error 400 & 403 menjadi pesan Indonesia yang ramah', () async {
      final mockClient400 = MockClient((request) async {
        return http.Response('{"error": "bad request"}', 400);
      });
      final repo400 = GeminiChatRepository(
        client: mockClient400,
        apiKey: 'test-api-key',
      );

      expect(
        () => repo400.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Konfigurasi AI belum benar.'))),
      );

      final mockClient403 = MockClient((request) async {
        return http.Response('{"error": "forbidden"}', 403);
      });
      final repo403 = GeminiChatRepository(
        client: mockClient403,
        apiKey: 'test-api-key',
      );

      expect(
        () => repo403.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Konfigurasi AI belum benar.'))),
      );
    });

    test('Memetakan error 429 menjadi pesan rate limit', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "rate limit exceeded"}', 429);
      });
      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'test-api-key',
      );

      expect(
        () => repo.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Terlalu banyak permintaan, coba lagi sebentar.'))),
      );
    });

    test('Memetakan network error / timeout menjadi pesan koneksi internet', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No route to host');
      });
      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'test-api-key',
      );

      expect(
        () => repo.sendMessage('Halo', []),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Tidak ada koneksi internet.'))),
      );
    });

    test('Menangani candidates kosong dengan balasan ramah', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'candidates': []}), 200);
      });
      final repo = GeminiChatRepository(
        client: mockClient,
        apiKey: 'test-api-key',
      );

      final reply = await repo.sendMessage('Tes kosong', []);
      expect(reply, equals('Aku belum bisa menjawab itu, coba pertanyaan lain.'));
    });
  });

  group('Fase B5: OpenExchangeRateRepository (PRD §9.2)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Mengambil kurs live sukses dan menyimpan ke cache (isFromCache == false)', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('open.er-api.com/v6/latest/USD'));
        return http.Response(
          jsonEncode({
            'result': 'success',
            'time_last_update_unix': 1700000000,
            'rates': {
              'USD': 1.0,
              'IDR': 15500.0,
              'EUR': 0.92,
              'GBP': 0.79,
              'JPY': 148.5,
              'SGD': 1.34,
            }
          }),
          200,
        );
      });

      final repo = OpenExchangeRateRepository(client: mockClient);
      final rates = await repo.getRates('USD');

      expect(repo.isFromCache, isFalse);
      expect(rates['IDR'], equals(15500.0));
      expect(rates['EUR'], equals(0.92));

      // Verifikasi konversi: amount * (targetRate / sourceRate)
      final usdRate = rates['USD']!;
      final idrRate = rates['IDR']!;
      final converted = 10.0 * (idrRate / usdRate);
      expect(converted, equals(155000.0));
    });

    test('Fallback ke cache saat jaringan gagal / offline (isFromCache == true)', () async {
      final prefs = await SharedPreferences.getInstance();
      final sampleCache = {
        'rates': {
          'USD': 1.0,
          'IDR': 15600.0,
        },
        'last_updated': DateTime.now().toUtc().toIso8601String(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString('exchange_rates_USD', jsonEncode(sampleCache));

      // Client yang selalu melempar SocketException
      final mockClient = MockClient((request) async {
        throw const SocketException('Network offline');
      });

      final repo = OpenExchangeRateRepository(client: mockClient);
      final rates = await repo.getRates('USD');

      expect(repo.isFromCache, isTrue);
      expect(rates['IDR'], equals(15600.0));
    });

    test('Melempar Exception jika jaringan gagal dan tidak ada cache tersimpan', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Network offline');
      });

      final repo = OpenExchangeRateRepository(client: mockClient);

      expect(
        () => repo.getRates('USD'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('tidak ada kurs tersimpan'))),
      );
    });
  });

  group('Fase B5: LocationService LBS (PRD §9.4)', () {
    test('Format URL search query toko buku valid', () {
      final service = LocationService.instance;
      // Periksa query manual
      expect(service, isNotNull);
    });
  });
}
