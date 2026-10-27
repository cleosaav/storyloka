import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/widgets/book_widgets.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/lock_screen_page.dart';
import 'package:storyloka/features/profile/profile_page.dart';
import 'package:storyloka/features/reading/reading_progress_page.dart';
import 'package:storyloka/features/reading/reading_timer_page.dart';
import 'package:storyloka/features/tools/feedback_page.dart';
import 'package:storyloka/features/tools/snake/snake_page.dart';
import 'package:storyloka/features/tools/tools_page.dart';

Widget _buildWrapper({
  required Widget child,
  LibraryRepository? libraryRepo,
  FeedbackRepository? feedbackRepo,
  ScoreRepository? scoreRepo,
}) {
  final session = SecureSessionStore();
  final dControls = DemoControls();
  final authRepo = FakeAuthRepository(sessionStore: session);
  final aController = AuthController(
    authRepository: authRepo,
    sessionStore: session,
    demoControls: dControls,
  );

  return MultiProvider(
    providers: [
      Provider<SecureSessionStore>.value(value: session),
      ChangeNotifierProvider<DemoControls>.value(value: dControls),
      ChangeNotifierProvider<ThemeController>.value(value: ThemeController()),
      ChangeNotifierProvider<AuthController>.value(value: aController),
      Provider<LibraryRepository>.value(value: libraryRepo ?? FakeLibraryRepository()),
      Provider<BookSearchRepository>.value(value: FakeBookSearchRepository()),
      Provider<FeedbackRepository>.value(value: feedbackRepo ?? FakeFeedbackRepository()),
      Provider<ScoreRepository>.value(value: scoreRepo ?? FakeScoreRepository()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    fakeRepositoriesEnableLatency = false;
  });

  tearDown(() {
    fakeRepositoriesEnableLatency = true;
  });

  group('Fase U4d: Semantics & Accessibility Tests', () {
    testWidgets('1. BookGridCard memiliki Semantics label buku lengkap dan aksi long-press', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookGridCard(
              title: 'Laskar Pelangi',
              authors: 'Andrea Hirata',
              rating: 5,
              onLongPress: () => deleted = true,
            ),
          ),
        ),
      );

      final bookSemantics = find.bySemanticsLabel('Buku Laskar Pelangi oleh Andrea Hirata, rating 5 dari 5 bintang');
      expect(bookSemantics, findsOneWidget);

      // Pastikan aksi long press terhubung
      await tester.longPress(bookSemantics);
      expect(deleted, isTrue);
    });

    testWidgets('2. ToolsPage menu cards memiliki Semantics label Menu dan button: true', (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const ToolsPage()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Menu Kesan & Pesan, .*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Menu AI Chat, .*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Menu Mini Games — Book Snake, .*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Menu Konversi Mata Uang, .*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Menu Konversi Waktu, .*')), findsOneWidget);
    });

    testWidgets('3. SnakePage D-pad dan tombol Jeda memiliki Semantics label arah dan kontrol', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Gerak ke atas'), findsOneWidget);
      expect(find.bySemanticsLabel('Gerak ke bawah'), findsOneWidget);
      expect(find.bySemanticsLabel('Gerak ke kiri'), findsOneWidget);
      expect(find.bySemanticsLabel('Gerak ke kanan'), findsOneWidget);

      // Mulai permainan dengan tap board (GestureDetector)
      await tester.tap(find.byKey(const ValueKey('snake_board_gesture')));
      await tester.pump();

      final pauseBtn = find.bySemanticsLabel('Jeda permainan');
      expect(pauseBtn, findsOneWidget);

      // Tap pause untuk menghentikan timer game loop agar tidak ada pending timers
      await tester.tap(pauseBtn);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel('Lanjutkan permainan'), findsOneWidget);
    });

    testWidgets('4. ProfilePage avatar memiliki Semantics label "Ubah foto profil"', (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Ubah foto profil'), findsOneWidget);
    });

    testWidgets('5. FeedbackPage kartu memiliki Semantics label Avatar nama anggota tim', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildWrapper(
        child: const FeedbackPage(),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Avatar Najmah Cleosa'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Avatar Melanie Bunga Chintya Pawesty'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Avatar Naftali Margareta'),
        findsOneWidget,
      );
    });

    testWidgets('6. LockScreenPage lingkaran sidik jari memiliki Semantics label pemindai', (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const LockScreenPage()));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Pindai sidik jari atau biometrik untuk membuka kunci'),
        findsOneWidget,
      );
    });

    testWidgets('7. ReadingProgressPage Slider memiliki semanticFormatterCallback "Halaman X dari Y"', (tester) async {
      final libraryRepo = FakeLibraryRepository();
      final dummyBook = UserBook(
        id: 'prog-1',
        userId: 'test_user',
        googleBooksId: 'gb-1',
        title: 'Filosofi Teras',
        authors: 'Henry Manampiring',
        listType: ListType.collection,
        status: BookStatus.reading,
        pageCount: 320,
        currentPage: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await libraryRepo.addBook(dummyBook);

      await tester.pumpWidget(_buildWrapper(
        child: const ReadingProgressPage(id: 'prog-1'),
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.semanticFormatterCallback, isNotNull);
      expect(slider.semanticFormatterCallback!(50), 'Halaman 50 dari 320');
    });

    testWidgets('8. ReadingTimerPage stopwatch memiliki Semantics label waktu berjalan', (tester) async {
      final libraryRepo = FakeLibraryRepository();
      final dummyBook = UserBook(
        id: 'timer-1',
        userId: 'test_user',
        googleBooksId: 'gb-2',
        title: 'Atomic Habits',
        authors: 'James Clear',
        listType: ListType.collection,
        status: BookStatus.reading,
        pageCount: 300,
        currentPage: 20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await libraryRepo.addBook(dummyBook);

      await tester.pumpWidget(_buildWrapper(
        child: const ReadingTimerPage(id: 'timer-1'),
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Waktu membaca: \d{2}:\d{2}')), findsOneWidget);
    });
  });
}
