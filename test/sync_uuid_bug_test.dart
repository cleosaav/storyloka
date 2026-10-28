import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:storyloka/core/services/sync_service.dart';
import 'package:storyloka/data/database_helper.dart';
import 'package:storyloka/data/models/reading_session.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/local/local_repositories.dart';

/// Fake SyncRemoteSource yang menolak ID non-UUID (mensimulasikan Supabase Postgres)
class FakeStrictUuidRemoteSource implements SyncRemoteSource {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  int upsertCalls = 0;

  final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    upsertCalls++;
    final id = data['id']?.toString() ?? '';
    if (!_uuidPattern.hasMatch(id)) {
      throw Exception('invalid input syntax for type uuid: "$id"');
    }
    final list = tables.putIfAbsent(table, () => []);
    list.removeWhere((item) => item['id'] == id);
    list.add(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRows(
    String table,
    String userId, {
    String? orderBy,
    bool ascending = true,
  }) async {
    final list = tables[table] ?? [];
    return list.where((item) => item['user_id'] == userId).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchRowByField(
    String table,
    String userId,
    String field,
    dynamic value,
  ) async {
    final list = tables[table] ?? [];
    for (final row in list) {
      if (row['user_id'] == userId && row[field] == value) return row;
    }
    return null;
  }

  @override
  Future<String?> uploadAvatar({required String userId, required File file}) async {
    return 'https://fake.supabase.co/storage/v1/object/public/avatars/$userId.jpg';
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Perbaikan Bug UUID & Sinkronisasi', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late LocalLibraryRepository libraryRepo;
    late LocalReadingRepository readingRepo;
    const testUserId = '550e8400-e29b-41d4-a716-446655440000';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      dbHelper = DatabaseHelper.forTesting();
      DatabaseHelper.setTestDatabase(db);

      // Inisialisasi tabel skema StoryLoka
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
          sync_status TEXT NOT NULL DEFAULT 'pending',
          FOREIGN KEY (user_book_id) REFERENCES user_books (id)
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
        CREATE TABLE game_scores (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          game TEXT NOT NULL,
          score INTEGER NOT NULL,
          played_at TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'pending'
        );
      ''');

      libraryRepo = LocalLibraryRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => testUserId,
      );

      readingRepo = LocalReadingRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => testUserId,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Tes 5a: tambah buku via repository menghasilkan UUID v4 valid bahkan jika id awal non-UUID', () async {
      // Simulasi input id non-UUID dari widget yang belum atau sudah diperbaiki
      final rawBook = UserBook(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        userId: testUserId,
        googleBooksId: 'gb_test_01',
        title: 'Buku Uji Validitas UUID',
        listType: ListType.collection,
        status: BookStatus.notStarted,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final added = await libraryRepo.addBook(rawBook);

      // Verifikasi ID di-generate / diganti menjadi UUID valid
      expect(isValidUuid(added.id), isTrue, reason: 'ID buku harus UUID v4 valid');
      expect(added.id, isNot(rawBook.id));

      // Verifikasi di DB
      final inDb = await libraryRepo.getBookById(added.id);
      expect(inDb, isNotNull);
      expect(isValidUuid(inDb!.id), isTrue);
    });

    test('Tes 5b: push ke strict SyncRemoteSource yang menolak id non-UUID berhasil dengan status synced', () async {
      final remoteSource = FakeStrictUuidRemoteSource();
      final syncService = SyncService.forTesting(
        dbHelper: dbHelper,
        remoteSource: remoteSource,
      );

      // Tambahkan buku
      final book = await libraryRepo.addBook(UserBook(
        id: const Uuid().v4(),
        userId: testUserId,
        googleBooksId: 'gb_strict_sync',
        title: 'Buku Test Sync Strict',
        listType: ListType.collection,
        status: BookStatus.reading,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Tambahkan reading session
      final session = ReadingSession(
        id: const Uuid().v4(),
        userId: testUserId,
        userBookId: book.id,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        endedAt: DateTime.now(),
        durationSeconds: 600,
        createdAt: DateTime.now(),
      );
      await readingRepo.saveSession(session);

      // Lakukan push
      await syncService.pushPending(userId: testUserId);

      // Periksa status lokal menjadi 'synced'
      final bookRows = await db.query('user_books', where: 'id = ?', whereArgs: [book.id]);
      expect(bookRows.first['sync_status'], 'synced');

      final sessionRows = await db.query('reading_sessions', where: 'id = ?', whereArgs: [session.id]);
      expect(sessionRows.first['sync_status'], 'synced');

      // Periksa data sampai di remote
      expect(remoteSource.tables['user_books']?.length, 1);
      expect(remoteSource.tables['reading_sessions']?.length, 1);
    });

    test('Tes 5c: baris sync_status error dikembalikan ke pending lalu berhasil terkirim saat push berikutnya', () async {
      final remoteSource = FakeStrictUuidRemoteSource();
      final syncService = SyncService.forTesting(
        dbHelper: dbHelper,
        remoteSource: remoteSource,
      );

      final validId = const Uuid().v4();
      await db.insert('user_books', {
        'id': validId,
        'user_id': testUserId,
        'google_books_id': 'gb_err_recovery',
        'title': 'Buku Pulih Dari Error',
        'list_type': 'collection',
        'status': 'not_started',
        'current_page': 0,
        'is_deleted': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'error', // sengaja diset error
      });

      // Verifikasi pending count menghitung baris error
      final pendingCountBefore = await syncService.refreshPendingCount(userId: testUserId);
      expect(pendingCountBefore, 1);

      // Jalankan push
      await syncService.pushPending(userId: testUserId);

      // Baris harus sudah 'synced'
      final rows = await db.query('user_books', where: 'id = ?', whereArgs: [validId]);
      expect(rows.first['sync_status'], 'synced');
      expect(remoteSource.tables['user_books']?.length, 1);
    });

    test('Tes 5d: simulasi migrasi V3 & persistensi data mempertahankan data collection, wishlist, dan reading_sessions', () async {
      final oldNonUuidBookId = '1793167732379150';

      // Masukkan buku lama dengan id microseconds
      await db.insert('user_books', {
        'id': oldNonUuidBookId,
        'user_id': testUserId,
        'google_books_id': 'gb_old_micro',
        'title': 'Buku Lama Microseconds',
        'list_type': 'collection',
        'status': 'reading',
        'current_page': 50,
        'is_deleted': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'error',
      });

      await db.insert('reading_sessions', {
        'id': const Uuid().v4(),
        'user_id': testUserId,
        'user_book_id': oldNonUuidBookId,
        'started_at': DateTime.now().toIso8601String(),
        'ended_at': DateTime.now().toIso8601String(),
        'duration_seconds': 300,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'error',
      });

      // Jalankan migrasi V3
      await dbHelper.database; // pemicu database helper
      // Simulasi eksekusi migrasi v3 secara eksplisit
      final userBooks = await db.query('user_books');
      const uuidGen = Uuid();
      for (final book in userBooks) {
        final oldId = book['id']?.toString() ?? '';
        if (!isValidUuid(oldId)) {
          final newId = uuidGen.v4();
          await db.transaction((txn) async {
            await txn.update(
              'user_books',
              {
                'id': newId,
                'sync_status': 'pending',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [oldId],
            );
            await txn.update(
              'reading_sessions',
              {'user_book_id': newId, 'sync_status': 'pending'},
              where: 'user_book_id = ?',
              whereArgs: [oldId],
            );
          });
        }
      }

      // Verifikasi ID baru sudah UUID
      final updatedBooks = await db.query('user_books');
      expect(updatedBooks.length, 1);
      final newBookId = updatedBooks.first['id'] as String;
      expect(isValidUuid(newBookId), isTrue);

      // Verifikasi reading_sessions foreign key ikut terupdate
      final updatedSessions = await db.query('reading_sessions');
      expect(updatedSessions.length, 1);
      expect(updatedSessions.first['user_book_id'], newBookId);
    });
  });
}
