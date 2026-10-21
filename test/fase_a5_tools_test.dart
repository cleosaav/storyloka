import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/services/time_converter_service.dart';
import 'package:storyloka/data/models/chat_message.dart';
import 'package:storyloka/data/models/feedback_entry.dart';
import 'package:storyloka/data/models/game_score.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/features/tools/currency_converter_page.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('Fase A5: TimeConverterService — PRD §9.5', () {
    test('Mengkonversi waktu WIB ke 4 zona dengan offset yang benar', () {
      final inputTime = DateTime(2026, 10, 21, 10, 0); // 10:00 WIB
      final results = TimeConverterService.convertAll(inputTime, TimeZone.wib);

      expect(results.length, 4);

      final wib = results.firstWhere((r) => r.zone == TimeZone.wib);
      final wita = results.firstWhere((r) => r.zone == TimeZone.wita);
      final wit = results.firstWhere((r) => r.zone == TimeZone.wit);
      final london = results.firstWhere((r) => r.zone == TimeZone.london);

      // WIB = 10:00
      expect(wib.localTime.hour, 10);
      // WITA = 11:00 (+1 jam)
      expect(wita.localTime.hour, 11);
      // WIT = 12:00 (+2 jam)
      expect(wit.localTime.hour, 12);

      // London selisih 6 atau 7 jam tergantung BST
      expect(london.localTime.hour, isIn([3, 4]));
      expect(wib.dayDiff, 0);
    });

    test('Menangani pergantian hari antar zona waktu', () {
      // 01:00 WIB tanggal 22 -> di London masih tanggal 21 (dayDiff = -1)
      final inputTime = DateTime(2026, 10, 22, 1, 0);
      final results = TimeConverterService.convertAll(inputTime, TimeZone.wib);

      final london = results.firstWhere((r) => r.zone == TimeZone.london);
      expect(london.dayDiff, -1);
      expect(london.localTime.day, 21);
    });
  });

  group('Fase A5: CurrencyConverter Logic — PRD §9.2', () {
    final rates = {
      'USD': 1.0,
      'IDR': 15500.0,
      'EUR': 0.92,
      'JPY': 150.0,
      'SGD': 1.35,
    };

    test('Mata uang asal dan tujuan sama mengembalikan jumlah awal', () {
      final result = convertCurrency(
        amount: 100,
        fromCurrency: 'USD',
        toCurrency: 'USD',
        rates: rates,
      );
      expect(result, 100.0);
    });

    test('Konversi USD ke IDR', () {
      final result = convertCurrency(
        amount: 10,
        fromCurrency: 'USD',
        toCurrency: 'IDR',
        rates: rates,
      );
      expect(result, 155000.0);
    });

    test('Konversi IDR ke USD', () {
      final result = convertCurrency(
        amount: 31000,
        fromCurrency: 'IDR',
        toCurrency: 'USD',
        rates: rates,
      );
      expect(result, 2.0);
    });

    test('Konversi silang non-USD: EUR ke JPY', () {
      // 92 EUR = 100 USD = 15000 JPY
      final result = convertCurrency(
        amount: 92,
        fromCurrency: 'EUR',
        toCurrency: 'JPY',
        rates: rates,
      );
      expect(result, closeTo(15000.0, 0.01));
    });

    test('Mata uang tidak ditemukan mengembalikan 0', () {
      final result = convertCurrency(
        amount: 100,
        fromCurrency: 'UNKNOWN',
        toCurrency: 'USD',
        rates: rates,
      );
      expect(result, 0.0);
    });

    test('formatCurrencyResult memformat desimal sesuai mata uang', () {
      expect(formatCurrencyResult(15500, 'IDR'), contains('15.500'));
      expect(formatCurrencyResult(12.5, 'USD'), contains('12.50'));
    });
  });

  group('Fase A5: FakeFeedbackRepository — PRD §7.7.1', () {
    test('Simpan feedback dan ambil daftar terurut terbaru di atas', () async {
      final repo = FakeFeedbackRepository();

      final e1 = FeedbackEntry(
        id: '1',
        userId: 'u1',
        name: 'Andi',
        impression: 'Keren',
        suggestion: 'Tingkatkan lagi',
        createdAt: DateTime(2026, 1, 1),
      );
      final e2 = FeedbackEntry(
        id: '2',
        userId: 'u2',
        name: 'Budi',
        impression: 'Sangat bagus',
        suggestion: 'Lengkap',
        createdAt: DateTime(2026, 1, 2),
      );

      await repo.save(e1);
      await repo.save(e2);

      final list = await repo.getAll();
      expect(list.length, 2);
      expect(list.first.name, 'Budi'); // terbaru di atas
      expect(list.last.name, 'Andi');
    });
  });

  group('Fase A5: FakeScoreRepository — PRD §10.1', () {
    test('Simpan dan ambil high score game snake', () async {
      final repo = FakeScoreRepository();

      expect(await repo.getHighScore('snake'), 0);

      await repo.saveScore(GameScore(
        id: 's1',
        userId: 'u1',
        game: 'snake',
        score: 40,
        playedAt: DateTime.now(),
      ));
      await repo.saveScore(GameScore(
        id: 's2',
        userId: 'u1',
        game: 'snake',
        score: 80,
        playedAt: DateTime.now(),
      ));

      expect(await repo.getHighScore('snake'), 80);
    });
  });

  group('Fase A5: FakeChatRepository — PRD §9.3', () {
    test('Balasan AI Chat mengandung label demo dan riwayat dapat dihapus', () async {
      final repo = FakeChatRepository();

      final reply = await repo.sendMessage('Rekomendasi buku fiksi ilmiah', []);
      expect(reply, contains('Jawaban contoh (mode demo)'));

      final msg = ChatMessage(
        id: 'm1',
        userId: 'u1',
        role: 'user',
        content: 'Halo',
        createdAt: DateTime.now(),
      );
      await repo.saveMessage(msg);

      var history = await repo.getHistory();
      expect(history.length, 1);

      await repo.clearHistory();
      history = await repo.getHistory();
      expect(history, isEmpty);
    });
  });
}
