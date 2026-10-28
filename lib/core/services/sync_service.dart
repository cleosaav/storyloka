import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/database_helper.dart';
import '../../data/repositories/local/local_repositories.dart';
import '../config/env.dart';
import 'secure_session_store.dart';

/// Status sinkronisasi untuk indikator UI — PRD §8.3 & §7.8.
enum SyncState {
  synced('Tersinkron'),
  syncing('Menyinkronkan...'),
  pending('Menunggu sinkron'),
  offline('Offline / Belum tersambung'),
  error('Gagal sinkron');

  final String label;
  const SyncState(this.label);
}

/// Kontrak sumber remote untuk operasi sinkronisasi — PRD §8.3 & §13.0.
abstract class SyncRemoteSource {
  Future<void> upsert(String table, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> fetchRows(
    String table,
    String userId, {
    String? orderBy,
    bool ascending = true,
  });
  Future<Map<String, dynamic>?> fetchRowByField(
    String table,
    String userId,
    String field,
    dynamic value,
  ) async {
    final rows = await fetchRows(table, userId);
    for (final row in rows) {
      if (row[field] == value) return row;
    }
    return null;
  }
  Future<String?> uploadAvatar({required String userId, required File file});
}

/// Implementasi nyata SyncRemoteSource menggunakan Supabase PostgREST & Storage — PRD §8.3.
class SupabaseSyncRemoteSource implements SyncRemoteSource {
  final SupabaseClient? client;

  SupabaseSyncRemoteSource({this.client});

