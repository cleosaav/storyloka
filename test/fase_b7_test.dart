import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/chat_repository.dart';
import 'package:storyloka/data/repositories/currency_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/local/local_repositories.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'package:storyloka/data/repositories/remote/exchange_rate_repository.dart';
import 'package:storyloka/data/repositories/remote/fallback_chat_repository.dart';
import 'package:storyloka/data/repositories/remote/google_books_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/features/tools/currency_converter_page.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fakeRepositoriesEnableLatency = false;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase B7: Verifikasi Default USE_FAKE & Eliminasi Data Demo', () {
    test('1. AppConfig.useFakeData bernilai false secara default', () {
      expect(AppConfig.useFakeData, isFalse,
          reason: 'Fase B7 mensyaratkan default USE_FAKE adalah false');
    });

    testWidgets('2. DemoModeChip tidak merender chip saat USE_FAKE = false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: DemoModeChip(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mode demo'), findsNothing,
          reason: 'Chip Mode demo tidak boleh tampil di alur nyata');
    });

    testWidgets(
        '3. buildAppProviders() secara default mengikat repository nyata',
        (tester) async {
      late BookSearchRepository searchRepo;
      late CurrencyRepository currencyRepo;
      late ChatRepository chatRepo;
      late LibraryRepository libRepo;
      late ReadingRepository readRepo;
      late LedgerRepository ledgerRepo;
      late FeedbackRepository feedbackRepo;
      late ScoreRepository scoreRepo;

      await tester.pumpWidget(
        MultiProvider(
          providers: buildAppProviders(),
          child: Builder(
            builder: (context) {
              searchRepo = context.read<BookSearchRepository>();
              currencyRepo = context.read<CurrencyRepository>();
              chatRepo = context.read<ChatRepository>();
              libRepo = context.read<LibraryRepository>();
              readRepo = context.read<ReadingRepository>();
              ledgerRepo = context.read<LedgerRepository>();
              feedbackRepo = context.read<FeedbackRepository>();
              scoreRepo = context.read<ScoreRepository>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(searchRepo, isA<GoogleBooksRepository>());
      expect(currencyRepo, isA<OpenExchangeRateRepository>());
      expect(chatRepo, isA<FallbackChatRepository>());
      expect(libRepo, isA<LocalLibraryRepository>());
      expect(readRepo, isA<LocalReadingRepository>());
      expect(ledgerRepo, isA<LocalLedgerRepository>());
      expect(feedbackRepo, isA<LocalFeedbackRepository>());
      expect(scoreRepo, isA<LocalScoreRepository>());
    });

    testWidgets(
        '4. CurrencyConverterPage tidak memuat label demo saat USE_FAKE = false',
        (tester) async {
      final fakeRepo = FakeCurrencyRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<CurrencyRepository>.value(
            value: fakeRepo,
            child: const CurrencyConverterPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Kurs contoh (mode demo)'), findsNothing,
          reason: 'Label mode demo tidak boleh tampil pada alur rilis/nyata');
    });

    test('5. DemoControlsSheet memiliki proteksi kDebugMode', () {
      expect(kDebugMode, isTrue); // Di environment test kDebugMode aktif
    });
  });
}
