import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'helpers/demo_widgets.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/chat_repository.dart';
import 'package:storyloka/data/repositories/currency_repository.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/profile_repository.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/features/add_book/add_book_page.dart';
import 'package:storyloka/features/add_book/scan_page.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/lock_screen_page.dart';
import 'package:storyloka/features/auth/login_page.dart';
import 'package:storyloka/features/auth/register_page.dart';
import 'package:storyloka/features/auth/splash_page.dart';
import 'package:storyloka/features/book_detail/collection_book_detail_page.dart';
import 'package:storyloka/features/book_detail/search_book_detail_page.dart';
import 'package:storyloka/features/book_detail/wishlist_book_detail_page.dart';
import 'package:storyloka/features/home/home_page.dart';
import 'package:storyloka/features/library/library_page.dart';
import 'package:storyloka/features/profile/edit_profile_page.dart';
import 'package:storyloka/features/profile/profile_page.dart';
import 'package:storyloka/features/profile/reading_ledger_page.dart';
import 'package:storyloka/features/reading/finished_book_page.dart';
import 'package:storyloka/features/reading/reading_progress_page.dart';
import 'package:storyloka/features/reading/reading_timer_page.dart';
import 'package:storyloka/features/tools/ai_chat_page.dart';
import 'package:storyloka/features/tools/bookstore_map/bookstore_map_page.dart';
import 'package:storyloka/features/tools/currency_converter_page.dart';
import 'package:storyloka/features/tools/feedback_page.dart';
import 'package:storyloka/features/tools/snake/snake_page.dart';
import 'package:storyloka/features/tools/time_converter_page.dart';
import 'package:storyloka/features/tools/tools_page.dart';