  SupabaseClient? get _client {
    if (client != null) return client;
    if (Env.isSupabaseConfigured) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final sb = _client;
    if (sb == null) {
      throw StateError(
        'Supabase client tidak tersedia / belum dikonfigurasi saat upsert $table',
      );
    }
    await sb.from(table).upsert(data, onConflict: 'id');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRows(
    String table,
    String userId, {
    String? orderBy,
    bool ascending = true,
  }) async {
    final sb = _client;
    if (sb == null) return [];

    final query = sb.from(table).select().eq('user_id', userId);
    if (orderBy != null) {
      final rows = await query.order(orderBy, ascending: ascending);
      return List<Map<String, dynamic>>.from(rows as List);
    }
    final rows = await query;
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Future<Map<String, dynamic>?> fetchRowByField(
    String table,
    String userId,
    String field,
    dynamic value,
  ) async {
    final sb = _client;
    if (sb == null) return null;
    try {
      final res = await sb
          .from(table)
          .select()
          .eq('user_id', userId)
          .eq(field, value)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final sb = _client;
    if (sb == null || !await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      final storagePath =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await sb.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      return sb.storage.from('avatars').getPublicUrl(storagePath);
    } catch (e) {
      if (kDebugMode) debugPrint('[SyncService] uploadAvatar gagal: $e');
      return null;
    }
  }
}

/// Service Sinkronisasi Offline-First StoryLoka — PRD §8.3.
/// Mengelola push baris pending, pull data server, resolusi konflik last-write-wins,
/// upload avatar, dan idempotensi sinkronisasi.
class SyncService extends ChangeNotifier {
  static SyncService _instance = SyncService._internal();
  static SyncService get instance => _instance;

  /// Setter untuk unit testing.
  static set testInstance(SyncService custom) {
    _instance = custom;
  }

  DatabaseHelper dbHelper;
  SyncRemoteSource remoteSource;
  SecureSessionStore? sessionStore;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  int _pendingCount = 0;
  SyncState _state = SyncState.synced;

  @visibleForTesting
  SyncService.forTesting({
    DatabaseHelper? dbHelper,
    SyncRemoteSource? remoteSource,
    SecureSessionStore? sessionStore,
  })  : dbHelper = dbHelper ?? DatabaseHelper.instance,
        sessionStore = sessionStore ?? SecureSessionStore(),
        remoteSource = remoteSource ?? SupabaseSyncRemoteSource();

  SyncService._internal({
    DatabaseHelper? dbHelper,
    SupabaseClient? client,
    SyncRemoteSource? remoteSource,
    SecureSessionStore? sessionStore,
  })  : dbHelper = dbHelper ?? DatabaseHelper.instance,
        sessionStore = sessionStore ?? SecureSessionStore(),
        remoteSource = remoteSource ?? SupabaseSyncRemoteSource(client: client);

  factory SyncService({
    DatabaseHelper? dbHelper,
    SupabaseClient? client,
    SyncRemoteSource? remoteSource,
    SecureSessionStore? sessionStore,
  }) {
    return _instance = SyncService._internal(
      dbHelper: dbHelper,
      client: client,
      remoteSource: remoteSource,
      sessionStore: sessionStore,
    );
  }

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  int get pendingCount => _pendingCount;
  SyncState get state => _state;
  bool get hasPendingChanges => _pendingCount > 0;

  /// Pemicu asinkron tanpa memblokir UI — PRD §8.3.
  /// Dipanggil oleh repositori setelah operasi tulis ke SQLite.
  void trigger() {
    unawaited(_runSafePush());
  }

  Future<void> _runSafePush() async {
    try {
      await pushPending();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] _runSafePush gagal: $e');
      }
      // Kegagalan jaringan ditelan dan dicoba lagi nanti — PRD §8.3
    }
  }

  /// Mengembalikan baris dengan sync_status='error' menjadi 'pending'
  /// agar dicoba kembali saat startup, login, resume, dan sync manual.
  Future<void> resetErrorSyncStatus({String? userId}) async {
    try {
      final db = await dbHelper.database;
      final targetUserId = userId ?? await _resolveCurrentUserId();

      final tables = [
        'user_books',
        'reading_sessions',
        'ledger_blocks',
        'game_scores',
      ];

      for (final table in tables) {
        if (targetUserId != null && targetUserId.isNotEmpty) {
          await db.update(
            table,
            {'sync_status': 'pending'},
            where: 'user_id = ? AND sync_status = ?',
            whereArgs: [targetUserId, 'error'],
          );
        } else {
          await db.update(
            table,
            {'sync_status': 'pending'},
            where: 'sync_status = ?',
            whereArgs: ['error'],
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] resetErrorSyncStatus gagal: $e');
      }
    }
  }

  /// Menghitung jumlah baris yang berstatus 'pending' atau 'error' di SQLite lokal.
  Future<int> refreshPendingCount({String? userId}) async {
    try {
      final db = await dbHelper.database;
      final targetUserId = userId ?? await _resolveCurrentUserId();

      int count = 0;
      final tables = [
        'user_books',
        'reading_sessions',
        'ledger_blocks',
        'game_scores',
      ];

      for (final table in tables) {
        final res = targetUserId != null && targetUserId.isNotEmpty
            ? await db.rawQuery(
                'SELECT COUNT(*) as c FROM $table WHERE user_id = ? AND sync_status IN (?, ?)',
                [targetUserId, 'pending', 'error'],
              )
            : await db.rawQuery(
                'SELECT COUNT(*) as c FROM $table WHERE sync_status IN (?, ?)',
                ['pending', 'error'],
              );
        count += (res.first['c'] as num?)?.toInt() ?? 0;
      }

      _pendingCount = count;
      _state = count > 0 ? SyncState.pending : SyncState.synced;
      notifyListeners();
      return count;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] refreshPendingCount gagal: $e');
      }
      return 0;
    }
  }

