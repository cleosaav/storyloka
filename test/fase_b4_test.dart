import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/services/sync_service.dart';
import 'package:storyloka/data/database_helper.dart';

/// FakeSyncRemoteSource untuk menguji SyncService di unit test tanpa koneksi internet.
class FakeSyncRemoteSource implements SyncRemoteSource {
  final List<String> pushOrder = [];
  final Map<String, List<Map<String, dynamic>>> tables = {
    'user_books': [],
    'reading_sessions': [],
    'ledger_blocks': [],
    'feedbacks': [],
    'game_scores': [],
  };

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    pushOrder.add(table);
    final list = tables[table] ?? [];
    final id = data['id'];
    list.removeWhere((item) => item['id'] == id);
    list.add(Map<String, dynamic>.from(data));
    tables[table] = list;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRows(
    String table,
    String userId, {
    String? orderBy,
    bool ascending = true,
  }) async {
    final list = tables[table] ?? [];
    var filtered = list.where((row) => row['user_id'] == userId).toList();
    if (orderBy != null) {
      filtered.sort((a, b) {
        final valA = a[orderBy];
        final valB = b[orderBy];
        if (valA is Comparable && valB is Comparable) {
          return ascending ? valA.compareTo(valB) : valB.compareTo(valA);
        }
        return 0;
      });
    }
    return filtered;
  }

  @override
  Future<String?> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    return 'https://supabase.co/storage/v1/object/public/avatars/$userId/avatar.jpg';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late FakeSyncRemoteSource fakeRemote;
  late SyncService syncService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.setTestDatabase(db);
    dbHelper = DatabaseHelper.instance;

    // Inisialisasi tabel-tabel SQLite
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
        list_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'not_started',
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

