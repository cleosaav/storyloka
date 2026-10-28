import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/services/sync_service.dart';
import 'helpers/demo_widgets.dart';
import 'package:storyloka/data/database_helper.dart';
import 'package:storyloka/data/models/app_user.dart';
import 'package:storyloka/data/models/game_score.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/feedback_repository.dart';
import 'package:storyloka/data/repositories/local/local_repositories.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/tools/feedback_page.dart';

class FakeSyncRemoteSourceS7 extends SyncRemoteSource {
  final Map<String, List<Map<String, dynamic>>> tables = {
    'user_books': [],
    'reading_sessions': [],
    'ledger_blocks': [],
    'feedbacks': [],
    'game_scores': [],
  };

  bool shouldFailUpsert = false;
  final List<String> upsertLog = [];

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    if (shouldFailUpsert) {
      throw Exception('Simulated Network / Remote Failure');
    }
    upsertLog.add('$table:${data['id']}');
    final list = tables[table] ?? [];
    list.removeWhere((item) => item['id'] == data['id']);
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
    return list.where((row) => row['user_id'] == userId).toList();
  }

  @override
  Future<String?> uploadAvatar({required String userId, required dynamic file}) async {
    return null;
  }
}

class TestAuthController extends AuthController {
  final AppUser? testUser;
  TestAuthController({
    this.testUser,
    required super.authRepository,
    required super.sessionStore,
    required super.demoControls,
  });

  @override
  AppUser? get currentUser => testUser;

  @override
  bool get isAuthenticated => testUser != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const userUuidA = '11111111-1111-4111-8111-111111111111';
  const userUuidB = '22222222-2222-4222-8222-222222222222';

  late Database db;
  late DatabaseHelper dbHelper;

  setUpAll(() async {
    fakeRepositoriesEnableLatency = false;
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.setTestDatabase(db);
    dbHelper = DatabaseHelper.instance;

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
        sync_status TEXT NOT NULL DEFAULT 'pending'
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
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setTestDatabase(null);
  });

