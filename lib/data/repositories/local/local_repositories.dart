import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/secure_session_store.dart';
import '../../../core/services/sync_service.dart';
import '../../database_helper.dart';
import '../../models/chat_message.dart';
import '../../models/game_score.dart';
import '../../models/ledger_block.dart';
import '../../models/reading_session.dart';
import '../../models/user_book.dart';
import '../chat_repository.dart';
import '../feedback_repository.dart';
import '../../static/team_feedback.dart';
import '../ledger_repository.dart';
import '../library_repository.dart';
import '../reading_repository.dart';
import '../score_repository.dart';

const _uuid = Uuid();

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Memeriksa apakah sebuah string merupakan format UUID valid (RFC 4122) — PRD §8.1 & Fase S7.
bool isValidUuid(String? id) {
  if (id == null || id.trim().isEmpty) return false;
  return _uuidPattern.hasMatch(id.trim());
}

/// Helper untuk mengambil ID user saat ini dari session store atau userIdProvider.
/// Memeriksa validitas UUID dan menolak fallback palsu ('default_user', 'demo', dll).
/// Melempar StateError jika sesi tidak tersedia atau ID tidak valid — PRD §7.1 & Fase S7.
Future<String> _resolveUserId({
  SecureSessionStore? sessionStore,
  Future<String> Function()? userIdProvider,
}) async {
  if (userIdProvider != null) {
    final raw = await userIdProvider();
    if (isValidUuid(raw)) {
      return raw;
    }
    throw StateError('NO_AUTHENTICATED_USER: ID pengguna "$raw" tidak valid atau fallback palsu.');
  }
  if (sessionStore != null) {
    final user = await sessionStore.getUser();
    if (user != null && user.id.isNotEmpty && isValidUuid(user.id)) {
      return user.id;
    }
  }
  throw StateError('NO_AUTHENTICATED_USER: Sesi pengguna tidak ditemukan atau belum login.');
}

// ═══════════════════════════════════════════════════
// Local Library Repository (SQLite) — PRD §8.1 & §13.0
// ═══════════════════════════════════════════════════

class LocalLibraryRepository implements LibraryRepository {
  final DatabaseHelper dbHelper;
  final SecureSessionStore? sessionStore;
  final Future<String> Function()? userIdProvider;

