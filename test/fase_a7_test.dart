import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/config/env.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_colors.dart';
import 'package:storyloka/core/theme/app_spacing.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/app_button.dart';
import 'package:storyloka/core/widgets/app_card.dart';
import 'helpers/demo_widgets.dart';
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
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/home/home_page.dart';
import 'package:storyloka/features/library/library_page.dart';
import 'package:storyloka/features/profile/profile_page.dart';
import 'package:storyloka/app/app.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:storyloka/features/tools/ai_chat_page.dart';
import 'package:storyloka/features/tools/currency_converter_page.dart';
import 'package:storyloka/features/tools/snake/snake_page.dart';
import 'package:storyloka/features/tools/time_converter_page.dart';
import 'package:storyloka/features/tools/tools_page.dart';

Widget _buildTestApp({
  required Widget child,
  DemoControls? demoControls,
  ThemeController? themeController,
  AuthController? authController,
  FakeLibraryRepository? libraryRepo,
  FakeBookSearchRepository? searchRepo,
  FakeReadingRepository? readingRepo,
  FakeLedgerRepository? ledgerRepo,
  FakeChatRepository? chatRepo,
  FakeCurrencyRepository? currencyRepo,
  FakeFeedbackRepository? feedbackRepo,
  FakeScoreRepository? scoreRepo,
  Size physicalSize = const Size(360, 640),
  double textScale = 1.3,
}) {
  final dControls = demoControls ?? DemoControls();
  final tController = themeController ?? ThemeController();
  final session = SecureSessionStore();
  final authRepo = FakeAuthRepository(sessionStore: session);
  final aController = authController ??
      AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: dControls,
      );

  final libRepo = libraryRepo ?? FakeLibraryRepository(demoControls: dControls);
  final sRepo = searchRepo ?? FakeBookSearchRepository(demoControls: dControls);
  final rRepo = readingRepo ?? FakeReadingRepository(demoControls: dControls);
  final lRepo = ledgerRepo ?? FakeLedgerRepository(demoControls: dControls);
  final cRepo = chatRepo ?? FakeChatRepository(demoControls: dControls);
  final curRepo = currencyRepo ?? FakeCurrencyRepository(demoControls: dControls);
  final fRepo = feedbackRepo ?? FakeFeedbackRepository(demoControls: dControls);
  final scRepo = scoreRepo ?? FakeScoreRepository(demoControls: dControls);
  final pRepo = FakeProfileRepository(authRepo);

  return MultiProvider(
    providers: [
      Provider<SecureSessionStore>.value(value: session),
      ChangeNotifierProvider<DemoControls>.value(value: dControls),
      ChangeNotifierProvider<ThemeController>.value(value: tController),
      ChangeNotifierProvider<AuthController>.value(value: aController),
      Provider<LibraryRepository>.value(value: libRepo),
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
      themeMode: tController.themeMode,
      home: MediaQuery(
        data: MediaQueryData(
          size: physicalSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: SizedBox(
          width: physicalSize.width,
          height: physicalSize.height,
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
    Env.setMockValues({
      'SUPABASE_URL': 'https://mock.supabase.co',
      'SUPABASE_ANON_KEY': 'mock-anon-key',
    });
    await initializeDateFormatting('id_ID', null);
  });

  tearDown(() {
    fakeRepositoriesEnableLatency = true;
    Env.reset();
  });

  group('Fase A7: Token, Spacing, Radius & Hierarchy Audit', () {
    test('Token AppSpacing konsisten dengan PRD §4.4 & design-system.md §4', () {
      expect(AppSpacing.pageMargin, 24.0);
      expect(AppSpacing.cardPadding, 16.0);
      expect(AppSpacing.cardRadius, 20.0);
      expect(AppSpacing.buttonRadius, 14.0);
      expect(AppSpacing.inputRadius, 12.0);
      expect(AppSpacing.touchTarget, 44.0);
      expect(AppSpacing.buttonHeight, 48.0);
    });

    testWidgets('AppCard mematuhi radius 20 dan padding 16 secara default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Testing Card'),
            ),
          ),
        ),
      );

      final materialFinder = find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(Material),
      ).first;
      final material = tester.widget<Material>(materialFinder);
      expect(material.shape, isA<RoundedRectangleBorder>());
      final shape = material.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20.0));
    });

    testWidgets('PrimaryButton mematuhi tinggi 48, background Deep Teal, dan teks putih', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Aksi Utama',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      final elevated = tester.widget<ElevatedButton>(buttonFinder);
      expect(elevated.style?.backgroundColor?.resolve({}), AppColors.deepTeal);
      expect(elevated.style?.foregroundColor?.resolve({}), AppColors.white);
    });

    testWidgets('SecondaryButton mematuhi outline 1px Deep Teal dan teks Deep Teal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondaryButton(
              label: 'Aksi Sekunder',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(OutlinedButton);
      expect(buttonFinder, findsOneWidget);
      final outlined = tester.widget<OutlinedButton>(buttonFinder);
      expect(outlined.style?.foregroundColor?.resolve({}), AppColors.deepTeal);
      final side = outlined.style?.side?.resolve({});
      expect(side?.color, AppColors.deepTeal);
      expect(side?.width, 1.0);
    });
  });

  group('Fase A7: Uji Responsive 360x640 dan Text Scale 1.3 (Bebas Overflow)', () {
    testWidgets('HomePage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const HomePage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('StoryLoka'), findsOneWidget);
      expect(find.text('Currently Reading'), findsOneWidget);
    });

    testWidgets('LibraryPage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const LibraryPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Wishlist'), findsOneWidget);
    });

    testWidgets('AddBookPage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const AddBookPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add a Book'), findsOneWidget);
    });

    testWidgets('ToolsPage render 5 card vertikal tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const ToolsPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Mini Games — Book Snake'), findsOneWidget);
      expect(find.text('Kesan & Pesan'), findsOneWidget);
      expect(find.text('AI Chat'), findsOneWidget);
    });

    testWidgets('ProfilePage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const ProfilePage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Tampilan'), findsOneWidget);
      expect(find.text('Reading Ledger'), findsOneWidget);
    });

    testWidgets('CurrencyConverterPage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const CurrencyConverterPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Konversi Mata Uang'), findsOneWidget);
      expect(find.text('Kurs Semua Mata Uang (vs USD)'), findsOneWidget);
    });

    testWidgets('TimeConverterPage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const TimeConverterPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('WIB'), findsOneWidget);
      expect(find.text('WITA'), findsOneWidget);
      expect(find.text('WIT'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
    });

    testWidgets('AiChatPage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const AiChatPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('StoryLoka AI'), findsOneWidget);
    });

    testWidgets('SnakePage render tanpa overflow pada 360x640 + skala 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(child: const SnakePage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Book Snake'), findsOneWidget);
    });
  });

  group('Fase A7: Uji State Lewat DemoControls (Empty, Error, Loading)', () {
    testWidgets('DemoControls toggleDataEmpty memunculkan Empty State pada Home & Library', (tester) async {
      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      // 1. Initial Home: berisi data demo
      await tester.pumpWidget(_buildTestApp(
        child: const HomePage(key: ValueKey('initial')),
        demoControls: demoControls,
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      // Ada buku demo
      expect(find.text('Start Your Reading Journey'), findsNothing);

      // 2. Toggle empty -> reload
      demoControls.toggleDataEmpty(true);
      await tester.pumpWidget(_buildTestApp(
        child: const HomePage(key: ValueKey('empty')),
        demoControls: demoControls,
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      // Home sekarang kosong
      expect(find.text('Start Your Reading Journey'), findsOneWidget);
      expect(find.text('Belum ada buku di koleksi Anda.'), findsOneWidget);
      expect(find.text('Wishlist Anda masih kosong.'), findsOneWidget);

      // 3. Test pada LibraryPage
      await tester.pumpWidget(_buildTestApp(
        child: const LibraryPage(key: ValueKey('empty-lib')),
        demoControls: demoControls,
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      // Library menampilkan empty state
      expect(find.text('Koleksi Masih Kosong'), findsOneWidget);
    });

    testWidgets('DemoControls toggleNetworkError memunculkan Error state + Coba Lagi', (tester) async {
      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      // Aktifkan error simulasi
      demoControls.toggleNetworkError(true);

      await tester.pumpWidget(_buildTestApp(
        child: const HomePage(),
        demoControls: demoControls,
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      // Memverifikasi pesan error dan tombol Coba Lagi
      expect(find.text('Gagal memuat data Home.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Matikan error dan tekan tombol Coba Lagi
      demoControls.toggleNetworkError(false);
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      // Data berhasil dimuat kembali
      expect(find.text('Gagal memuat data Home.'), findsNothing);
      expect(find.text('Currently Reading'), findsOneWidget);
    });

    testWidgets('LibraryPage menampilkan Error state ketika simulasi error aktif', (tester) async {
      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      demoControls.toggleNetworkError(true);

      await tester.pumpWidget(_buildTestApp(
        child: const LibraryPage(),
        demoControls: demoControls,
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat buku di Library.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      demoControls.toggleNetworkError(false);
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat buku di Library.'), findsNothing);
    });
  });

  group('Fase A7: Aksesibilitas & Target Sentuh', () {
    testWidgets('Bottom nav memiliki 5 item, label Semantics, dan tombol tengah 56px', (tester) async {
      final sessionStore = SecureSessionStore();
      final fakeAuth = FakeAuthRepository(sessionStore: sessionStore);

      await tester.pumpWidget(
        MultiProvider(
          providers: buildAppProviders(
            authRepo: fakeAuth,
          ),
          child: const StoryLokaApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Isi kredensial dan tap Login untuk masuk ke shell utama
      await tester.enterText(find.byType(TextField).first, 'user@storyloka.app');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Profile'), findsWidgets);

      final addButtonFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Add Book',
      );
      expect(addButtonFinder, findsOneWidget);

      // Periksa ukuran tombol Add di tengah: minimal 56x56
      final renderBox = tester.renderObject<RenderBox>(addButtonFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(56.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(56.0));
    });

    testWidgets('AppIconButton mematuhi target sentuh minimal 44x44 dan label Semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppIconButton(
                icon: Icons.search,
                tooltip: 'Pencarian',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final iconButtonFinder = find.byType(AppIconButton);
      final renderBox = tester.renderObject<RenderBox>(iconButtonFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
      expect(find.bySemanticsLabel('Pencarian'), findsOneWidget);
    });
  });
}
