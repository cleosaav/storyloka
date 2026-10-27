import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/services/sync_service.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/widgets/widgets.dart';
import 'package:storyloka/data/models/ledger_block.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/profile/reading_ledger_page.dart';

Widget _buildLedgerTestWrapper({
  required Widget child,
  required AuthController authController,
  required LedgerRepository ledgerRepo,
  required LedgerService ledgerService,
  SyncService? syncService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: authController),
      ChangeNotifierProvider<ThemeController>.value(value: ThemeController()),
      ChangeNotifierProvider<SyncService>.value(
        value: syncService ?? SyncService.instance,
      ),
      Provider<LedgerRepository>.value(value: ledgerRepo),
      Provider<LedgerService>.value(value: ledgerService),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void _setupLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    fakeRepositoriesEnableLatency = false;
  });

  group('Fase S5: Reading Ledger Tests', () {
    testWidgets('1. State Unauthenticated: Menampilkan state Silakan Masuk tanpa fallback demo_user',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      // Pastikan currentUser adalah null
      expect(authController.currentUser, isNull);

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: ledgerRepo,
          ledgerService: ledgerService,
        ),
      );
      await tester.pumpAndSettle();

      // State Silakan Masuk harus terlihat
      expect(find.text('Silakan Masuk'), findsOneWidget);
      expect(find.text('Masuk Sekarang'), findsOneWidget);

      // Tidak boleh membuat blok untuk demo_user palsu
      final blocks = await ledgerRepo.getBlocks();
      expect(blocks, isEmpty);
    });

    testWidgets('2. Deskripsi faktual tampil dan TIDAK ada banner demo/simulasi atau emoji',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      // Login user nyata
      await authController.login('test@storyloka.app', 'password123');
      expect(authController.currentUser, isNotNull);

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: ledgerRepo,
          ledgerService: ledgerService,
        ),
      );
      await tester.pumpAndSettle();

      // Deskripsi faktual yang jujur
      expect(
        find.textContaining(
          'Setiap buku yang selesai kamu baca dicatat sebagai blok. Blok saling terhubung lewat hash SHA-256 dan Proof of Work; mengubah satu data saja membuat rantai tidak valid.',
        ),
        findsOneWidget,
      );

      // Tidak boleh ada teks banner demo lama
      expect(find.textContaining('Simulasi edukatif single-node'), findsNothing);
      expect(find.textContaining('ℹ️'), findsNothing);
    });

    testWidgets('3. Ringkasan di bagian atas & auto-verify saat halaman dibuka',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      await authController.login('test@storyloka.app', 'password123');
      final userId = authController.currentUser!.id;

      // Tambahkan sebuah buku selesai ke ledger
      final userBook = UserBook(
        id: 'book_1',
        userId: userId,
        googleBooksId: 'gb_123',
        title: 'Laskar Pelangi',
        authors: 'Andrea Hirata',
        pageCount: 529,
        listType: ListType.collection,
        status: BookStatus.finished,
        finishedAt: DateTime.now(),
        rating: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ledgerService.appendFinishedBook(
        userBook,
        userId: userId,
        totalReadingSeconds: 7200,
      );

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: ledgerRepo,
          ledgerService: ledgerService,
        ),
      );
      await tester.pumpAndSettle();

      // Ringkasan harus menunjukkan 2 Blok (Genesis + Laskar Pelangi) dan 1 Buku Tercatat
      expect(find.text('Ringkasan Ledger'), findsOneWidget);
      expect(find.text('2 Blok'), findsWidgets);
      expect(find.text('1 Buku'), findsOneWidget);

      // Auto-verify harus langsung berjalan dan menghasilkan status valid
      expect(find.textContaining('Valid'), findsWidgets);
    });

    testWidgets('4. Tombol manual Verify Ledger memicu verifikasi dan menampilkan hasil',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      await authController.login('test@storyloka.app', 'password123');

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: ledgerRepo,
          ledgerService: ledgerService,
        ),
      );
      await tester.pumpAndSettle();

      final verifyBtn = find.widgetWithText(PrimaryButton, 'Verify Ledger');
      expect(verifyBtn, findsOneWidget);

      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Rantai Utuh & Valid'), findsOneWidget);
    });

    testWidgets('5. Blok yang rusak ditandai dengan jelas saat manipulasi rantai terdeteksi',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      await authController.login('test@storyloka.app', 'password123');
      final userId = authController.currentUser!.id;

      // Buat genesis
      await ledgerService.ensureGenesisBlock(userId);

      // Tambahkan blok buku
      final userBook = UserBook(
        id: 'book_tamper',
        userId: userId,
        googleBooksId: 'gb_tamper',
        title: 'Buku Asli',
        authors: 'Penulis Asli',
        listType: ListType.collection,
        status: BookStatus.finished,
        finishedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final validBlock = await ledgerService.appendFinishedBook(userBook, userId: userId);

      // Simulasikan blok yang rusak (data dimodifikasi tanpa menghitung ulang hash)
      final allBlocks = await ledgerRepo.getBlocks();
      final tamperedData = Map<String, dynamic>.from(validBlock.dataJson);
      tamperedData['title'] = 'Buku Dimanipulasi!';

      final tamperedBlock = LedgerBlock(
        id: validBlock.id,
        userId: validBlock.userId,
        blockIndex: validBlock.blockIndex,
        timestamp: validBlock.timestamp,
        dataJson: tamperedData,
        previousHash: validBlock.previousHash,
        nonce: validBlock.nonce,
        hash: validBlock.hash, // Hash lama tidak cocok lagi!
        createdAt: validBlock.createdAt,
        syncStatus: validBlock.syncStatus,
      );

      // Simpan blok tampered ke repo
      final customRepo = _CustomBlocksLedgerRepo([allBlocks[0], tamperedBlock]);
      final customService = LedgerService(customRepo);

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: customRepo,
          ledgerService: customService,
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi harus mendeteksi blok #1 tidak valid
      expect(find.textContaining('Blok #1 Tidak Valid'), findsWidgets);
      expect(find.text('Rusak / Tidak Valid'), findsOneWidget);
    });

    testWidgets('6. Ketuk blok membuka bottom sheet detail lengkap dengan hash SHA-256 dan JSON',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      await authController.login('test@storyloka.app', 'password123');
      final userId = authController.currentUser!.id;

      final userBook = UserBook(
        id: 'book_detail_test',
        userId: userId,
        googleBooksId: 'gb_detail',
        title: 'Bumi Manusia',
        authors: 'Pramoedya Ananta Toer',
        pageCount: 535,
        rating: 5,
        listType: ListType.collection,
        status: BookStatus.finished,
        finishedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ledgerService.appendFinishedBook(userBook, userId: userId, totalReadingSeconds: 3600);

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: ledgerRepo,
          ledgerService: ledgerService,
        ),
      );
      await tester.pumpAndSettle();

      // Temukan kartu blok Bumi Manusia dan ketuk
      final bookCard = find.text('Bumi Manusia');
      expect(bookCard, findsOneWidget);
      await tester.tap(bookCard);
      await tester.pumpAndSettle();

      // Bottom sheet detail harus muncul
      expect(find.text('Hash Blok (SHA-256)'), findsOneWidget);
      expect(find.text('Previous Hash'), findsOneWidget);
      expect(find.text('Data Payload (Kanonikal JSON)'), findsOneWidget);
      expect(find.text('535 hal'), findsOneWidget);
      expect(find.text('1 jam'), findsOneWidget);
      expect(find.text('5 dari 5 Bintang'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Tutup bottom sheet
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Hash Blok (SHA-256)'), findsNothing);
    });

    testWidgets('7. Genesis block otomatis dibuat saat Register akun baru dan bersifat idempoten',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      // Belum ada blok
      expect(await ledgerRepo.getBlocks(), isEmpty);

      // Lakukan pendaftaran
      final success = await authController.register(
        name: 'Budi Santoso',
        email: 'budi@storyloka.test',
        password: 'password123',
      );
      expect(success, isTrue);

      // Genesis block harus sudah dibuat otomatis
      final blocks = await ledgerRepo.getBlocks();
      expect(blocks.length, equals(1));
      expect(blocks.first.blockIndex, equals(0));
      expect(blocks.first.previousHash, equals('0'));
      expect(blocks.first.dataJson['message'], equals('StoryLoka genesis'));

      // Pemanggilan register/login ulang atau ensureGenesisBlock tidak menduplikasi blok
      await ledgerService.ensureGenesisBlock(authController.currentUser!.id);
      final blocksAfter = await ledgerRepo.getBlocks();
      expect(blocksAfter.length, equals(1));
    });

    testWidgets('8. Mode uji manipulasi kDebugMode mendeteksi kerusakan rantai saat ditekan',
        (tester) async {
      _setupLargeViewport(tester);

      final session = SecureSessionStore();
      final demoControls = DemoControls();
      final authRepo = FakeAuthRepository(sessionStore: session);
      final ledgerRepo = FakeLedgerRepository();
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: session,
        demoControls: demoControls,
        ledgerService: ledgerService,
      );

      await authController.login('test@storyloka.app', 'password123');

      await tester.pumpWidget(
        _buildLedgerTestWrapper(
          child: const ReadingLedgerPage(),
          authController: authController,
          ledgerRepo: ledgerRepo,
          ledgerService: ledgerService,
        ),
      );
      await tester.pumpAndSettle();

      if (kDebugMode) {
        final tamperBtn = find.text('Ubah data blok (uji)');
        expect(tamperBtn, findsOneWidget);

        await tester.tap(tamperBtn);
        await tester.pumpAndSettle();

        // Manipulasi terdeteksi oleh sistem verifikasi
        expect(find.textContaining('Tidak Valid'), findsWidgets);
      }
    });
  });
}

class _CustomBlocksLedgerRepo implements LedgerRepository {
  final List<LedgerBlock> _blocks;
  _CustomBlocksLedgerRepo(this._blocks);

  @override
  Future<List<LedgerBlock>> getBlocks() async => List.of(_blocks);

  @override
  Future<LedgerBlock?> getLastBlock() async => _blocks.isNotEmpty ? _blocks.last : null;

  @override
  Future<void> saveBlock(LedgerBlock block) async {
    _blocks.add(block);
  }
}