  LocalLibraryRepository({
    DatabaseHelper? dbHelper,
    this.sessionStore,
    this.userIdProvider,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> _getUserId() async =>
      _resolveUserId(sessionStore: sessionStore, userIdProvider: userIdProvider);

  @override
  Future<List<UserBook>> getBooks({ListType? listType}) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    List<Map<String, dynamic>> maps;
    if (listType != null) {
      maps = await db.query(
        'user_books',
        where: 'user_id = ? AND is_deleted = 0 AND list_type = ?',
        whereArgs: [userId, listType.value],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'user_books',
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    }

    return maps.map((m) => UserBook.fromMap(m)).toList();
  }

  @override
  Future<UserBook?> getBookById(String id) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();
    final maps = await db.query(
      'user_books',
      where: 'id = ? AND user_id = ? AND is_deleted = 0',
      whereArgs: [id, userId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return UserBook.fromMap(maps.first);
  }

  @override
  Future<UserBook?> findByGoogleBooksId(String googleBooksId) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'user_books',
      where: 'user_id = ? AND google_books_id = ? AND is_deleted = 0',
      whereArgs: [userId, googleBooksId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return UserBook.fromMap(maps.first);
  }

  @override
  Future<UserBook> addBook(UserBook book) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();
    final now = DateTime.now().toUtc();

    // Pastikan user_id sesuai user aktif dan id merupakan UUID valid (PRD §8.1)
    // Jika id kosong atau berupa angka murni (microseconds timestamp seperti bug lama), buat UUID v4 baru.
    final isMicrosecondsOrEmpty = book.id.trim().isEmpty || int.tryParse(book.id.trim()) != null;
    final resolvedBookId = isMicrosecondsOrEmpty ? _uuid.v4() : book.id;
    final resolvedUserId = book.userId.isEmpty ? userId : book.userId;

    final targetBook = UserBook(
      id: resolvedBookId,
      userId: resolvedUserId,
      googleBooksId: book.googleBooksId,
      title: book.title,
      authors: book.authors,
      genre: book.genre,
      isbn: book.isbn,
      publisher: book.publisher,
      pageCount: book.pageCount,
      coverUrl: book.coverUrl,
      synopsis: book.synopsis,
      priceAmount: book.priceAmount,
      priceCurrency: book.priceCurrency,
      listType: book.listType,
      status: book.status,
      currentPage: book.currentPage,
      rating: book.rating,
      review: book.review,
      startedAt: book.startedAt,
      finishedAt: book.finishedAt,
      lastReadAt: book.lastReadAt,
      isDeleted: false,
      createdAt: book.createdAt,
      updatedAt: now,
      syncStatus: 'pending',
    );

    // Cek apakah buku sudah pernah ada untuk user ini (termasuk yang soft-deleted)
    final existing = await db.query(
      'user_books',
      where: 'user_id = ? AND google_books_id = ?',
      whereArgs: [targetBook.userId, targetBook.googleBooksId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final oldBook = UserBook.fromMap(existing.first);
      if (oldBook.isDeleted) {
        // Restore buku yang terhapus:
        // Bersihkan status baca kembali ke awal (not_started, current_page = 0)
        // kecuali jika targetBook memang membawa progres yang disengaja.
        final hasExplicitProgress = targetBook.currentPage > 0 ||
            targetBook.status != BookStatus.notStarted;
        final restored = UserBook(
          id: oldBook.id,
          userId: oldBook.userId,
          googleBooksId: oldBook.googleBooksId,
          title: oldBook.title,
          authors: oldBook.authors,
          genre: oldBook.genre,
          isbn: oldBook.isbn,
          publisher: oldBook.publisher,
          pageCount: oldBook.pageCount,
          coverUrl: oldBook.coverUrl,
          synopsis: oldBook.synopsis,
          priceAmount: oldBook.priceAmount,
          priceCurrency: oldBook.priceCurrency,
          listType: targetBook.listType,
          status: hasExplicitProgress ? targetBook.status : BookStatus.notStarted,
          currentPage: hasExplicitProgress ? targetBook.currentPage : 0,
          rating: hasExplicitProgress ? targetBook.rating : null,
          review: hasExplicitProgress ? targetBook.review : null,
          startedAt: hasExplicitProgress ? targetBook.startedAt : null,
          finishedAt: hasExplicitProgress ? targetBook.finishedAt : null,
          lastReadAt: hasExplicitProgress ? targetBook.lastReadAt : null,
          isDeleted: false,
          createdAt: oldBook.createdAt,
          updatedAt: now,
          syncStatus: 'pending',
        );
        await updateBook(restored);
        return restored;
      }
      if (oldBook.listType == ListType.wishlist &&
          targetBook.listType == ListType.collection) {
        // Pindahkan dari wishlist ke collection
        final moved = oldBook.copyWith(
          listType: ListType.collection,
          updatedAt: now,
          syncStatus: 'pending',
        );
        await updateBook(moved);
        return moved;
      }
      return oldBook;
    }

    final data = targetBook.toMap();
    await db.insert(
      'user_books',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    SyncService.instance.trigger();

    return targetBook;
  }

  @override
  Future<UserBook> updateBook(UserBook book) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toUtc();
    final updated = book.copyWith(
      updatedAt: now,
      syncStatus: 'pending',
    );

    await db.update(
      'user_books',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
    SyncService.instance.trigger();

    return updated;
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'user_books',
      {
        'is_deleted': 1,
        'updated_at': now,
        'sync_status': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    SyncService.instance.trigger();
  }

  @override
  Future<UserBook> moveToCollection(String id) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'user_books',
      {
        'list_type': ListType.collection.value,
        'updated_at': now,
        'sync_status': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    SyncService.instance.trigger();

    final updated = await getBookById(id);
    if (updated == null) {
      throw Exception('Book not found: $id');
    }
    return updated;
  }

  @override
  Future<UserBook?> getCurrentlyReading() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'user_books',
      where:
          'user_id = ? AND status = ? AND list_type = ? AND is_deleted = 0',
      whereArgs: [
        userId,
        BookStatus.reading.value,
        ListType.collection.value,
      ],
      orderBy: 'COALESCE(last_read_at, started_at, created_at) DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return UserBook.fromMap(maps.first);
  }
}

// ═══════════════════════════════════════════════════
// Local Reading Repository (SQLite) — PRD §8.1 & §13.0
// ═══════════════════════════════════════════════════

class LocalReadingRepository implements ReadingRepository {
  final DatabaseHelper dbHelper;
  final SecureSessionStore? sessionStore;
  final Future<String> Function()? userIdProvider;

  LocalReadingRepository({
    DatabaseHelper? dbHelper,
    this.sessionStore,
    this.userIdProvider,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> _getUserId() async =>
      _resolveUserId(sessionStore: sessionStore, userIdProvider: userIdProvider);

  @override
  Future<void> saveSession(ReadingSession session) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final isMicrosecondsOrEmpty = session.id.trim().isEmpty || int.tryParse(session.id.trim()) != null;
    final resolvedSessionId = isMicrosecondsOrEmpty ? _uuid.v4() : session.id;
    final resolvedUserId =
        session.userId.isEmpty ? userId : session.userId;

    final sessionToSave = ReadingSession(
      id: resolvedSessionId,
      userId: resolvedUserId,
      userBookId: session.userBookId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSeconds: session.durationSeconds,
      createdAt: session.createdAt,
      syncStatus: 'pending',
    );

    await db.insert(
      'reading_sessions',
      sessionToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    SyncService.instance.trigger();
  }

  @override
  Future<List<ReadingSession>> getSessionsForBook(String userBookId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'reading_sessions',
      where: 'user_book_id = ?',
      whereArgs: [userBookId],
      orderBy: 'started_at DESC',
    );
    return maps.map((m) => ReadingSession.fromMap(m)).toList();
  }

  @override
  Future<List<ReadingSession>> getAllSessions() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'reading_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'started_at DESC',
    );
    return maps.map((m) => ReadingSession.fromMap(m)).toList();
  }

  @override
  Future<int> getTotalReadingSeconds() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final result = await db.rawQuery(
      'SELECT SUM(duration_seconds) as total FROM reading_sessions WHERE user_id = ?',
      [userId],
    );

    if (result.isEmpty || result.first['total'] == null) return 0;
    return (result.first['total'] as num).toInt();
  }
}

// ═══════════════════════════════════════════════════
// Local Ledger Repository (SQLite) — PRD §8.1 & §10.2
// ═══════════════════════════════════════════════════

class LocalLedgerRepository implements LedgerRepository {
  final DatabaseHelper dbHelper;
  final SecureSessionStore? sessionStore;
  final Future<String> Function()? userIdProvider;

  LocalLedgerRepository({
    DatabaseHelper? dbHelper,
    this.sessionStore,
    this.userIdProvider,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> _getUserId() async =>
      _resolveUserId(sessionStore: sessionStore, userIdProvider: userIdProvider);

  @override
  Future<List<LedgerBlock>> getBlocks() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'ledger_blocks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'block_index ASC',
    );
    return maps.map((m) => LedgerBlock.fromMap(m)).toList();
  }

  @override
  Future<void> saveBlock(LedgerBlock block) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final isMicrosecondsOrEmpty = block.id.trim().isEmpty || int.tryParse(block.id.trim()) != null;
    final resolvedBlockId = isMicrosecondsOrEmpty ? _uuid.v4() : block.id;
    final resolvedUserId =
        block.userId.isEmpty ? userId : block.userId;

    final blockToSave = LedgerBlock(
      id: resolvedBlockId,
      userId: resolvedUserId,
      blockIndex: block.blockIndex,
      timestamp: block.timestamp,
      dataJson: block.dataJson,
      previousHash: block.previousHash,
      nonce: block.nonce,
      hash: block.hash,
      createdAt: block.createdAt,
      syncStatus: 'pending',
    );

    await db.insert(
      'ledger_blocks',
      blockToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    SyncService.instance.trigger();
  }

  @override
  Future<LedgerBlock?> getLastBlock() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'ledger_blocks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'block_index DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return LedgerBlock.fromMap(maps.first);
  }
}

// ═══════════════════════════════════════════════════
// Local Feedback Repository (SQLite) — PRD §7.7 & §8.1
// ═══════════════════════════════════════════════════

class LocalFeedbackRepository implements FeedbackRepository {
  final DatabaseHelper? dbHelper;
  final SecureSessionStore? sessionStore;
  final Future<String> Function()? userIdProvider;