  group('Fase S7 — 1. Isolasi Data Pengguna & Read-Only TeamFeedbackRepository', () {
    test('Dua akun berbeda tidak saling mencampur data pribadi pada repository nyata', () async {
      String currentUserId = userUuidA;
      final scoreRepo = LocalScoreRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => currentUserId,
      );

      // User A simpan skor game
      await scoreRepo.saveScore(GameScore(
        id: const Uuid().v4(),
        userId: userUuidA,
        game: 'snake',
        score: 100,
        playedAt: DateTime.now().toUtc(),
      ));

      // User B simpan skor game
      currentUserId = userUuidB;
      await scoreRepo.saveScore(GameScore(
        id: const Uuid().v4(),
        userId: userUuidB,
        game: 'snake',
        score: 250,
        playedAt: DateTime.now().toUtc(),
      ));

      // Verifikasi skor User A: high score 100
      currentUserId = userUuidA;
      final highA = await scoreRepo.getHighScore('snake');
      expect(highA, 100);

      // Verifikasi skor User B: high score 250
      currentUserId = userUuidB;
      final highB = await scoreRepo.getHighScore('snake');
      expect(highB, 250);
    });

    test('User ID palsu atau non-UUID ditolak oleh repository nyata dengan melempar StateError', () async {
      // 1. Fallback 'default_user' ditolak
      final repoDefault = LocalScoreRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => 'default_user',
      );
      expect(
        () async => await repoDefault.getHighScore('snake'),
        throwsA(isA<StateError>()),
      );

      // 2. Fallback 'demo_user' ditolak
      final repoDemo = LocalScoreRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => 'demo_user',
      );
      expect(
        () async => await repoDemo.getHighScore('snake'),
        throwsA(isA<StateError>()),
      );

      // 3. String non-UUID sembarang ditolak
      final repoInvalid = LocalScoreRepository(
        dbHelper: dbHelper,
        userIdProvider: () async => 'invalid-not-uuid',
      );
      expect(
        () async => await repoInvalid.getHighScore('snake'),
        throwsA(isA<StateError>()),
      );
    });

    test('TeamFeedbackRepository bersifat baca saja, mengembalikan 3 data konstan tim PAM', () async {
      const repo = TeamFeedbackRepository();
      final list = await repo.getAll();

      expect(list.length, 3);
      expect(list[0].name, 'Najmah Cleosa');
      expect(list[0].nim, '124240104');
      expect(list[1].name, 'Melanie Bunga Chintya Pawesty');
      expect(list[1].nim, '124240164');
      expect(list[2].name, 'Naftali Margareta');
      expect(list[2].nim, '124240119');
    });
  });

  group('Fase S7 — 2. Migrasi Database & Sanitasi Baris ID Palsu', () {
    test('Membersihkan baris dengan ID palsu tanpa menghapus data pengguna valid', () async {
      // Simulasikan database versi lama yang tercemar data palsu
      await db.insert('feedbacks', {
        'id': 'legacy-1',
        'user_id': 'default_user',
        'name': 'Legacy User 1',
        'impression': 'Kesan lama',
        'suggestion': 'Saran lama',
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'synced',
      });
      await db.insert('feedbacks', {
        'id': 'legacy-2',
        'user_id': 'demo',
        'name': 'Demo User',
        'impression': 'Kesan demo',
        'suggestion': 'Saran demo',
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'synced',
      });
      await db.insert('feedbacks', {
        'id': 'legacy-3',
        'user_id': 'guest',
        'name': 'Guest User',
        'impression': 'Kesan guest',
        'suggestion': 'Saran guest',
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'synced',
      });
      await db.insert('feedbacks', {
        'id': 'legacy-4',
        'user_id': 'non-uuid-string',
        'name': 'Random Non-UUID',
        'impression': 'Kesan aneh',
        'suggestion': 'Saran aneh',
        'created_at': '2026-01-01T00:00:00Z',
        'sync_status': 'synced',
      });
      // Baris pengguna valid
      await db.insert('feedbacks', {
        'id': 'valid-1',
        'user_id': userUuidA,
        'name': 'Akun Resmi A',
        'impression': 'Kesan resmi',
        'suggestion': 'Saran resmi',
        'created_at': '2026-10-25T00:00:00Z',
        'sync_status': 'synced',
      });

      // Jalankan query sanitasi migrasi v2
      await db.delete(
        'feedbacks',
        where: "user_id IN ('default_user', 'demo', 'demo_user', 'guest', '') OR length(user_id) != 36 OR user_id NOT LIKE '%-%-%-%-%'",
      );

      final remaining = await db.query('feedbacks');
      expect(remaining.length, 1);
      expect(remaining.first['id'], 'valid-1');
      expect(remaining.first['user_id'], userUuidA);
      expect(remaining.first['name'], 'Akun Resmi A');
    });
  });

  group('Fase S7 — 3. SyncService: Error Handling & Isolasi Multi-Perangkat (Tanpa Feedbacks)', () {
    test('Upsert error menandai baris tetap pending tanpa crash', () async {
      final fakeRemote = FakeSyncRemoteSourceS7();
      fakeRemote.shouldFailUpsert = true; // Simulasikan kegagalan jaringan / remote

      final syncService = SyncService(
        dbHelper: dbHelper,
        remoteSource: fakeRemote,
      );

      await db.insert('game_scores', {
        'id': 'score-sync-1',
        'user_id': userUuidA,
        'game': 'snake',
        'score': 150,
        'played_at': '2026-10-27T00:00:00Z',
        'sync_status': 'pending',
      });

      // Jalankan push: tidak boleh melempar unhandled exception keluar
      await syncService.pushPending(userId: userUuidA);

      // Verifikasi status lokal tetap 'pending' agar bisa dicoba ulang (retry)
      final rows = await db.query('game_scores', where: 'id = ?', whereArgs: ['score-sync-1']);
      expect(rows.first['sync_status'], 'pending');

      // Setelah koneksi pulih, push berhasil mengubah status menjadi 'synced'
      fakeRemote.shouldFailUpsert = false;
      await syncService.pushPending(userId: userUuidA);

      final rowsAfter = await db.query('game_scores', where: 'id = ?', whereArgs: ['score-sync-1']);
      expect(rowsAfter.first['sync_status'], 'synced');
    });

    test('Login di perangkat baru hanya menarik (pull) entri milik akun tersebut', () async {
      final fakeRemote = FakeSyncRemoteSourceS7();
      final syncService = SyncService(
        dbHelper: dbHelper,
        remoteSource: fakeRemote,
      );

      // Remote Supabase memiliki skor game milik User A dan User B
      fakeRemote.tables['game_scores']!.addAll([
        {
          'id': 'score-remote-a',
          'user_id': userUuidA,
          'game': 'snake',
          'score': 200,
          'played_at': '2026-10-27T01:00:00Z',
        },
        {
          'id': 'score-remote-b',
          'user_id': userUuidB,
          'game': 'snake',
          'score': 350,
          'played_at': '2026-10-27T02:00:00Z',
        },
      ]);

      // User B login di perangkat baru -> pullAll(userUuidB)
      await syncService.pullAll(userUuidB);

      // Periksa database lokal di perangkat baru: hanya entri User B yang ditarik
      final localRows = await db.query('game_scores');
      expect(localRows.length, 1);
      expect(localRows.first['id'], 'score-remote-b');
      expect(localRows.first['user_id'], userUuidB);
      expect(localRows.first['score'], 350);
    });

    test('Tabel feedbacks tidak lagi didorong (push) maupun ditarik (pull) oleh SyncService', () async {
      final fakeRemote = FakeSyncRemoteSourceS7();
      final syncService = SyncService(
        dbHelper: dbHelper,
        remoteSource: fakeRemote,
      );

      // 1. Baris feedback di lokal dengan status pending
      await db.insert('feedbacks', {
        'id': 'fb-local-pending',
        'user_id': userUuidA,
        'name': 'User A',
        'impression': 'Kesan Lokal',
        'suggestion': 'Saran Lokal',
        'created_at': '2026-10-27T00:00:00Z',
        'sync_status': 'pending',
      });

      // 2. Baris feedback di remote
      fakeRemote.tables['feedbacks']!.add({
        'id': 'fb-remote-ignore',
        'user_id': userUuidA,
        'name': 'User A Remote',
        'impression': 'Kesan Cloud',
        'suggestion': 'Saran Cloud',
        'created_at': '2026-10-27T00:00:00Z',
      });

      // Push pending
      await syncService.pushPending(userId: userUuidA);

      // Tabel feedbacks tidak pernah dikirim ke remote
      expect(fakeRemote.tables['feedbacks']!.any((row) => row['id'] == 'fb-local-pending'), isFalse);

      // Pull all
      await syncService.pullAll(userUuidA);

      // Data remote feedbacks tidak pernah ditarik ke SQLite lokal
      final pulledRows = await db.query('feedbacks', where: 'id = ?', whereArgs: ['fb-remote-ignore']);
      expect(pulledRows, isEmpty);
    });
  });

  group('Fase S7 — 4. FeedbackPage: Halaman BACA SAJA (3 Kartu Tim PAM)', () {
    Widget buildTestApp({
      AppUser? user,
      ThemeMode themeMode = ThemeMode.light,
      double textScale = 1.0,
      Size size = const Size(800, 1600),
    }) {
      final authController = TestAuthController(
        testUser: user,
        authRepository: FakeAuthRepository(),
        sessionStore: SecureSessionStore(),
        demoControls: DemoControls(),
      );

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: authController),
          Provider<FeedbackRepository>.value(value: const TeamFeedbackRepository()),
        ],
        child: MaterialApp(
          themeMode: themeMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const FeedbackPage(),
          ),
        ),
      );
    }

    testWidgets('1. FeedbackPage tidak memiliki TextField maupun Form input', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Form), findsNothing);
      expect(find.text('Kesan & Pesan'), findsOneWidget);
      expect(
        find.textContaining('Kesan dan pesan dari kelompok kami'),
        findsOneWidget,
      );
    });

    testWidgets('2. Menampilkan tepat 3 kartu anggota tim dengan nama, NIM, dan teks lengkap', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Nama anggota tim
      expect(find.text('Najmah Cleosa'), findsOneWidget);
      expect(find.text('Melanie Bunga Chintya Pawesty'), findsOneWidget);
      expect(find.text('Naftali Margareta'), findsOneWidget);

      // NIM anggota tim
      expect(find.text('NIM: 124240104'), findsOneWidget);
      expect(find.text('NIM: 124240164'), findsOneWidget);
      expect(find.text('NIM: 124240119'), findsOneWidget);

      // Label Kesan & Pesan ada 3 pasang
      expect(find.text('Kesan'), findsNWidgets(3));
      expect(find.text('Pesan'), findsNWidgets(3));

      // Cuplikan teks Kesan & Pesan lengkap
      expect(find.textContaining('Awalnya mengira aplikasi mobile itu cuma soal membuat tampilan'), findsOneWidget);
      expect(find.textContaining('Semoga mata kuliah ini terus memberi ruang untuk proyek utuh'), findsOneWidget);
      expect(find.textContaining('Paling berkesan itu saat debugging'), findsOneWidget);
      expect(find.textContaining('manajemen state, sinkronisasi offline-first'), findsOneWidget);
      expect(find.textContaining('Mengerjakan fitur-fitur yang tidak biasa, seperti game Snake'), findsOneWidget);
      expect(find.textContaining('Terima kasih atas tugas akhir yang menantang tapi masuk akal'), findsOneWidget);

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Avatar Najmah Cleosa'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Avatar Melanie Bunga Chintya Pawesty'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Avatar Naftali Margareta'),
        findsOneWidget,
      );
    });

    testWidgets('3. Tampilan identik untuk dua akun berbeda maupun saat belum login', (tester) async {
      final userA = AppUser(
        id: userUuidA,
        name: 'Akun Pertama',
        email: 'userA@storyloka.id',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final userB = AppUser(
        id: userUuidB,
        name: 'Akun Kedua',
        email: 'userB@storyloka.id',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      // 1. Render dengan User A
      await tester.pumpWidget(buildTestApp(user: userA));
      await tester.pumpAndSettle();
      expect(find.text('Najmah Cleosa'), findsOneWidget);
      expect(find.text('Melanie Bunga Chintya Pawesty'), findsOneWidget);
      expect(find.text('Naftali Margareta'), findsOneWidget);

      // 2. Render dengan User B
      await tester.pumpWidget(buildTestApp(user: userB));
      await tester.pumpAndSettle();
      expect(find.text('Najmah Cleosa'), findsOneWidget);
      expect(find.text('Melanie Bunga Chintya Pawesty'), findsOneWidget);
      expect(find.text('Naftali Margareta'), findsOneWidget);

      // 3. Render tanpa user (belum login)
      await tester.pumpWidget(buildTestApp(user: null));
      await tester.pumpAndSettle();
      expect(find.text('Najmah Cleosa'), findsOneWidget);
      expect(find.text('Melanie Bunga Chintya Pawesty'), findsOneWidget);
      expect(find.text('Naftali Margareta'), findsOneWidget);
    });

    testWidgets('4. Bebas overflow pada layar compact 360x640 dan skala teks 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(
        size: const Size(360, 640),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Najmah Cleosa'), findsOneWidget);
    });

    testWidgets('5. Tampilan dark mode benar dan bebas dari render error', (tester) async {
      await tester.pumpWidget(buildTestApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Najmah Cleosa'), findsOneWidget);
      expect(find.text('Melanie Bunga Chintya Pawesty'), findsOneWidget);
      expect(find.text('Naftali Margareta'), findsOneWidget);
    });
  });
}
