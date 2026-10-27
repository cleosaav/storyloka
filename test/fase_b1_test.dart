import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/data/database_helper.dart';
import 'package:storyloka/data/models/game_score.dart';
import 'package:storyloka/data/models/reading_session.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/local/local_repositories.dart';

void main() {
  // Inisialisasi sqflite FFI untuk desktop / test runner
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;

  setUp(() async {
    // Gunakan in-memory database unik untuk setiap test
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.setTestDatabase(db);
    dbHelper = DatabaseHelper.instance;

    // Trigger inisialisasi tabel
    await db.execute('''
      CREATE TABLE user_books (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        google_books_id TEXT NOT NULL,
        title TEXT NOT NULL,
        authors TEXT,
        genre TEXT,
        isbn TEXT,
        publisher TEXT,
        page_count INTEGER,
        cover_url TEXT,
        synopsis TEXT,
        price_amount REAL,
        price_currency TEXT,
        list_type TEXT NOT NULL CHECK (list_type IN ('collection','wishlist')),
        status TEXT NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started','reading','finished')),
        current_page INTEGER NOT NULL DEFAULT 0,
        rating INTEGER,
        review TEXT,
        started_at TEXT,
        finished_at TEXT,
        last_read_at TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        UNIQUE (user_id, google_books_id)
      );
    ''');

    await db.execute('''
      CREATE TABLE reading_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_book_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      );
    ''');

    await db.execute('''
      CREATE TABLE ledger_blocks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        block_index INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        data_json TEXT NOT NULL,
        previous_hash TEXT NOT NULL,
        nonce INTEGER NOT NULL,
        hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        UNIQUE (user_id, block_index)
      );
    ''');

    await db.execute('''
      CREATE TABLE feedbacks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        impression TEXT NOT NULL,
        suggestion TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      );
    ''');

    await db.execute('''
      CREATE TABLE game_scores (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        game TEXT NOT NULL,
        score INTEGER NOT NULL,
        played_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      );
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('user','model')),
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX idx_user_books_user ON user_books(user_id, list_type, is_deleted);',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_book ON reading_sessions(user_book_id);',
    );
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Fase B1: LocalLibraryRepository Tests', () {
    test('Tambah buku ke koleksi, perbarui progress, soft delete', () async {
      final repo = LocalLibraryRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000001',
      );

      final now = DateTime.now().toUtc();
      final book = UserBook(
        id: 'book_1',
        userId: '00000000-0000-4000-8000-000000000001',
        googleBooksId: 'gb_001',
        title: 'Bumi Manusia',
        authors: 'Pramoedya Ananta Toer',
        listType: ListType.collection,
        status: BookStatus.reading,
        currentPage: 50,
        pageCount: 500,
        createdAt: now,
        updatedAt: now,
      );

      // Add
      final added = await repo.addBook(book);
      expect(added.id, 'book_1');
      expect(added.title, 'Bumi Manusia');

      // Get
      final books = await repo.getBooks(listType: ListType.collection);
      expect(books.length, 1);
      expect(books.first.currentPage, 50);

      // Find by googleBooksId
      final found = await repo.findByGoogleBooksId('gb_001');
      expect(found, isNotNull);
      expect(found!.id, 'book_1');

      // Update
      final updated = await repo.updateBook(book.copyWith(
        currentPage: 150,
        status: BookStatus.reading,
      ));
      expect(updated.currentPage, 150);

      final retrieved = await repo.getBookById('book_1');
      expect(retrieved?.currentPage, 150);

      // Currently reading
      final current = await repo.getCurrentlyReading();
      expect(current, isNotNull);
      expect(current!.id, 'book_1');

      // Soft delete
      await repo.deleteBook('book_1');
      final booksAfterDelete = await repo.getBooks();
      expect(booksAfterDelete, isEmpty);

      final afterDelete = await repo.getBookById('book_1');
      expect(afterDelete, isNull);
    });

    test('Pindah buku dari wishlist ke collection', () async {
      final repo = LocalLibraryRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000001',
      );

      final now = DateTime.now().toUtc();
      final wishlistBook = UserBook(
        id: 'book_wish',
        userId: '00000000-0000-4000-8000-000000000001',
        googleBooksId: 'gb_002',
        title: 'Laskar Pelangi',
        listType: ListType.wishlist,
        createdAt: now,
        updatedAt: now,
      );

      await repo.addBook(wishlistBook);
      expect((await repo.getBooks(listType: ListType.wishlist)).length, 1);
      expect((await repo.getBooks(listType: ListType.collection)).length, 0);

      // Move to collection
      final moved = await repo.moveToCollection('book_wish');
      expect(moved.listType, ListType.collection);

      expect((await repo.getBooks(listType: ListType.wishlist)).length, 0);
      expect((await repo.getBooks(listType: ListType.collection)).length, 1);
    });
  });

  group('Fase B1: LocalReadingRepository Tests', () {
    test('Simpan sesi membaca dan hitung total durasi', () async {
      final repo = LocalReadingRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000001',
      );

      final now = DateTime.now().toUtc();
      final session1 = ReadingSession(
        id: 's1',
        userId: '00000000-0000-4000-8000-000000000001',
        userBookId: 'book_1',
        startedAt: now.subtract(const Duration(minutes: 30)),
        endedAt: now,
        durationSeconds: 1800,
        createdAt: now,
      );

      final session2 = ReadingSession(
        id: 's2',
        userId: '00000000-0000-4000-8000-000000000001',
        userBookId: 'book_1',
        startedAt: now.subtract(const Duration(minutes: 60)),
        endedAt: now.subtract(const Duration(minutes: 40)),
        durationSeconds: 1200,
        createdAt: now,
      );

      await repo.saveSession(session1);
      await repo.saveSession(session2);

      final sessions = await repo.getSessionsForBook('book_1');
      expect(sessions.length, 2);

      final allSessions = await repo.getAllSessions();
      expect(allSessions.length, 2);

      final totalSeconds = await repo.getTotalReadingSeconds();
      expect(totalSeconds, 3000);
    });
  });

  group('Fase B1: LocalLedgerRepository & LedgerService Tests', () {
    test('Simpan blok, ambil genesis block, dan verifikasi integritas', () async {
      final repo = LocalLedgerRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000001',
      );
      final ledgerService = LedgerService(repo);

      // Buat genesis block
      final genesis = await ledgerService.ensureGenesisBlock('00000000-0000-4000-8000-000000000001');
      expect(genesis.blockIndex, 0);
      expect(genesis.previousHash, '0');
      expect(genesis.hash.startsWith('00'), isTrue);

      final last = await repo.getLastBlock();
      expect(last, isNotNull);
      expect(last!.blockIndex, 0);

      // Tambahkan blok buku selesai
      final now = DateTime.now().toUtc();
      final finishedBook = UserBook(
        id: 'book_finished_1',
        userId: '00000000-0000-4000-8000-000000000001',
        googleBooksId: 'gb_fin_1',
        title: 'Filosofi Teras',
        authors: 'Henry Manampiring',
        listType: ListType.collection,
        status: BookStatus.finished,
        currentPage: 320,
        pageCount: 320,
        rating: 5,
        review: 'Buku yang sangat menginspirasi.',
        finishedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final newBlock = await ledgerService.appendFinishedBook(
        finishedBook,
        userId: '00000000-0000-4000-8000-000000000001',
        totalReadingSeconds: 3600,
      );
      expect(newBlock, isNotNull);
      expect(newBlock.blockIndex, 1);
      expect(newBlock.previousHash, genesis.hash);
      expect(newBlock.hash.startsWith('00'), isTrue);

      // Verifikasi rantai
      final blocks = await repo.getBlocks();
      expect(blocks.length, 2);

      final verifyResult = LedgerService.verifyChain(blocks);
      expect(verifyResult.isValid, isTrue);
    });
  });

  group('Fase B1: LocalFeedbackRepository Tests (Read-Only — S7)', () {
    test('Ambil daftar kesan & pesan tim PAM', () async {
      const validUserId = '00000000-0000-4000-8000-000000000001';
      final repo = LocalFeedbackRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => validUserId,
      );

      final list = await repo.getAll();
      expect(list.length, 3);
      expect(list.first.name, 'Najmah Cleosa');
      expect(list.last.name, 'Naftali Margareta');
    });
  });

  group('Fase B1: LocalScoreRepository Tests', () {
    test('Simpan skor Snake dan hitung high score', () async {
      final repo = LocalScoreRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000001',
      );

      final now = DateTime.now().toUtc();
      await repo.saveScore(GameScore(
        id: 'sc_1',
        userId: '00000000-0000-4000-8000-000000000001',
        game: 'snake',
        score: 30,
        playedAt: now,
      ));

      await repo.saveScore(GameScore(
        id: 'sc_2',
        userId: '00000000-0000-4000-8000-000000000001',
        game: 'snake',
        score: 70,
        playedAt: now.add(const Duration(minutes: 5)),
      ));

      final scores = await repo.getScores('snake');
      expect(scores.length, 2);
      expect(scores.first.score, 70); // urut skor tertinggi

      final highScore = await repo.getHighScore('snake');
      expect(highScore, 70);
    });
  });

  group('Fase B1: LocalChatRepository Tests', () {
    test('Simpan dan ambil riwayat chat lokal', () async {
      final repo = LocalChatRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000001',
      );

      final reply = await repo.sendMessage('Rekomendasi buku fantasi', []);
      expect(reply.isNotEmpty, isTrue);

      final history = await repo.getHistory();
      expect(history.length, 2); // 1 user + 1 model
      expect(history.first.role, 'user');
      expect(history.first.content, 'Rekomendasi buku fantasi');
      expect(history.last.role, 'model');

      await repo.clearHistory();
      final cleared = await repo.getHistory();
      expect(cleared, isEmpty);
    });
  });

  group('Fase B1: DoD Persistensi Data (Tutup & Buka Aplikasi)', () {
    test('Data di database SQLite bertahan setelah instansiasi repository baru', () async {
      // 1. Simpan data lewat instance repo pertama
      final repo1 = LocalLibraryRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000002',
      );

      final now = DateTime.now().toUtc();
      await repo1.addBook(UserBook(
        id: 'persist_book_1',
        userId: '00000000-0000-4000-8000-000000000002',
        googleBooksId: 'gb_persist_01',
        title: 'Atomic Habits',
        authors: 'James Clear',
        listType: ListType.collection,
        status: BookStatus.reading,
        currentPage: 120,
        pageCount: 320,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Simulasikan aplikasi ditutup dan dibuka kembali dengan membuat instance baru
      final repo2 = LocalLibraryRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => '00000000-0000-4000-8000-000000000002',
      );

      final loadedBooks = await repo2.getBooks(listType: ListType.collection);
      expect(loadedBooks.length, 1);
      expect(loadedBooks.first.id, 'persist_book_1');
      expect(loadedBooks.first.title, 'Atomic Habits');
      expect(loadedBooks.first.currentPage, 120);
    });
  });
}