  LocalFeedbackRepository({
    DatabaseHelper? dbHelper,
    this.sessionStore,
    this.userIdProvider,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<TeamFeedback>> getAll() async {
    return teamFeedbacks;
  }
}

// ═══════════════════════════════════════════════════
// Local Score Repository (SQLite) — PRD §8.1 & §10.1
// ═══════════════════════════════════════════════════

class LocalScoreRepository implements ScoreRepository {
  final DatabaseHelper dbHelper;
  final SecureSessionStore? sessionStore;
  final Future<String> Function()? userIdProvider;

  LocalScoreRepository({
    DatabaseHelper? dbHelper,
    this.sessionStore,
    this.userIdProvider,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> _getUserId() async =>
      _resolveUserId(sessionStore: sessionStore, userIdProvider: userIdProvider);

  @override
  Future<List<GameScore>> getScores(String game) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'game_scores',
      where: 'user_id = ? AND game = ?',
      whereArgs: [userId, game],
      orderBy: 'score DESC, played_at DESC',
    );
    return maps.map((m) => GameScore.fromMap(m)).toList();
  }

  @override
  Future<void> saveScore(GameScore score) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final isMicrosecondsOrEmpty = score.id.trim().isEmpty || int.tryParse(score.id.trim()) != null;
    final resolvedScoreId = isMicrosecondsOrEmpty ? _uuid.v4() : score.id;
    final resolvedUserId =
        score.userId.isEmpty ? userId : score.userId;

    final scoreToSave = GameScore(
      id: resolvedScoreId,
      userId: resolvedUserId,
      game: score.game,
      score: score.score,
      playedAt: score.playedAt,
      syncStatus: 'pending',
    );

    await db.insert(
      'game_scores',
      scoreToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    SyncService.instance.trigger();
  }

  @override
  Future<int> getHighScore(String game) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final result = await db.rawQuery(
      'SELECT MAX(score) as high_score FROM game_scores WHERE user_id = ? AND game = ?',
      [userId, game],
    );

    if (result.isEmpty || result.first['high_score'] == null) return 0;
    return (result.first['high_score'] as num).toInt();
  }
}

// ═══════════════════════════════════════════════════
// Local Chat Repository (SQLite) — PRD §8.1 & §9.3
// ═══════════════════════════════════════════════════

class LocalChatRepository implements ChatRepository {
  final DatabaseHelper dbHelper;
  final SecureSessionStore? sessionStore;
  final Future<String> Function()? userIdProvider;

