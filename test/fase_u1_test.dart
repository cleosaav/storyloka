import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/core/widgets/responsive_body.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/chat_repository.dart';
import 'package:storyloka/data/repositories/currency_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/profile_repository.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/features/add_book/add_book_page.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/lock_screen_page.dart';
import 'package:storyloka/features/auth/login_page.dart';
import 'package:storyloka/features/auth/register_page.dart';
import 'package:storyloka/features/book_detail/collection_book_detail_page.dart';
import 'package:storyloka/features/book_detail/search_book_detail_page.dart';
import 'package:storyloka/features/home/home_page.dart';
import 'package:storyloka/features/library/library_page.dart';
import 'package:storyloka/features/profile/profile_page.dart';
import 'package:storyloka/features/profile/reading_ledger_page.dart';
import 'package:storyloka/features/reading/finished_book_page.dart';
import 'package:storyloka/features/reading/reading_progress_page.dart';
import 'package:storyloka/features/reading/reading_timer_page.dart';
import 'package:storyloka/features/tools/currency_converter_page.dart';
import 'package:storyloka/features/tools/feedback_page.dart';
import 'package:storyloka/features/tools/tools_page.dart';

Widget _buildTestWrapper({
  required Widget child,
  required Size size,
  required double textScale,
  required FakeLibraryRepository libraryRepo,
}) {
  final session = SecureSessionStore();
  final dControls = DemoControls();
  final tController = ThemeController();
  final authRepo = FakeAuthRepository(sessionStore: session);
  final aController = AuthController(
    authRepository: authRepo,
    sessionStore: session,
    demoControls: dControls,
  );
  final sRepo = FakeBookSearchRepository(demoControls: dControls);
  final rRepo = FakeReadingRepository(demoControls: dControls);
  final lRepo = FakeLedgerRepository(demoControls: dControls);
  final cRepo = FakeChatRepository(demoControls: dControls);
  final curRepo = FakeCurrencyRepository(demoControls: dControls);
  final fRepo = FakeFeedbackRepository(demoControls: dControls);
  final scRepo = FakeScoreRepository(demoControls: dControls);
  final pRepo = FakeProfileRepository(authRepo);

  return MultiProvider(
    providers: [
      Provider<SecureSessionStore>.value(value: session),
      ChangeNotifierProvider<DemoControls>.value(value: dControls),
      ChangeNotifierProvider<ThemeController>.value(value: tController),
      ChangeNotifierProvider<AuthController>.value(value: aController),
      Provider<LibraryRepository>.value(value: libraryRepo),
      Provider<BookSearchRepository>.value(value: sRepo),
      Provider<ReadingRepository>.value(value: rRepo),
      Provider<LedgerRepository>.value(value: lRepo),
      Provider<LedgerService>.value(value: LedgerService(lRepo)),
      Provider<ChatRepository>.value(value: cRepo),
      Provider<CurrencyRepository>.value(value: curRepo),
      Provider<FeedbackRepository>.value(value: fRepo),
      Provider<ScoreRepository>.value(value: scRepo),
      Provider<ProfileRepository>.value(value: pRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    fakeRepositoriesEnableLatency = false;
    await initializeDateFormatting('id_ID', null);
  });

  tearDown(() {
    fakeRepositoriesEnableLatency = true;
  });

  group('Fase U1: ResponsiveBody & Anti-Overflow Tests', () {
    const testConfigs = [
      {'size': Size(360, 640), 'scale': 1.0, 'name': '360x640 (scale 1.0)'},
      {'size': Size(360, 640), 'scale': 1.3, 'name': '360x640 (scale 1.3)'},
      {'size': Size(402, 874), 'scale': 1.0, 'name': '402x874 (scale 1.0)'},
      {'size': Size(800, 1280), 'scale': 1.0, 'name': '800x1280 Tablet (scale 1.0)'},
    ];

    const sampleBookResult = BookSearchResult(
      googleBooksId: 'u1_test_book',
      title: 'Judul Panjang Buku Tes Anti-Overflow StoryLoka Editorial',
      authors: 'Penulis Hebat Dan Terkenal Sepanjang Masa',
      genre: 'Literature & Fiction',
      isbn: '9781234567890',
      publisher: 'Penerbit Aksara Nusantara',
      pageCount: 384,
      synopsis: 'Sinopsis panjang untuk pengujian responsif dan teks.',
    );

    for (final config in testConfigs) {
      final size = config['size'] as Size;
      final scale = config['scale'] as double;
      final name = config['name'] as String;

      testWidgets('Semua layar render bebas overflow pada $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final libraryRepo = FakeLibraryRepository();
        final testBook = UserBook(
          id: 'test_book_u1',
          userId: 'test_user',
          googleBooksId: 'u1_test_book',
          title: 'Judul Panjang Buku Tes Anti-Overflow StoryLoka',
          authors: 'Penulis Populer',
          genre: 'Fiction',
          pageCount: 350,
          currentPage: 120,
          status: BookStatus.reading,
          listType: ListType.collection,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await libraryRepo.addBook(testBook);

        // 1. Home
        await tester.pumpWidget(_buildTestWrapper(
          child: const HomePage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada HomePage di $name');

        // 2. Library
        await tester.pumpWidget(_buildTestWrapper(
          child: const LibraryPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada LibraryPage di $name');

        // 3. Add Book
        await tester.pumpWidget(_buildTestWrapper(
          child: const AddBookPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada AddBookPage di $name');

        // 4. Tools
        await tester.pumpWidget(_buildTestWrapper(
          child: const ToolsPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ToolsPage di $name');

        // 5. Profile
        await tester.pumpWidget(_buildTestWrapper(
          child: const ProfilePage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ProfilePage di $name');

        // 6. Login
        await tester.pumpWidget(_buildTestWrapper(
          child: const LoginPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada LoginPage di $name');

        // 7. Register
        await tester.pumpWidget(_buildTestWrapper(
          child: const RegisterPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada RegisterPage di $name');

        // 8. Finished Book
        await tester.pumpWidget(_buildTestWrapper(
          child: const FinishedBookPage(id: 'test_book_u1'),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada FinishedBookPage di $name');

        // 9. Reading Timer
        await tester.pumpWidget(_buildTestWrapper(
          child: const ReadingTimerPage(id: 'test_book_u1'),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ReadingTimerPage di $name');

        // 10. Lock Screen
        await tester.pumpWidget(_buildTestWrapper(
          child: const LockScreenPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada LockScreenPage di $name');

        // 11. Search Book Detail
        await tester.pumpWidget(_buildTestWrapper(
          child: const SearchBookDetailPage(book: sampleBookResult),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada SearchBookDetailPage di $name');

        // 12. Collection Book Detail
        await tester.pumpWidget(_buildTestWrapper(
          child: const CollectionBookDetailPage(id: 'test_book_u1'),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada CollectionBookDetailPage di $name');

        // 13. Reading Progress
        await tester.pumpWidget(_buildTestWrapper(
          child: const ReadingProgressPage(id: 'test_book_u1'),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ReadingProgressPage di $name');

        // 14. Reading Ledger
        await tester.pumpWidget(_buildTestWrapper(
          child: const ReadingLedgerPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ReadingLedgerPage di $name');

        // 15. Currency Converter
        await tester.pumpWidget(_buildTestWrapper(
          child: const CurrencyConverterPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada CurrencyConverterPage di $name');

        // 16. Feedback
        await tester.pumpWidget(_buildTestWrapper(
          child: const FeedbackPage(),
          size: size,
          textScale: scale,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada FeedbackPage di $name');
      });
    }

    testWidgets('ResponsiveBody membatasi lebar maksimum hingga 560 px di layar tablet', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBody(
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boxFinder = find.byType(ConstrainedBox);
      expect(boxFinder, findsWidgets);

      // Pastikan ada ConstrainedBox dengan maxWidth 560
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(boxFinder);
      final responsiveBox = constrainedBoxes.firstWhere(
        (cb) => cb.constraints.maxWidth == 560,
      );
      expect(responsiveBox.constraints.maxWidth, 560);
    });
  });
}