  /// 1. PUSH PENDING: Urutan tabel (feedbacks dikecualikan karena statis — Fase S7):
  /// user_books → reading_sessions → ledger_blocks → game_scores
  Future<void> pushPending({String? userId}) async {
    final targetUserId = userId ?? await _resolveCurrentUserId();
    if (targetUserId == null || targetUserId.isEmpty) {
      return;
    }
    if (remoteSource is SupabaseSyncRemoteSource && !isValidUuid(targetUserId)) {
      debugPrint('[SyncService] Skip push: userId bukan UUID valid ($targetUserId)');
      return;
    }

    // Kembalikan baris 'error' menjadi 'pending' agar ikut dicoba kembali
    await resetErrorSyncStatus(userId: targetUserId);

    _isSyncing = true;
    _state = SyncState.syncing;
    _lastError = null;
    notifyListeners();

    try {
      final db = await dbHelper.database;

      // 1. user_books
      await _pushTable(
        db: db,
        tableName: 'user_books',
        userId: targetUserId,
        transform: (row) {
          final payload = Map<String, dynamic>.from(row);
          payload.remove('sync_status');
          // Konversi is_deleted int ke boolean untuk Supabase
          payload['is_deleted'] =
              (row['is_deleted'] == 1 || row['is_deleted'] == true);
          return payload;
        },
      );

      // 2. reading_sessions
      await _pushTable(
        db: db,
        tableName: 'reading_sessions',
        userId: targetUserId,
        transform: (row) {
          final payload = Map<String, dynamic>.from(row);
          payload.remove('sync_status');
          return payload;
        },
      );

      // 3. ledger_blocks
      await _pushTable(
        db: db,
        tableName: 'ledger_blocks',
        userId: targetUserId,
        transform: (row) {
          final payload = Map<String, dynamic>.from(row);
          payload.remove('sync_status');
          // Pastikan data_json dikirim sebagai Map JSON untuk jsonb di Supabase
          final rawData = payload['data_json'];
          if (rawData is String && rawData.isNotEmpty) {
            try {
              payload['data_json'] = jsonDecode(rawData);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[SyncService] Gagal parse data_json ledger_blocks: $e');
              }
            }
          }
          return payload;
        },
      );

      // 4. game_scores
      await _pushTable(
        db: db,
        tableName: 'game_scores',
        userId: targetUserId,
        transform: (row) {
          final payload = Map<String, dynamic>.from(row);
          payload.remove('sync_status');
          return payload;
        },
      );

      _lastSyncTime = DateTime.now();
      await refreshPendingCount(userId: targetUserId);
    } catch (e) {
      _lastError = e.toString();
      _state = SyncState.error;
      notifyListeners();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 3;

  void _recordRetry(String id) {
    _retryCounts[id] = (_retryCounts[id] ?? 0) + 1;
  }

  bool _isUniqueViolation(Object error) {
    if (error is PostgrestException && error.code == '23505') return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('23505') ||
        msg.contains('unique constraint') ||
        msg.contains('duplicate key');
  }

  /// Helper untuk push batch per tabel
  Future<void> _pushTable({
    required Database db,
    required String tableName,
    required String userId,
    required Map<String, dynamic> Function(Map<String, dynamic>) transform,
  }) async {
    final pendingRows = await db.query(
      tableName,
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, 'pending'],
    );

    if (pendingRows.isEmpty) return;

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    const uuidGen = Uuid();

    for (final row in pendingRows) {
      final payload = transform(row);
      var id = row['id'] as String;

      // Auto-heal ID non-UUID sebelum dikirim ke Supabase Postgres UUID column (22P02)
      if (!uuidRegex.hasMatch(id)) {
        final newId = uuidGen.v4();
        await db.update(
          tableName,
          {'id': newId},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (tableName == 'user_books') {
          await db.update(
            'reading_sessions',
            {'user_book_id': newId},
            where: 'user_book_id = ?',
            whereArgs: [id],
          );
        }
        id = newId;
        payload['id'] = newId;
      }

      // Auto-heal user_book_id non-UUID pada reading_sessions jika merujuk ke id lama
      if (tableName == 'reading_sessions') {
        final ubId = payload['user_book_id']?.toString() ?? '';
        if (ubId.isNotEmpty && !uuidRegex.hasMatch(ubId)) {
          // Cek apakah ada user_books yang cocok
          final ubRow = await db.query(
            'user_books',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [ubId],
          );
          if (ubRow.isEmpty) {
            // Jika user_books tidak ada dengan ID lama, skip atau jangan kirim foreign key invalid
            final fallbackUb = await db.query(
              'user_books',
              columns: ['id'],
              where: 'user_id = ?',
              whereArgs: [userId],
              limit: 1,
            );
            if (fallbackUb.isNotEmpty) {
              final healedUbId = fallbackUb.first['id'] as String;
              await db.update(
                'reading_sessions',
                {'user_book_id': healedUbId},
                where: 'id = ?',
                whereArgs: [id],
              );
              payload['user_book_id'] = healedUbId;
            }
          }
        }
      }

      try {
        // Upsert ke Remote Source dengan onConflict: 'id'
        await remoteSource.upsert(tableName, payload);

        // Tandai baris di SQLite sebagai synced jika berhasil
        await db.update(
          tableName,
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [id],
        );
        _retryCounts.remove(id);
      } catch (e) {
        if (_isUniqueViolation(e) && tableName == 'user_books') {
          await _resolveUserBookConflict(
            db: db,
            userId: userId,
            localRow: row,
            transform: transform,
          );
        } else if (_isUniqueViolation(e) && tableName == 'ledger_blocks') {
          await _resolveLedgerBlockConflict(
            db: db,
            userId: userId,
            localRow: row,
          );
        } else {
          _recordRetry(id);
          if ((_retryCounts[id] ?? 0) >= _maxRetries) {
            await db.update(
              tableName,
              {'sync_status': 'error'},
              where: 'id = ?',
              whereArgs: [id],
            );
            debugPrint(
                '[SyncService] Batas retry ($_maxRetries) tercapai untuk $tableName id $id');
          }
          if (kDebugMode) {
            debugPrint('[SyncService] Gagal upsert tabel $tableName id $id: $e');
          }
        }
      }
    }
  }

  Future<void> _resolveUserBookConflict({
    required Database db,
    required String userId,
    required Map<String, dynamic> localRow,
    required Map<String, dynamic> Function(Map<String, dynamic>) transform,
  }) async {
    final localId = localRow['id'] as String;
    final googleBooksId = localRow['google_books_id'] as String?;
    if (googleBooksId == null) return;

    final remoteRow = await remoteSource.fetchRowByField(
      'user_books',
      userId,
      'google_books_id',
      googleBooksId,
    );

    if (remoteRow == null) return;
    final remoteId = remoteRow['id'] as String;

    final localUpdatedAtStr = localRow['updated_at'] as String?;
    final remoteUpdatedAtStr = remoteRow['updated_at'] as String?;
    final localUpdatedAt =
        DateTime.tryParse(localUpdatedAtStr ?? '') ?? DateTime(1970);
    final remoteUpdatedAt =
        DateTime.tryParse(remoteUpdatedAtStr ?? '') ?? DateTime(1970);

    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      // Local menang LWW: dorong pembaruan lokal ke remote menggunakan ID remote
      final mergedPayload = transform(localRow);
      mergedPayload['id'] = remoteId;
      await remoteSource.upsert('user_books', mergedPayload);

      // Di SQLite lokal:
      // 1. Pindahkan reading_sessions yang merujuk localId ke remoteId
      await db.update(
        'reading_sessions',
        {'user_book_id': remoteId},
        where: 'user_book_id = ?',
        whereArgs: [localId],
      );
      // 2. Hapus localId lama jika berbeda
      if (localId != remoteId) {
        await db.delete('user_books', where: 'id = ?', whereArgs: [localId]);
      }
      // 3. Simpan baris yang menang dengan remoteId & synced
      final updatedLocal = Map<String, dynamic>.from(localRow);
      updatedLocal['id'] = remoteId;
      updatedLocal['sync_status'] = 'synced';
      final isDeleted = updatedLocal['is_deleted'];
      updatedLocal['is_deleted'] =
          (isDeleted == 1 || isDeleted == true) ? 1 : 0;
      await db.insert(
        'user_books',
        updatedLocal,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // Remote menang LWW:
      // 1. Pindahkan reading_sessions yang merujuk localId ke remoteId
      await db.update(
        'reading_sessions',
        {'user_book_id': remoteId},
        where: 'user_book_id = ?',
        whereArgs: [localId],
      );
      // 2. Hapus localId lama
      if (localId != remoteId) {
        await db.delete('user_books', where: 'id = ?', whereArgs: [localId]);
      }
      // 3. Simpan data remote ke lokal & synced
      final remoteToLocal = Map<String, dynamic>.from(remoteRow);
      remoteToLocal['sync_status'] = 'synced';
      final isDeleted = remoteToLocal['is_deleted'];
      remoteToLocal['is_deleted'] =
          (isDeleted == 1 || isDeleted == true) ? 1 : 0;
      await db.insert(
        'user_books',
        remoteToLocal,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    _retryCounts.remove(localId);
  }

  Future<void> _resolveLedgerBlockConflict({
    required Database db,
    required String userId,
    required Map<String, dynamic> localRow,
  }) async {
    final localId = localRow['id'] as String;
    final blockIndex = localRow['block_index'];

    final remoteRow = await remoteSource.fetchRowByField(
      'ledger_blocks',
      userId,
      'block_index',
      blockIndex,
    );

    if (remoteRow != null) {
      // Blok remote sudah ada, JANGAN menimpa blok remote.
      // Tandai blok lokal 'conflict' dan catat agar tidak loop pending selamanya.
      await db.update(
        'ledger_blocks',
        {'sync_status': 'conflict'},
        where: 'id = ?',
        whereArgs: [localId],
      );
      debugPrint(
        '[SyncService] Konflik ledger_blocks block_index $blockIndex: remote sudah ada, ditandai conflict',
      );
      _retryCounts.remove(localId);
    } else {
      _recordRetry(localId);
      if ((_retryCounts[localId] ?? 0) >= _maxRetries) {
        await db.update(
          'ledger_blocks',
          {'sync_status': 'conflict'},
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    }
  }

  /// 2. PULL ALL: Dipanggil setelah login/register & pull-to-refresh — PRD §8.3.
  /// Last-write-wins berdasarkan updated_at untuk user_books.
  /// Append-only untuk tabel lainnya.
  Future<void> pullAll(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    if (remoteSource is SupabaseSyncRemoteSource && !isValidUuid(userId)) {
      debugPrint('[SyncService] Skip pull: userId bukan UUID valid ($userId)');
      return;
    }

    _isSyncing = true;
    _state = SyncState.syncing;
    _lastError = null;
    notifyListeners();

    try {
      final db = await dbHelper.database;

      // 1. Pull user_books (Resolusi konflik Last-Write-Wins berdasarkan updated_at)
      await _pullUserBooks(db, userId);

      // 2. Pull reading_sessions (Append-only)
      await _pullAppendOnlyTable(
        db: db,
        tableName: 'reading_sessions',
        userId: userId,
      );

      // 3. Pull ledger_blocks (Terurut block_index ASC)
      await _pullLedgerBlocks(db, userId);

      // 4. Pull game_scores (Append-only)
      await _pullAppendOnlyTable(
        db: db,
        tableName: 'game_scores',
        userId: userId,
      );

      _lastSyncTime = DateTime.now();
      await refreshPendingCount(userId: userId);
    } catch (e) {
      _lastError = e.toString();
      _state = SyncState.error;
      notifyListeners();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Pull user_books dengan logika Last-Write-Wins (PRD §8.3).
  Future<void> _pullUserBooks(Database db, String userId) async {
    final remoteRows = await remoteSource.fetchRows('user_books', userId);
    if (remoteRows.isEmpty) return;

    for (final remote in remoteRows) {
      final remoteMap = Map<String, dynamic>.from(remote);
      final id = remoteMap['id'] as String;
      final googleBooksId = remoteMap['google_books_id'] as String?;

      // Konversi format remote ke SQLite
      final isDeletedBool = remoteMap['is_deleted'];
      remoteMap['is_deleted'] =
          (isDeletedBool == true || isDeletedBool == 1) ? 1 : 0;
      remoteMap['sync_status'] = 'synced';

      var localList = await db.query(
        'user_books',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      // Jika belum ditemukan berdasarkan id, cari berdasarkan (user_id, google_books_id)
      if (localList.isEmpty && googleBooksId != null) {
        localList = await db.query(
          'user_books',
          where: 'user_id = ? AND google_books_id = ?',
          whereArgs: [userId, googleBooksId],
          limit: 1,
        );
      }

      if (localList.isEmpty) {
        // Belum ada di lokal -> sisipkan langsung
        await db.insert(
          'user_books',
          remoteMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        // Sudah ada di lokal: bandingkan updated_at (Last-Write-Wins)
        final local = localList.first;
        final localId = local['id'] as String;
        final localUpdatedAtStr = local['updated_at'] as String?;
        final remoteUpdatedAtStr = remoteMap['updated_at'] as String?;

        final localUpdatedAt =
            DateTime.tryParse(localUpdatedAtStr ?? '') ?? DateTime(1970);
        final remoteUpdatedAt =
            DateTime.tryParse(remoteUpdatedAtStr ?? '') ?? DateTime(1970);

        if (localId != id) {
          // Ada konflik ID untuk buku yang sama (google_books_id sama)
          // Pindahkan reading_sessions lokal ke id remote
          await db.update(
            'reading_sessions',
            {'user_book_id': id},
            where: 'user_book_id = ?',
            whereArgs: [localId],
          );
          await db.delete('user_books', where: 'id = ?', whereArgs: [localId]);
        }

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          // Remote lebih baru -> timpa data lokal
          await db.insert(
            'user_books',
            remoteMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else if (localId != id) {
          // Local lebih baru, tetapi ID lokal berbeda dari remote.
          // Pertahankan data lokal dengan ID remote dan tandai 'pending' agar ter-push
          final localMerged = Map<String, dynamic>.from(local);
          localMerged['id'] = id;
          localMerged['sync_status'] = 'pending';
          await db.insert(
            'user_books',
            localMerged,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }

  /// Pull ledger_blocks dengan urutan block_index ASC (PRD §8.3).
  Future<void> _pullLedgerBlocks(Database db, String userId) async {
    final remoteRows = await remoteSource.fetchRows(
      'ledger_blocks',
      userId,
      orderBy: 'block_index',
      ascending: true,
    );
    if (remoteRows.isEmpty) return;

    for (final remote in remoteRows) {
      final remoteMap = Map<String, dynamic>.from(remote);
      final id = remoteMap['id'] as String;
      final blockIndex = remoteMap['block_index'];

      // SQLite menyimpan data_json sebagai string
      if (remoteMap['data_json'] is! String) {
        remoteMap['data_json'] = jsonEncode(remoteMap['data_json']);
      }
      remoteMap['sync_status'] = 'synced';

      final localList = await db.query(
        'ledger_blocks',
        where: 'id = ? OR (user_id = ? AND block_index = ?)',
        whereArgs: [id, userId, blockIndex],
        limit: 1,
      );

      if (localList.isEmpty) {
        await db.insert(
          'ledger_blocks',
          remoteMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await db.update(
          'ledger_blocks',
          remoteMap,
          where: 'id = ? OR (user_id = ? AND block_index = ?)',
          whereArgs: [id, userId, blockIndex],
        );
      }
    }
  }

  /// Pull tabel append-only: cukup insert-jika-belum-ada (PRD §8.3).
  Future<void> _pullAppendOnlyTable({
    required Database db,
    required String tableName,
    required String userId,
  }) async {
    final remoteRows = await remoteSource.fetchRows(tableName, userId);
    if (remoteRows.isEmpty) return;

    for (final remote in remoteRows) {
      final remoteMap = Map<String, dynamic>.from(remote);
      final id = remoteMap['id'] as String;

      final localList = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (localList.isEmpty) {
        remoteMap['sync_status'] = 'synced';
        await db.insert(
          tableName,
          remoteMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  /// Sinkronisasi saat aplikasi resume ke foreground — PRD §8.3.
  Future<void> syncOnResume() async {
    final userId = await _resolveCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      await pushPending(userId: userId);
      await pullAll(userId);
    }
  }

  /// Sinkronisasi sebelum logout — PRD §8.3.
  /// Mendorong pending changes terakhir sebelum database lokal dibersihkan.
  Future<void> syncBeforeLogout(String userId) async {
    if (userId.isEmpty) return;
    try {
      await pushPending(userId: userId).timeout(const Duration(seconds: 4));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SyncService] syncBeforeLogout gagal: $e');
      }
      // Abaikan kegagalan jaringan saat logout
    }
  }

  /// Upload avatar ke bucket Storage 'avatars' — PRD §8.2 & §8.3.
  Future<String?> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    return await remoteSource.uploadAvatar(userId: userId, file: file);
  }

  Future<String?> _resolveCurrentUserId() async {
    if (sessionStore != null) {
      final user = await sessionStore!.getUser();
      return user?.id;
    }
    return null;
  }
}