  LocalChatRepository({
    DatabaseHelper? dbHelper,
    this.sessionStore,
    this.userIdProvider,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> _getUserId() async =>
      _resolveUserId(sessionStore: sessionStore, userIdProvider: userIdProvider);

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    void Function(String status)? onStatusUpdate,
  }) async {
    final userId = await _getUserId();
    final now = DateTime.now().toUtc();

    // Simpan pesan user
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      userId: userId,
      role: 'user',
      content: message,
      createdAt: now,
    );
    await saveMessage(userMsg);

    // Balasan asisten (di Fase B5 akan digantikan panggilan Gemini API nyata)
    const replyText =
        'Halo! Saya asisten membaca StoryLoka. Riwayat chat ini tersimpan secara lokal di SQLite.';
    final modelMsg = ChatMessage(
      id: _uuid.v4(),
      userId: userId,
      role: 'model',
      content: replyText,
      createdAt: DateTime.now().toUtc(),
    );
    await saveMessage(modelMsg);

    return replyText;
  }

  @override
  Future<List<ChatMessage>> getHistory() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final maps = await db.query(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    final msgToSave = message.userId.isEmpty
        ? ChatMessage(
            id: message.id.isEmpty ? _uuid.v4() : message.id,
            userId: userId,
            role: message.role,
            content: message.content,
            createdAt: message.createdAt,
          )
        : message;

    await db.insert(
      'chat_messages',
      msgToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearHistory() async {
    final db = await dbHelper.database;
    final userId = await _getUserId();

    await db.delete(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
