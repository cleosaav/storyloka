import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database_helper.dart';
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
    if (sb == null) return;
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
    } catch (_) {
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
    } catch (_) {
      // Kegagalan jaringan ditelan dan dicoba lagi nanti — PRD §8.3
    }
  }

  /// Menghitung jumlah baris yang berstatus 'pending' di SQLite lokal.
  Future<int> refreshPendingCount({String? userId}) async {
    try {
      final db = await dbHelper.database;
      final targetUserId = userId ?? await _resolveCurrentUserId();

      int count = 0;
      final tables = [
        'user_books',
        'reading_sessions',
        'ledger_blocks',
        'feedbacks',
        'game_scores',
      ];

      for (final table in tables) {
        final res = targetUserId != null && targetUserId.isNotEmpty
            ? await db.rawQuery(
                'SELECT COUNT(*) as c FROM $table WHERE user_id = ? AND sync_status = ?',
                [targetUserId, 'pending'],
              )
            : await db.rawQuery(
                'SELECT COUNT(*) as c FROM $table WHERE sync_status = ?',
                ['pending'],
              );
        count += (res.first['c'] as num?)?.toInt() ?? 0;
      }

      _pendingCount = count;
      _state = count > 0 ? SyncState.pending : SyncState.synced;
      notifyListeners();
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// 1. PUSH PENDING: Urutan tabel PRD §8.3:
  /// user_books → reading_sessions → ledger_blocks → feedbacks → game_scores
  Future<void> pushPending({String? userId}) async {
    final targetUserId = userId ?? await _resolveCurrentUserId();
    if (targetUserId == null ||
        targetUserId.isEmpty ||
        targetUserId == 'demo_user') {
      return;
    }

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
            } catch (_) {}
          }
          return payload;
        },
      );

      // 4. feedbacks
      await _pushTable(
        db: db,
        tableName: 'feedbacks',
        userId: targetUserId,
        transform: (row) {
          final payload = Map<String, dynamic>.from(row);
          payload.remove('sync_status');
          return payload;
        },
      );

      // 5. game_scores
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

    for (final row in pendingRows) {
      final payload = transform(row);
      final id = row['id'] as String;

      // Upsert ke Remote Source dengan onConflict: 'id'
      await remoteSource.upsert(tableName, payload);

      // Tandai baris di SQLite sebagai synced
      await db.update(
        tableName,
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// 2. PULL ALL: Dipanggil setelah login/register & pull-to-refresh — PRD §8.3.
  /// Last-write-wins berdasarkan updated_at untuk user_books.
  /// Append-only untuk tabel lainnya.
  Future<void> pullAll(String userId) async {
    if (userId.isEmpty || userId == 'demo_user') return;

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

      // 4. Pull feedbacks (Append-only)
      await _pullAppendOnlyTable(
        db: db,
        tableName: 'feedbacks',
        userId: userId,
      );

      // 5. Pull game_scores (Append-only)
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

      // Konversi format remote ke SQLite
      final isDeletedBool = remoteMap['is_deleted'];
      remoteMap['is_deleted'] =
          (isDeletedBool == true || isDeletedBool == 1) ? 1 : 0;
      remoteMap['sync_status'] = 'synced';

      final localList = await db.query(
        'user_books',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

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
        final localUpdatedAtStr = local['updated_at'] as String?;
        final remoteUpdatedAtStr = remoteMap['updated_at'] as String?;

        final localUpdatedAt =
            DateTime.tryParse(localUpdatedAtStr ?? '') ?? DateTime(1970);
        final remoteUpdatedAt =
            DateTime.tryParse(remoteUpdatedAtStr ?? '') ?? DateTime(1970);

        if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
          // Remote lebih baru -> timpa data lokal
          await db.update(
            'user_books',
            remoteMap,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        // Jika localUpdatedAt >= remoteUpdatedAt, pertahankan data lokal
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

      final localList = await db.query(
        'ledger_blocks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (localList.isEmpty) {
        // SQLite menyimpan data_json sebagai string
        if (remoteMap['data_json'] is! String) {
          remoteMap['data_json'] = jsonEncode(remoteMap['data_json']);
        }
        remoteMap['sync_status'] = 'synced';

        await db.insert(
          'ledger_blocks',
          remoteMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
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
    if (userId != null && userId.isNotEmpty && userId != 'demo_user') {
      await pushPending(userId: userId);
      await pullAll(userId);
    }
  }

  /// Sinkronisasi sebelum logout — PRD §8.3.
  /// Mendorong pending changes terakhir sebelum database lokal dibersihkan.
  Future<void> syncBeforeLogout(String userId) async {
    if (userId.isEmpty || userId == 'demo_user') return;
    try {
      await pushPending(userId: userId).timeout(const Duration(seconds: 4));
    } catch (_) {
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
