import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_spacing.dart';
import 'package:storyloka/core/theme/app_text.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/models/feedback_entry.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/reading/finished_book_page.dart';
import 'package:storyloka/features/tools/feedback_page.dart';
import 'package:provider/provider.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    fakeRepositoriesEnableLatency = false;
  });

  tearDown(() {
    fakeRepositoriesEnableLatency = true;
  });

  group('Fase U5: Pembersihan Token & Konsistensi Bahasa Tests', () {
    test('1. Validasi Token Baru AppSpacing dan AppText', () {
      expect(AppSpacing.radiusXs, 4);
      expect(AppSpacing.radiusS, 8);
      expect(AppSpacing.radiusL, 16);
      expect(AppSpacing.radius18, 18);
      expect(AppSpacing.radius22, 22);
      expect(AppSpacing.avatarSmallRadius, 18);
      expect(AppSpacing.avatarMediumRadius, 24);
      expect(AppSpacing.avatarLargeRadius, 32);
      expect(AppSpacing.avatarXLargeRadius, 46);
      expect(AppSpacing.biometricCircleSize, 88);
      expect(AppSpacing.iconXs, 14);
      expect(AppSpacing.iconS, 16);
      expect(AppSpacing.iconM, 20);
      expect(AppSpacing.iconL, 24);
      expect(AppSpacing.iconXl, 32);
      expect(AppSpacing.iconXxl, 48);

      final displayMed = AppText.displayMedium();
      expect(displayMed.fontSize, 36);
    });

    testWidgets('2. FinishedBookPage tombol countdown berbahasa Indonesia', (tester) async {
      final libraryRepo = FakeLibraryRepository();
      const bookId = 'book-fin-u5';
      final testBook = UserBook(
        id: bookId,
        userId: 'u1',
        googleBooksId: 'gb-u5',
        title: 'Laskar Pelangi',
        authors: 'Andrea Hirata',
        pageCount: 300,
        currentPage: 300,
        status: BookStatus.finished,
        listType: ListType.collection,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await libraryRepo.addBook(testBook);

      await tester.pumpWidget(_buildWrapper(
        child: const FinishedBookPage(
          id: bookId,
        ),
        libraryRepo: libraryRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kembali ke Beranda'), findsOneWidget);
    });

    testWidgets('3. FeedbackPage format tanggal menggunakan id_ID', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final feedbackRepo = FakeFeedbackRepository();
      final dt = DateTime(2026, 10, 23, 14, 30);
      await feedbackRepo.save(
        FeedbackEntry(
          id: 'fb-locale-1',
          userId: 'test_user',
          name: 'Siti Rahma',
          impression: 'Materi sangat jelas',
          suggestion: 'Pertahankan metode praktikumnya',
          createdAt: dt,
        ),
      );

      await tester.pumpWidget(_buildWrapper(
        child: const FeedbackPage(),
        feedbackRepo: feedbackRepo,
      ));
      await tester.pumpAndSettle();

      // Memeriksa tanggal format Indonesia: "23 Okt 2026, 14:30"
      expect(find.textContaining('23 Okt 2026'), findsOneWidget);
    });
  });
}
