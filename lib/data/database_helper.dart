import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// DatabaseHelper untuk SQLite lokal — PRD §8.1 (versi 1).
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static DatabaseHelper get instance => _instance;

  DatabaseHelper._internal();

  Database? _db;

  /// Setter untuk pengujian dengan database in-memory / mock.
  static void setTestDatabase(Database? db) {
    _instance._db = db;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'storyloka.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  /// Membuat semua tabel dan indeks sesuai PRD §8.1.
  Future<void> _createTables(Database db) async {
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
  }

  /// Hapus seluruh data tabel lokal (misalnya saat logout sesuai PRD §7.8).
  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.delete('user_books', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('reading_sessions', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('ledger_blocks', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('feedbacks', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('game_scores', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('chat_messages', where: 'user_id = ?', whereArgs: [userId]);
  }

  /// Tutup koneksi database.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
