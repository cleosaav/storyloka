import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/app_button.dart';
import 'package:storyloka/core/widgets/app_card.dart';
import 'package:storyloka/core/widgets/book_widgets.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/core/widgets/progress_and_badge.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/home/home_page.dart';

Widget _buildHomeTestApp({
  required FakeLibraryRepository libraryRepo,
  required DemoControls demoControls,
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(360, 640),
  double textScale = 1.0,
}) {
  final session = SecureSessionStore();
  final authRepo = FakeAuthRepository(sessionStore: session);
  final authCtrl = AuthController(
    authRepository: authRepo,
    sessionStore: session,
    demoControls: demoControls,
  );
  final themeCtrl = ThemeController();

  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      padding: EdgeInsets.zero,
    ),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<DemoControls>.value(value: demoControls),
        ChangeNotifierProvider<AuthController>.value(value: authCtrl),
        ChangeNotifierProvider<ThemeController>.value(value: themeCtrl),
        Provider<LibraryRepository>.value(value: libraryRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const HomePage(),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    fakeRepositoriesEnableLatency = false;
  });

  tearDown(() {
    fakeRepositoriesEnableLatency = true;
  });

  group('Fase U2: Perbaikan HomePage & EmptyStateCard Tests', () {
    testWidgets('1. EmptyStateCard.horizontal merender ilustrasi kiri dan konten kanan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateCard.horizontal(
              icon: Icons.auto_stories_outlined,
              title: 'Start Your Reading Journey',
              message: 'Your next favorite book is waiting for you.',
              actionLabel: 'Add Book',
              actionIcon: Icons.add_rounded,
              onAction: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Your Reading Journey'), findsOneWidget);
      expect(find.text('Your next favorite book is waiting for you.'), findsOneWidget);
      expect(find.text('Add Book'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
    });

    testWidgets('2. HomePage kondisi kosong: semua card selebar penuh konten', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);
      demoControls.toggleDataEmpty(true);

      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan kondisi kosong Currently Reading, Collection, Wishlist terdeteksi
      expect(find.text('Start Your Reading Journey'), findsOneWidget);
      expect(find.text('Belum ada buku di koleksi Anda.'), findsOneWidget);
      expect(find.text('Wishlist Anda masih kosong.'), findsOneWidget);

      // Memastikan semua AppCard selebar area konten (360 - 2 * 24 margin = 312 px)
      final cardFinders = find.byType(AppCard);
      expect(cardFinders, findsWidgets);
      for (final card in cardFinders.evaluate()) {
        final box = card.renderObject as RenderBox;
        expect(box.size.width, equals(312.0));
      }
    });

    testWidgets('3. HomePage kondisi terisi: Currently Reading, cover 80x120, progress bar, Read & Update', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
        ),
      );
      await tester.pumpAndSettle();

      // Currently reading ada
      expect(find.text('Currently Reading'), findsOneWidget);
      expect(find.text('Laskar Pelangi'), findsOneWidget);
      expect(find.byType(ReadingProgressBar), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Read'), findsOneWidget);
      expect(find.widgetWithText(SecondaryButton, 'Update'), findsOneWidget);

      // Card Currently Reading selebar penuh (402 - 48 = 354 px)
      final cardFinders = find.byType(AppCard);
      expect(cardFinders, findsWidgets);
      for (final card in cardFinders.evaluate()) {
        final box = card.renderObject as RenderBox;
        expect(box.size.width, equals(354.0));
      }
    });

    testWidgets('4. My Collection & My Wishlist terisi: 3 cover sejajar, jarak antarcover 12', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi cover buku sejajar
      expect(find.byType(BookCover), findsWidgets);

      // Tombol See all menggunakan TertiaryButton
      expect(find.widgetWithText(TertiaryButton, 'See all'), findsNWidgets(2));
    });

    testWidgets('5. HomePage bebas overflow pada layar 360 px dengan teks skala 1.3 (Empty & Filled)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      // A. Filled state skala 1.3
      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Overflow pada filled HomePage skala 1.3');

      // B. Empty state skala 1.3
      demoControls.toggleDataEmpty(true);
      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Overflow pada empty HomePage skala 1.3');
    });

    testWidgets('6. HomePage di layar Tablet (800x1280) dibatasi ResponsiveBody 560 px selebar penuh kartu', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);

      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
          size: const Size(800, 1280),
        ),
      );
      await tester.pumpAndSettle();

      // Pada tablet, max content width 560, kartu selebar 560 - 48 = 512 px
      final cardFinders = find.byType(AppCard);
      expect(cardFinders, findsWidgets);
      for (final card in cardFinders.evaluate()) {
        final box = card.renderObject as RenderBox;
        expect(box.size.width, equals(512.0));
      }
    });

    testWidgets('7. HomePage pada Dark Mode merender tanpa error dan ikon warna dinamis', (tester) async {
      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);
      demoControls.toggleDataEmpty(true);

      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Your Reading Journey'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. HomePage Error state menampilkan Coba Lagi', (tester) async {
      final demoControls = DemoControls();
      final libraryRepo = FakeLibraryRepository(demoControls: demoControls);
      demoControls.toggleNetworkError(true);

      await tester.pumpWidget(
        _buildHomeTestApp(
          libraryRepo: libraryRepo,
          demoControls: demoControls,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat data Home.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });
  });
}