Widget _buildWrapper({
  required Widget child,
  required Size size,
  required double textScale,
  required ThemeMode themeMode,
  required FakeLibraryRepository libraryRepo,
}) {
  final session = SecureSessionStore();
  final dControls = DemoControls();
  final tController = ThemeController();
  if (themeMode == ThemeMode.dark) {
    tController.setThemeMode(ThemeMode.dark);
  } else {
    tController.setThemeMode(ThemeMode.light);
  }

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
      themeMode: themeMode,
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

  group('Fase F4: Comprehensive UI Consistency & Responsive Matrix Tests', () {
    const testMatrix = [
      {'size': Size(360, 640), 'scale': 1.0, 'theme': ThemeMode.light, 'name': '360x640 (scale 1.0, Light)'},
      {'size': Size(360, 640), 'scale': 1.3, 'theme': ThemeMode.dark, 'name': '360x640 (scale 1.3, Dark)'},
      {'size': Size(402, 874), 'scale': 1.0, 'theme': ThemeMode.light, 'name': '402x874 (scale 1.0, Light)'},
      {'size': Size(402, 874), 'scale': 1.3, 'theme': ThemeMode.dark, 'name': '402x874 (scale 1.3, Dark)'},
      {'size': Size(800, 1280), 'scale': 1.0, 'theme': ThemeMode.light, 'name': '800x1280 Tablet (scale 1.0, Light)'},
      {'size': Size(800, 1280), 'scale': 1.3, 'theme': ThemeMode.dark, 'name': '800x1280 Tablet (scale 1.3, Dark)'},
    ];

    const sampleSearchResult = BookSearchResult(
      googleBooksId: 'f4_test_book',
      title: 'Bumi Manusia Pramoedya Ananta Toer Edisi Spesial Tetralogi Buru',
      authors: 'Pramoedya Ananta Toer',
      genre: 'Historical Fiction',
      isbn: '9789799731234',
      publisher: 'Hasta Mitra',
      pageCount: 535,
      synopsis: 'Roman kebangkitan nasional awal abad ke-20 di Hindia Belanda.',
    );

    for (final cfg in testMatrix) {
      final size = cfg['size'] as Size;
      final scale = cfg['scale'] as double;
      final theme = cfg['theme'] as ThemeMode;
      final name = cfg['name'] as String;

      testWidgets('Render seluruh 20 halaman StoryLoka bebas overflow pada $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final libraryRepo = FakeLibraryRepository();
        final testBookCollection = UserBook(
          id: 'test_book_collection_f4',
          userId: 'test_user',
          googleBooksId: 'f4_test_book',
          title: 'Bumi Manusia Pramoedya Ananta Toer',
          authors: 'Pramoedya Ananta Toer',
          genre: 'Historical Fiction',
          pageCount: 535,
          currentPage: 210,
          status: BookStatus.reading,
          listType: ListType.collection,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final testBookWishlist = UserBook(
          id: 'test_book_wishlist_f4',
          userId: 'test_user',
          googleBooksId: 'f4_test_book_w',
          title: 'Cantik Itu Luka',
          authors: 'Eka Kurniawan',
          genre: 'Magical Realism',
          pageCount: 480,
          currentPage: 0,
          status: BookStatus.notStarted,
          listType: ListType.wishlist,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await libraryRepo.addBook(testBookCollection);
        await libraryRepo.addBook(testBookWishlist);

        // 1. Home Page
        await tester.pumpWidget(_buildWrapper(
          child: const HomePage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada HomePage di $name');

        // 2. Library Page
        await tester.pumpWidget(_buildWrapper(
          child: const LibraryPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada LibraryPage di $name');

        // 3. Add Book Page
        await tester.pumpWidget(_buildWrapper(
          child: const AddBookPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada AddBookPage di $name');

        // 4. Scan Page
        await tester.pumpWidget(_buildWrapper(
          child: const ScanPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ScanPage di $name');

        // 5. Search Book Detail
        await tester.pumpWidget(_buildWrapper(
          child: const SearchBookDetailPage(book: sampleSearchResult),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada SearchBookDetailPage di $name');

        // 6. Collection Book Detail
        await tester.pumpWidget(_buildWrapper(
          child: const CollectionBookDetailPage(id: 'test_book_collection_f4'),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada CollectionBookDetailPage di $name');

        // 7. Wishlist Book Detail
        await tester.pumpWidget(_buildWrapper(
          child: const WishlistBookDetailPage(id: 'test_book_wishlist_f4'),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada WishlistBookDetailPage di $name');

        // 8. Reading Timer
        await tester.pumpWidget(_buildWrapper(
          child: const ReadingTimerPage(id: 'test_book_collection_f4'),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ReadingTimerPage di $name');

        // 9. Reading Progress
        await tester.pumpWidget(_buildWrapper(
          child: const ReadingProgressPage(id: 'test_book_collection_f4'),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ReadingProgressPage di $name');

        // 10. Finished Book
        await tester.pumpWidget(_buildWrapper(
          child: const FinishedBookPage(id: 'test_book_collection_f4'),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada FinishedBookPage di $name');

        // 11. Tools Page
        await tester.pumpWidget(_buildWrapper(
          child: const ToolsPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ToolsPage di $name');

        // 12. Feedback Page
        await tester.pumpWidget(_buildWrapper(
          child: const FeedbackPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada FeedbackPage di $name');

        // 13. Currency Converter Page
        await tester.pumpWidget(_buildWrapper(
          child: const CurrencyConverterPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada CurrencyConverterPage di $name');

        // 14. Time Converter Page
        await tester.pumpWidget(_buildWrapper(
          child: const TimeConverterPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada TimeConverterPage di $name');

        // 15. AI Chat Page
        await tester.pumpWidget(_buildWrapper(
          child: const AiChatPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada AiChatPage di $name');

        // 16. Snake Page
        await tester.pumpWidget(_buildWrapper(
          child: const SnakePage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada SnakePage di $name');

        // 17. Bookstore Map Page
        await tester.pumpWidget(_buildWrapper(
          child: const BookstoreMapPage(
            initialLat: -6.2088,
            initialLng: 106.8456,
          ),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: 'Overflow pada BookstoreMapPage di $name');

        // 18. Profile Page
        await tester.pumpWidget(_buildWrapper(
          child: const ProfilePage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ProfilePage di $name');

        // 19. Edit Profile Page
        await tester.pumpWidget(_buildWrapper(
          child: const EditProfilePage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada EditProfilePage di $name');

        // 20. Reading Ledger Page
        await tester.pumpWidget(_buildWrapper(
          child: const ReadingLedgerPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada ReadingLedgerPage di $name');

        // 21. Login Page
        await tester.pumpWidget(_buildWrapper(
          child: const LoginPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada LoginPage di $name');

        // 22. Register Page
        await tester.pumpWidget(_buildWrapper(
          child: const RegisterPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada RegisterPage di $name');

        // 23. Lock Screen Page
        await tester.pumpWidget(_buildWrapper(
          child: const LockScreenPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow pada LockScreenPage di $name');

        // 24. Splash Page
        await tester.pumpWidget(_buildWrapper(
          child: const SplashPage(),
          size: size,
          textScale: scale,
          themeMode: theme,
          libraryRepo: libraryRepo,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: 'Overflow pada SplashPage di $name');
      });
    }
  });
}
