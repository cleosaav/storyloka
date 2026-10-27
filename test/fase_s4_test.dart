import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/repositories/book_search_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/score_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/features/tools/snake/snake_engine.dart';
import 'package:storyloka/features/tools/snake/snake_page.dart';

Widget _buildWrapper({
  required Widget child,
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
      Provider<LibraryRepository>.value(value: FakeLibraryRepository()),
      Provider<BookSearchRepository>.value(value: FakeBookSearchRepository()),
      Provider<FeedbackRepository>.value(value: FakeFeedbackRepository()),
      Provider<ScoreRepository>.value(value: scoreRepo ?? FakeScoreRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    fakeRepositoriesEnableLatency = false;
  });

  group('Fase S4: Snake Game Grid & Board Geometry Tests', () {
    testWidgets('1. Ukuran 360x640: engine.rows sama dengan baris yang digambar dan sel persegi sempurna',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      // Temukan CustomPaint papan
      final customPaintFinder = find.descendant(
        of: find.byKey(const ValueKey('snake_board_gesture')),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.painter, isA<SnakePainter>());
      final painter = customPaint.painter as SnakePainter;

      final engine = painter.engine;
      final boardSize = customPaint.size;

      // 1. engine.cols adalah 15
      expect(engine.cols, equals(15));

      // 2. Satu sumber kebenaran: baris yang digambar di painter sama persis dengan engine.rows
      final cellW = boardSize.width / engine.cols;
      final expectedRows = engine.rows;
      final expectedHeight = expectedRows * cellW;

      // Tinggi papan tepat rows * cell
      expect(boardSize.height, closeTo(expectedHeight, 0.001));

      // Sel persegi sempurna: cellW == cellH
      final cellH = boardSize.height / expectedRows;
      expect(cellW, closeTo(cellH, 0.001));

      // Ukuran engine.rows setidaknya 10 baris pada layar 360x640
      expect(engine.rows, greaterThanOrEqualTo(10));
    });

    testWidgets(
        '2. Ukuran 360x640: ular bergerak ke bawah tidak game over sebelum menyentuh baris terakhir (rows - 1), dan game over tepat saat melewati batas',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const ValueKey('snake_board_gesture')),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = customPaint.painter as SnakePainter;
      final engine = painter.engine;
      final rows = engine.rows;

      // Tap to start
      await tester.tap(find.text('Tap to start'));
      await tester.pump();
      expect(engine.status, equals(SnakeStatus.running));

      // Set direction down
      engine.setDirection(SnakeDirection.down);

      // Kepala awal berada di tengah (rows ~/ 2)
      final startRow = engine.snake.first.row;
      expect(startRow, equals(rows ~/ 2));

      // Gerakkan ke bawah satu langkah demi satu langkah sampai baris terakhir yang digambar (rows - 1)
      int currentRow = startRow;
      while (currentRow < rows - 1) {
        final isGameOver = engine.tick();
        currentRow = engine.snake.first.row;

        // Pada baris terakhir yang digambar (rows - 1), ular belum game over!
        expect(isGameOver, isFalse,
            reason: 'Ular di baris $currentRow harus masih hidup di papan (rows = $rows)');
        expect(engine.status, equals(SnakeStatus.running));
      }

      // Pastikan kepala sekarang berada tepat di baris terakhir yang terlihat di layar
      expect(engine.snake.first.row, equals(rows - 1));

      // Langkah berikutnya menabrak batas bawah (melewati baris terakhir menuju baris index rows)
      final finalGameOver = engine.tick();
      expect(finalGameOver, isTrue,
          reason: 'Ular harus game over tepat saat melewati baris terakhir papan');
      expect(engine.status, equals(SnakeStatus.gameOver));
    });

    testWidgets('3. Ukuran 800x1280 (Tablet): engine.rows proporsional, sel tetap persegi, dan sinkron dengan painter',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      final customPaintFinder = find.descendant(
        of: find.byKey(const ValueKey('snake_board_gesture')),
        matching: find.byType(CustomPaint),
      );
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as SnakePainter;
      final engine = painter.engine;
      final boardSize = customPaint.size;

      // Di layar tablet 800x1280, jumlah baris bertambah dinamis mengikuti tinggi yang tersedia
      expect(engine.cols, equals(15));
      expect(engine.rows, greaterThan(15));

      final cell = boardSize.width / engine.cols;
      expect(boardSize.height, closeTo(engine.rows * cell, 0.001));

      // Papan dipusatkan di layar
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets(
        '4. Ukuran 800x1280 (Tablet): ular bergerak ke bawah menyentuh baris terakhir tanpa game over prematur',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(find.descendant(
            of: find.byKey(const ValueKey('snake_board_gesture')),
            matching: find.byType(CustomPaint),
          ))
          .painter as SnakePainter;
      final engine = painter.engine;
      final rows = engine.rows;

      engine.start();
      engine.setDirection(SnakeDirection.down);

      // Bergerak turun ke baris terakhir
      while (engine.snake.first.row < rows - 1) {
        final gameOver = engine.tick();
        expect(gameOver, isFalse);
      }

      expect(engine.snake.first.row, equals(rows - 1));
      // Tepat melewati batas
      final dead = engine.tick();
      expect(dead, isTrue);
      expect(engine.status, equals(SnakeStatus.gameOver));
    });

    testWidgets('5. Kontrol Tilt (Gyroscope) tidak memicu pergerakan ular atau auto-start saat baru diaktifkan di state ready',
        (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(find.descendant(
            of: find.byKey(const ValueKey('snake_board_gesture')),
            matching: find.byType(CustomPaint),
          ))
          .painter as SnakePainter;
      final engine = painter.engine;

      expect(engine.status, equals(SnakeStatus.ready));

      // Aktifkan FilterChip Tilt Control
      final tiltChipFinder = find.text('Tilt Control (Gyroscope)');
      expect(tiltChipFinder, findsOneWidget);
      await tester.tap(tiltChipFinder);
      await tester.pumpAndSettle();

      // Permainan TIDAK boleh auto-start hanya karena switch tilt dihidupkan
      expect(engine.status, equals(SnakeStatus.ready));
      expect(engine.direction, equals(SnakeDirection.right));
    });

    testWidgets('6. Swipe gesture diabaikan pada state ready dan paused (hanya aktif saat running)',
        (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      final boardFinder = find.byKey(const ValueKey('snake_board_gesture'));
      final painter = tester
          .widget<CustomPaint>(find.descendant(
            of: boardFinder,
            matching: find.byType(CustomPaint),
          ))
          .painter as SnakePainter;
      final engine = painter.engine;

      // 1. Pada state ready: swipe ke bawah diabaikan
      await tester.drag(boardFinder, const Offset(0, 100));
      await tester.pump();
      expect(engine.status, equals(SnakeStatus.ready));
      expect(engine.direction, equals(SnakeDirection.right));

      // 2. Mulai game
      await tester.tap(find.text('Tap to start'));
      await tester.pump();
      expect(engine.status, equals(SnakeStatus.running));

      // 3. Jeda game
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(engine.status, equals(SnakeStatus.paused));

      // 4. Pada state paused: swipe ke atas diabaikan
      await tester.drag(boardFinder, const Offset(0, -100));
      await tester.pump();
      expect(engine.direction, equals(SnakeDirection.right));
      expect(engine.status, equals(SnakeStatus.paused));
    });

    testWidgets('7. Restart setelah game over (Play again) mereset skor, ular kembali ke tengah, dan timer berjalan',
        (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      final painter = tester
          .widget<CustomPaint>(find.descendant(
            of: find.byKey(const ValueKey('snake_board_gesture')),
            matching: find.byType(CustomPaint),
          ))
          .painter as SnakePainter;
      final engine = painter.engine;

      // Mulai permainan
      await tester.tap(find.text('Tap to start'));
      await tester.pump();

      // Arahkan ular ke atas menggunakan tombol D-Pad
      await tester.tap(find.bySemanticsLabel('Gerak ke atas'));
      await tester.pump();

      // Biarkan timer berjalan sampai menabrak dinding atas
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.text('Game Over!').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      // Bottom sheet Game Over muncul
      expect(find.text('Game Over!'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);

      // Tekan Play again
      await tester.tap(find.text('Play again'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Bottom sheet tertutup
      expect(find.text('Game Over!'), findsNothing);

      // Skor 0, status running, kepala di baris tengah dan bergerak ke kanan
      expect(engine.score, equals(0));
      expect(engine.status, equals(SnakeStatus.running));
      expect(engine.snake.first.row, equals(engine.rows ~/ 2));
      expect(engine.snake.first.col, greaterThanOrEqualTo(engine.cols ~/ 2));
    });

    testWidgets('8. Timer permainan dibatalkan secara bersih saat dispose tanpa exception',
        (tester) async {
      await tester.pumpWidget(_buildWrapper(child: const SnakePage()));
      await tester.pumpAndSettle();

      // Mulai game agar timer aktif
      await tester.tap(find.text('Tap to start'));
      await tester.pump();

      // Ganti widget (unmount SnakePage)
      await tester.pumpWidget(_buildWrapper(child: const Scaffold(body: Text('Layar Lain'))));
      await tester.pumpAndSettle();

      // Tidak ada timer bocor yang melempar exception
      expect(find.text('Layar Lain'), findsOneWidget);
    });

    test('9. Engine murni: mempertahankan semua pengujian pergerakan dan ukuran papan', () {
      final engine = SnakeEngine(cols: 15, rows: 25, random: Random(0));
      expect(engine.cols, equals(15));
      expect(engine.rows, equals(25));
      expect(engine.snake.first.row, equals(12));
      expect(engine.snake.first.col, equals(7));

      engine.start();
      engine.setDirection(SnakeDirection.down);
      engine.tick();
      expect(engine.snake.first.row, equals(13));
    });
  });
}