    fakeRemote = FakeSyncRemoteSource();
    syncService = SyncService(
      dbHelper: dbHelper,
      remoteSource: fakeRemote,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase B4 — SyncService: Push & Urutan Tabel (PRD §8.3)', () {
    test('pushPending mengeksekusi tabel dengan urutan PRD: user_books -> reading_sessions -> ledger_blocks -> feedbacks -> game_scores', () async {
      const userId = 'usr_001';

      // Masukkan baris pending di setiap tabel
      await db.insert('user_books', {
        'id': 'b1',
        'user_id': userId,
        'google_books_id': 'g1',
        'title': 'Bumi Manusia',
        'list_type': 'collection',
        'is_deleted': 0,
        'created_at': '2026-10-22T00:00:00Z',
        'updated_at': '2026-10-22T00:00:00Z',
        'sync_status': 'pending',
      });

      await db.insert('reading_sessions', {
        'id': 's1',
        'user_id': userId,
        'user_book_id': 'b1',
        'started_at': '2026-10-22T01:00:00Z',
        'ended_at': '2026-10-22T01:30:00Z',
        'duration_seconds': 1800,
        'created_at': '2026-10-22T01:30:00Z',
        'sync_status': 'pending',
      });

      await db.insert('ledger_blocks', {
        'id': 'l1',
        'user_id': userId,
        'block_index': 0,
        'timestamp': '2026-10-22T00:00:00Z',
        'data_json': '{"genesis": true}',
        'previous_hash': '0',
        'nonce': 1,
        'hash': '00abc',
        'created_at': '2026-10-22T00:00:00Z',
        'sync_status': 'pending',
      });

      await db.insert('feedbacks', {
        'id': 'f1',
        'user_id': userId,
        'name': 'Budi',
        'impression': 'Sangat bagus',
        'suggestion': 'Pertahankan',
        'created_at': '2026-10-22T02:00:00Z',
        'sync_status': 'pending',
      });

      await db.insert('game_scores', {
        'id': 'g1',
        'user_id': userId,
        'game': 'snake',
        'score': 150,
        'played_at': '2026-10-22T02:30:00Z',
        'sync_status': 'pending',
      });

      // Jalankan push
      await syncService.pushPending(userId: userId);

      // Verifikasi urutan eksekusi push
      expect(fakeRemote.pushOrder, [
        'user_books',
        'reading_sessions',
        'ledger_blocks',
        'feedbacks',
        'game_scores',
      ]);

      // Verifikasi status lokal berubah menjadi 'synced'
      final localBook = await db.query('user_books', where: 'id = ?', whereArgs: ['b1']);
      expect(localBook.first['sync_status'], 'synced');

      final localSession = await db.query('reading_sessions', where: 'id = ?', whereArgs: ['s1']);
      expect(localSession.first['sync_status'], 'synced');

      final localBlock = await db.query('ledger_blocks', where: 'id = ?', whereArgs: ['l1']);
      expect(localBlock.first['sync_status'], 'synced');
    });

    test('pushPending mengubah is_deleted int ke boolean untuk payload remote', () async {
      const userId = 'usr_002';

      await db.insert('user_books', {
        'id': 'b_deleted',
        'user_id': userId,
        'google_books_id': 'g2',
        'title': 'Buku Dihapus',
        'list_type': 'collection',
        'is_deleted': 1, // Soft delete di lokal
        'created_at': '2026-10-22T00:00:00Z',
        'updated_at': '2026-10-22T01:00:00Z',
        'sync_status': 'pending',
      });

      await syncService.pushPending(userId: userId);

      final remoteBooks = fakeRemote.tables['user_books']!;
      expect(remoteBooks.length, 1);
      expect(remoteBooks.first['is_deleted'], isTrue);
      expect(remoteBooks.first.containsKey('sync_status'), isFalse);
    });
  });

  group('Fase B4 — SyncService: Resolusi Konflik Last-Write-Wins (PRD §8.3)', () {
    test('Remote lebih baru daripada lokal -> data lokal ditimpa data remote', () async {
      const userId = 'usr_conflict_1';
      const bookId = 'book_conflict';

      // Data lokal: versi lama (updated_at: 10:00)
      await db.insert('user_books', {
        'id': bookId,
        'user_id': userId,
        'google_books_id': 'gbk_1',
        'title': 'Judul Lama di HP',
        'current_page': 50,
        'list_type': 'collection',
        'is_deleted': 0,
        'created_at': '2026-10-22T08:00:00Z',
        'updated_at': '2026-10-22T10:00:00Z',
        'sync_status': 'synced',
      });

      // Data remote: versi lebih baru (updated_at: 12:00)
      fakeRemote.tables['user_books']!.add({
        'id': bookId,
        'user_id': userId,
        'google_books_id': 'gbk_1',
        'title': 'Judul Baru dari Web',
        'current_page': 120,
        'list_type': 'collection',
        'is_deleted': false,
        'created_at': '2026-10-22T08:00:00Z',
        'updated_at': '2026-10-22T12:00:00Z',
      });

      await syncService.pullAll(userId);

      final localRows = await db.query('user_books', where: 'id = ?', whereArgs: [bookId]);
      expect(localRows.first['title'], 'Judul Baru dari Web');
      expect(localRows.first['current_page'], 120);
      expect(localRows.first['updated_at'], '2026-10-22T12:00:00Z');
      expect(localRows.first['sync_status'], 'synced');
    });

    test('Lokal lebih baru daripada remote -> data lokal dipertahankan (lokal menang)', () async {
      const userId = 'usr_conflict_2';
      const bookId = 'book_local_wins';

      // Data lokal: versi terbaru (updated_at: 15:00)
      await db.insert('user_books', {
        'id': bookId,
        'user_id': userId,
        'google_books_id': 'gbk_2',
        'title': 'Catatan Offline Terbaru',
        'current_page': 210,
        'list_type': 'collection',
        'is_deleted': 0,
        'created_at': '2026-10-22T08:00:00Z',
        'updated_at': '2026-10-22T15:00:00Z',
        'sync_status': 'pending',
      });

      // Data remote: versi lama (updated_at: 11:00)
      fakeRemote.tables['user_books']!.add({
        'id': bookId,
        'user_id': userId,
        'google_books_id': 'gbk_2',
        'title': 'Catatan Usang Server',
        'current_page': 180,
        'list_type': 'collection',
        'is_deleted': false,
        'created_at': '2026-10-22T08:00:00Z',
        'updated_at': '2026-10-22T11:00:00Z',
      });

      await syncService.pullAll(userId);

      final localRows = await db.query('user_books', where: 'id = ?', whereArgs: [bookId]);
      // Lokal tetap menang!
      expect(localRows.first['title'], 'Catatan Offline Terbaru');
      expect(localRows.first['current_page'], 210);
      expect(localRows.first['updated_at'], '2026-10-22T15:00:00Z');
      expect(localRows.first['sync_status'], 'pending');
    });
  });

  group('Fase B4 — SyncService: Idempotensi & Tanpa Duplikasi (PRD §8.3)', () {
    test('pullAll berkali-kali tidak menduplikasi baris di tabel manapun', () async {
      const userId = 'usr_idempotent';

      // Siapkan data di remote
      fakeRemote.tables['user_books']!.add({
        'id': 'b_idem_1',
        'user_id': userId,
        'google_books_id': 'g_idem_1',
        'title': 'Buku Idemp',
        'list_type': 'collection',
        'is_deleted': false,
        'created_at': '2026-10-22T00:00:00Z',
        'updated_at': '2026-10-22T00:00:00Z',
      });

      fakeRemote.tables['reading_sessions']!.add({
        'id': 's_idem_1',
        'user_id': userId,
        'user_book_id': 'b_idem_1',
        'started_at': '2026-10-22T01:00:00Z',
        'ended_at': '2026-10-22T01:15:00Z',
        'duration_seconds': 900,
        'created_at': '2026-10-22T01:15:00Z',
      });

      fakeRemote.tables['ledger_blocks']!.add({
        'id': 'l_idem_1',
        'user_id': userId,
        'block_index': 0,
        'timestamp': '2026-10-22T00:00:00Z',
        'data_json': {'genesis': true},
        'previous_hash': '0',
        'nonce': 10,
        'hash': '00xyz',
        'created_at': '2026-10-22T00:00:00Z',
      });

      fakeRemote.tables['feedbacks']!.add({
        'id': 'f_idem_1',
        'user_id': userId,
        'name': 'Idem',
        'impression': 'Good',
        'suggestion': 'Keep it up',
        'created_at': '2026-10-22T01:00:00Z',
      });

      fakeRemote.tables['game_scores']!.add({
        'id': 'g_idem_1',
        'user_id': userId,
        'game': 'snake',
        'score': 100,
        'played_at': '2026-10-22T01:00:00Z',
      });

      // Panggil pull pertama
      await syncService.pullAll(userId);

      // Verifikasi jumlah row
      var booksCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_books'));
      var sessionsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reading_sessions'));
      var ledgerCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ledger_blocks'));
      var feedbackCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM feedbacks'));
      var scoreCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM game_scores'));

      expect(booksCount, 1);
      expect(sessionsCount, 1);
      expect(ledgerCount, 1);
      expect(feedbackCount, 1);
      expect(scoreCount, 1);

      // Panggil pull kedua & ketiga (simulasi sync berulang)
      await syncService.pullAll(userId);
      await syncService.pullAll(userId);

      // Jumlah baris HARUS tetap 1 di setiap tabel (TIDAK ADA DUPLIKASI)
      booksCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_books'));
      sessionsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reading_sessions'));
      ledgerCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ledger_blocks'));
      feedbackCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM feedbacks'));
      scoreCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM game_scores'));

      expect(booksCount, 1);
      expect(sessionsCount, 1);
      expect(ledgerCount, 1);
      expect(feedbackCount, 1);
      expect(scoreCount, 1);
    });

    test('pushPending berulang kali tidak mengirim baris yang sudah synced', () async {
      const userId = 'usr_push_idem';

      await db.insert('user_books', {
        'id': 'b_push_1',
        'user_id': userId,
        'google_books_id': 'g_push_1',
        'title': 'Buku Sekali Push',
        'list_type': 'collection',
        'is_deleted': 0,
        'created_at': '2026-10-22T00:00:00Z',
        'updated_at': '2026-10-22T00:00:00Z',
        'sync_status': 'pending',
      });

      fakeRemote.pushOrder.clear();

      // Push pertama: harus mengirim b_push_1
      await syncService.pushPending(userId: userId);
      expect(fakeRemote.pushOrder, contains('user_books'));

      fakeRemote.pushOrder.clear();

      // Push kedua: tidak boleh ada yang dikirim karena sudah 'synced'
      await syncService.pushPending(userId: userId);
      expect(fakeRemote.pushOrder, isEmpty);
    });
  });
}
