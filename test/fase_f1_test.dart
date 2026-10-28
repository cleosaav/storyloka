import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ListType;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/core/services/light_sensor_service.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/services/sync_service.dart';
import 'helpers/demo_widgets.dart';
import 'package:storyloka/data/database_helper.dart';
import 'package:storyloka/data/models/app_user.dart';
import 'package:storyloka/data/models/ledger_block.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/auth_repository.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';
import 'package:storyloka/data/repositories/library_repository.dart';
import 'package:storyloka/data/repositories/profile_repository.dart';
import 'package:storyloka/data/repositories/reading_repository.dart';
import 'helpers/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/local/local_repositories.dart';
import 'package:storyloka/data/repositories/supabase/supabase_repositories.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/splash_page.dart';
import 'package:storyloka/features/profile/profile_page.dart';
import 'package:uuid/uuid.dart';

class _MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  _MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

class _HangingAuthRepository implements AuthRepository {
  final AppUser? returnUser;

  _HangingAuthRepository({this.returnUser});

  @override
  Future<AppUser?> validateSession() async {
    await Future.delayed(const Duration(seconds: 15));
    return returnUser;
  }

  @override
  Future<AppUser> login(String email, String password) async => throw UnimplementedError();

  @override
  Future<AppUser> register(String name, String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasSession() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dummyUser = AppUser(
    id: 'user-offline-1',
    name: 'Pembaca Offline',
    email: 'offline@storyloka.com',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Fase F1.1 — SupabaseAuthRepository.validateSession Offline vs SESSION_INVALID', () {
    test('validateSession saat offline (SocketException) mempertahankan sesi & mengembalikan cached user',
        () async {
      final sessionStore = SecureSessionStore();
      await sessionStore.saveSession(
        token: 'valid-local-token-123',
        user: dummyUser,
        mode: 'real',
      );

      // Mock HTTP client yang melempar SocketException (simulasi offline / tanpa internet)
      final mockHttp = _MockHttpClient((request) async {
        throw const SocketException('Failed host lookup: mock.supabase.co');
      });

      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        httpClient: mockHttp,
      );

      final repo = SupabaseAuthRepository(
        client: client,
        sessionStore: sessionStore,
      );

      final result = await repo.validateSession();

      // Sesi lokal di secure storage TIDAK boleh dihapus saat offline
      expect(await sessionStore.hasSession(), isTrue);
      expect(await sessionStore.getToken(), 'valid-local-token-123');
      // Harus mengembalikan user dari cache lokal
      expect(result, isNotNull);
      expect(result?.id, dummyUser.id);
      expect(result?.email, dummyUser.email);
    });

    test('validateSession saat server merespons SESSION_INVALID menghapus sesi lokal & return null',
        () async {
      final sessionStore = SecureSessionStore();
      await sessionStore.saveSession(
        token: 'invalid-token-456',
        user: dummyUser,
        mode: 'real',
      );

      // Mock HTTP client yang mengembalikan error Postgrest SESSION_INVALID
      final mockHttp = _MockHttpClient((request) async {
        final body = jsonEncode({
          'code': 'P0001',
          'message': 'SESSION_INVALID',
          'details': 'Session token is expired or not found',
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          400,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        httpClient: mockHttp,
      );

      final repo = SupabaseAuthRepository(
        client: client,
        sessionStore: sessionStore,
      );

      final result = await repo.validateSession();

      // Sesi lokal HARUS dihapus jika server menyatakan SESSION_INVALID
      expect(result, isNull);
      expect(await sessionStore.hasSession(), isFalse);
      expect(await sessionStore.getToken(), isNull);
      expect(await sessionStore.getUser(), isNull);
    });

    test('Pesan error jaringan membedakan tanpa koneksi internet dan masalah TLS/Handshake', () async {
      final sessionStore = SecureSessionStore();

      // 1. Error tanpa internet (SocketException / ClientException)
      final offlineHttp = _MockHttpClient((request) async {
        throw const SocketException('Network is unreachable');
      });
      final offlineRepo = SupabaseAuthRepository(
        client: SupabaseClient('https://mock.supabase.co', 'mock-key', httpClient: offlineHttp),
        sessionStore: sessionStore,
      );

      expect(
        () => offlineRepo.login('user@test.com', 'password123'),
        throwsA(predicate((e) =>
            e.toString().contains('Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi.'))),
      );

      // 2. Error TLS/Handshake
      final tlsHttp = _MockHttpClient((request) async {
        throw const HandshakeException('Handshake error in client');
      });
      final tlsRepo = SupabaseAuthRepository(
        client: SupabaseClient('https://mock.supabase.co', 'mock-key', httpClient: tlsHttp),
        sessionStore: sessionStore,
      );

      expect(
        () => tlsRepo.login('user@test.com', 'password123'),
        throwsA(predicate((e) =>
            e.toString().contains('Handshake') &&
            !e.toString().contains('Tidak ada koneksi internet. Periksa jaringan Anda lalu coba lagi.'))),
      );
    });
  });

  group('Fase F1.1 — AuthController & SplashPage saat offline / timeout', () {
    testWidgets('Splash tetap lanjut masuk Home saat offline/timeout jika ada sesi lokal',
        (tester) async {
      final sessionStore = SecureSessionStore();
      await sessionStore.saveSession(
        token: 'real-token-local',
        user: dummyUser,
        mode: 'real',
      );

      final hangingRepo = _HangingAuthRepository(returnUser: dummyUser);
      final authController = AuthController(
        authRepository: hangingRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: authController,
          child: const MaterialApp(
            home: SplashPage(),
          ),
        ),
      );

      // Render awal splash
      expect(find.text('StoryLoka'), findsOneWidget);
      await tester.pump();

      // Majukan waktu 11 detik agar timeout 10 detik terpicu
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      // Karena ada sesi lokal tersimpan, user TIDAK boleh tertahan di splash timeout error!
      // authController harus terinisialisasi dan terautentikasi dengan user lokal
      expect(authController.hasSplashTimeout, isFalse);
      expect(authController.isInitialized, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.id, dummyUser.id);
      expect(find.text('Koneksi Terputus'), findsNothing);

      // Flush sisa timer hanging pertama dan background re-validation
      await tester.pump(const Duration(seconds: 20));
    });
  });

  group('Fase F1.2 — Persistensi ThemeMode di SharedPreferences', () {
    test('Simpan lalu muat ulang tiap mode tema (dark, auto, light)', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();

      // 1. Simpan Dark
      controller.setThemeMode(ThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 10));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');

      final reloadedDark = await ThemeController.create();
      expect(reloadedDark.userPreferenceMode, ThemeMode.dark);

      // 2. Simpan Auto
      controller.setThemeMode(ThemeMode.system);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(prefs.getString('theme_mode'), 'auto');

      final reloadedAuto = await ThemeController.create();
      expect(reloadedAuto.userPreferenceMode, ThemeMode.system);

      // 3. Simpan Light
      controller.setThemeMode(ThemeMode.light);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(prefs.getString('theme_mode'), 'light');

      final reloadedLight = await ThemeController.create();
      expect(reloadedLight.userPreferenceMode, ThemeMode.light);
    });

    test('Mode Auto otomatis mengaktifkan LightSensorService saat dimuat ulang', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'auto'});
      LightSensorService.instance.stopListening();
      expect(LightSensorService.instance.isAutoActive, isFalse);

      final controller = await ThemeController.create();
      expect(controller.userPreferenceMode, ThemeMode.system);
      expect(LightSensorService.instance.isAutoActive, isTrue);
    });

    test('Tema tidak direset saat logout', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final sessionStore = SecureSessionStore();
      final authRepo = FakeAuthRepository(sessionStore: sessionStore);
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
      );

      // User logged in
      await authRepo.login('user@test.com', 'password123');
      expect(await sessionStore.hasSession(), isTrue);

      // Logout
      await authController.logout();
      expect(await sessionStore.hasSession(), isFalse);

      // Cek bahwa preferensi theme_mode di SharedPreferences tetap utuh
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
      final reloaded = await ThemeController.create();
      expect(reloaded.userPreferenceMode, ThemeMode.dark);
    });
  });

  group('Fase F1.3 — Pencegahan Bentrok Genesis Block di Perangkat Baru', () {
    test('Genesis block bersifat deterministik (UUID v5 dan timestamp tetap)', () async {
      final repo1 = _InMemoryLedgerRepository();
      final repo2 = _InMemoryLedgerRepository();
      final service1 = LedgerService(repo1);
      final service2 = LedgerService(repo2);

      const testUserId = '00000000-0000-4000-8000-000000000001';

      // Dua perangkat menghasilkan genesis block secara independen
      final block1 = await service1.ensureGenesisBlock(testUserId);
      final block2 = await service2.ensureGenesisBlock(testUserId);

      // Harus 100% identik
      expect(block1.id, equals(block2.id), reason: 'ID genesis harus deterministik (UUID v5)');
      expect(block1.timestamp, equals(block2.timestamp), reason: 'Timestamp genesis harus tetap/deterministik');
      expect(block1.hash, equals(block2.hash), reason: 'Hash genesis harus identik');
      expect(block1.nonce, equals(block2.nonce), reason: 'Nonce genesis harus identik');
      expect(block1.blockIndex, 0);
      expect(block1.previousHash, '0');

      // verifyChain harus tetap valid pada kedua blok
      final verify1 = LedgerService.verifyChain([block1]);
      final verify2 = LedgerService.verifyChain([block2]);
      expect(verify1.isValid, isTrue);
      expect(verify2.isValid, isTrue);
    });

    test('Simulasi perangkat baru: pullAll dulu mencegah duplikasi dan bentrok UNIQUE', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      final fakeRemote = _FakeSyncRemoteSource();
      final syncService = SyncService(
        dbHelper: dbHelper,
        remoteSource: fakeRemote,
      );
      SyncService.testInstance = syncService;

      const userId = '00000000-0000-4000-8000-000000000001';
      final fixedTs = DateTime.utc(2025, 1, 1, 0, 0, 0);

      // 1. Simulasikan remote sudah memiliki blok genesis dari perangkat sebelumnya
      final remoteGenesis = LedgerBlock(
        id: const Uuid().v5(Namespace.url.value, 'storyloka:genesis:$userId'),
        userId: userId,
        blockIndex: 0,
        timestamp: fixedTs,
        dataJson: {'message': 'StoryLoka genesis', 'user_id': userId},
        previousHash: '0',
        nonce: 42,
        hash: '00abcdef12345678',
        createdAt: fixedTs,
        syncStatus: 'synced',
      );

      await fakeRemote.upsert('ledger_blocks', {
        'id': remoteGenesis.id,
        'user_id': remoteGenesis.userId,
        'block_index': remoteGenesis.blockIndex,
        'timestamp': remoteGenesis.timestamp.toIso8601String(),
        'data_json': remoteGenesis.dataJson,
        'previous_hash': remoteGenesis.previousHash,
        'nonce': remoteGenesis.nonce,
        'hash': remoteGenesis.hash,
        'created_at': remoteGenesis.createdAt.toIso8601String(),
        'sync_status': 'synced',
      });

      // 2. Perangkat baru (SQLite kosong) melakukan login
      final sessionStore = SecureSessionStore();
      final staticUser = AppUser(
        id: userId,
        name: 'Reader 1',
        email: 'user@test.com',
        createdAt: fixedTs,
        updatedAt: fixedTs,
      );
      final authRepo = _StaticAuthRepository(staticUser, sessionStore: sessionStore);
      final ledgerRepo = LocalLedgerRepository(dbHelper: dbHelper, sessionStore: sessionStore);
      final ledgerService = LedgerService(ledgerRepo);

      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        ledgerService: ledgerService,
        demoControls: DemoControls(),
      );

      final loginSuccess = await authController.login('user@test.com', 'password123');
      expect(loginSuccess, isTrue);

      // 3. Verifikasi di SQLite lokal: hanya ada 1 blok, ID sama dengan remote, status synced
      final localBlocks = await ledgerRepo.getBlocks();
      expect(localBlocks.length, 1, reason: 'Tidak boleh ada blok genesis ganda');
      expect(localBlocks.first.id, equals(remoteGenesis.id));
      expect(localBlocks.first.syncStatus, 'synced');

      // 4. Pastikan pending count adalah 0 (tidak ada baris pending yang tertahan)
      final pendingCount = await syncService.refreshPendingCount(userId: userId);
      expect(pendingCount, 0, reason: 'Tidak boleh ada baris pending tertahan akibat konflik genesis');

      // 5. Push pending tidak boleh melempar error konflik
      expect(() => syncService.pushPending(userId: userId), returnsNormally);
    });

    test('Idempotensi appendFinishedBook tetap terjaga setelah perbaikan genesis', () async {
      final repo = _InMemoryLedgerRepository();
      final service = LedgerService(repo);
      const userId = '00000000-0000-4000-8000-000000000001';

      final userBook = UserBook(
        id: 'ub-test-001',
        userId: userId,
        googleBooksId: 'gb-001',
        title: 'Buku Idempoten',
        listType: ListType.collection,
        status: BookStatus.finished,
        finishedAt: DateTime.utc(2025, 6, 1, 10, 0, 0),
        createdAt: DateTime.utc(2025, 6, 1, 9, 0, 0),
        updatedAt: DateTime.utc(2025, 6, 1, 10, 0, 0),
      );

      final blockA = await service.appendFinishedBook(userBook, userId: userId);
      final blockB = await service.appendFinishedBook(userBook, userId: userId);

      expect(blockA.id, equals(blockB.id));
      expect(blockA.hash, equals(blockB.hash));

      final allBlocks = await repo.getBlocks();
      expect(allBlocks.length, 2, reason: 'Hanya genesis + 1 blok buku');
      expect(allBlocks.first.blockIndex, 0);
      expect(allBlocks.last.blockIndex, 1);

      final verify = LedgerService.verifyChain(allBlocks);
      expect(verify.isValid, isTrue);
    });
  });

  group('Fase F1.4 — Logout Sesuai PRD §7.8', () {
    test('Logout menghapus data lokal user di SQLite (termasuk chat), preferensi per-perangkat tetap', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      const userId = '00000000-0000-4000-8000-000000000001';
      final sessionStore = _MockSessionStore();
      final staticUser = AppUser(
        id: userId,
        name: 'User Logout',
        email: 'logout@test.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final authRepo = _StaticAuthRepository(staticUser, sessionStore: sessionStore);
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
        dbHelper: dbHelper,
      );

      // Login dan isi SQLite dengan data user
      await authController.login('logout@test.com', 'password123');
      expect(authController.isAuthenticated, isTrue);

      await db.insert('user_books', {
        'id': 'ub-1',
        'user_id': userId,
        'google_books_id': 'gb-1',
        'title': 'Buku 1',
        'list_type': 'collection',
        'status': 'finished',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('reading_sessions', {
        'id': 'rs-1',
        'user_id': userId,
        'user_book_id': 'ub-1',
        'started_at': DateTime.now().toIso8601String(),
        'ended_at': DateTime.now().toIso8601String(),
        'duration_seconds': 120,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('chat_messages', {
        'id': 'cm-1',
        'user_id': userId,
        'role': 'user',
        'content': 'Halo AI',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Simpan pengaturan per-perangkat di SharedPreferences
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'pref_reading_reminder_hour': 21,
        'pref_reading_reminder_minute': 30,
      });

      // Verifikasi data lokal terisi sebelum logout
      final countBefore = _firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM user_books WHERE user_id = ?', [userId]),
      );
      expect(countBefore, 1);

      // Eksekusi Logout
      await authController.logout();

      // Verifikasi:
      // 1. Data lokal user di SQLite terhapus bersih (clearUserData)
      final userBooksAfter = _firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM user_books WHERE user_id = ?', [userId]),
      );
      final readingSessionsAfter = _firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM reading_sessions WHERE user_id = ?', [userId]),
      );
      final chatAfter = _firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM chat_messages WHERE user_id = ?', [userId]),
      );
      expect(userBooksAfter, 0, reason: 'Tabel user_books lokal harus dihapus saat logout');
      expect(readingSessionsAfter, 0, reason: 'Tabel reading_sessions lokal harus dihapus saat logout');
      expect(chatAfter, 0, reason: 'Tabel chat_messages lokal harus dihapus saat logout');

      // 2. Sesi terhapus
      expect(authController.isAuthenticated, isFalse);
      expect(await sessionStore.hasSession(), isFalse);

      // 3. Pengaturan per perangkat (tema & jam pengingat) TETAP utuh
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark', reason: 'Tema per perangkat tidak boleh dihapus');
      expect(prefs.getInt('pref_reading_reminder_hour'), 21, reason: 'Jam pengingat per perangkat tidak boleh dihapus');
    });

    testWidgets('ProfilePage menampilkan dialog peringatan saat masih ada data pending sebelum logout', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

      const userId = '00000000-0000-4000-8000-000000000001';
      final sessionStore = _MockSessionStore();
      final staticUser = AppUser(
        id: userId,
        name: 'User Logout Pending',
        email: 'pending@test.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockSync = _PendingMockSyncService(customPendingCount: 1);
      SyncService.testInstance = mockSync;

      final authRepo = _StaticAuthRepository(staticUser, sessionStore: sessionStore);
      final mockDbHelper = _MockDatabaseHelper();
      final authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: DemoControls(),
        dbHelper: mockDbHelper,
      );
      await authController.login('pending@test.com', 'password123');

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('Login Page')),
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SecureSessionStore>.value(value: sessionStore),
            ChangeNotifierProvider<ThemeController>.value(value: ThemeController()),
            ChangeNotifierProvider<DemoControls>.value(value: DemoControls()),
            ChangeNotifierProvider<AuthController>.value(value: authController),
            Provider<LibraryRepository>.value(value: FakeLibraryRepository()),
            Provider<ReadingRepository>.value(value: FakeReadingRepository()),
            Provider<ProfileRepository>.value(value: _MockProfileRepository()),
            Provider<LedgerRepository>.value(value: _InMemoryLedgerRepository()),
            Provider<LedgerService>.value(value: LedgerService(_InMemoryLedgerRepository())),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll dan tap tombol logout
      final logoutBtn = find.text('Keluar dari Akun (Logout)');
      await tester.ensureVisible(logoutBtn);
      await tester.pumpAndSettle();
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // 1. Dialog pertama muncul: Konfirmasi Keluar
      expect(find.text('Konfirmasi Keluar'), findsOneWidget);

      // Tap Keluar pada dialog pertama
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      // 2. Karena ada data pending, dialog kedua harus muncul dengan pesan peringatan PRD §7.8
      expect(find.textContaining('Ada data belum tersinkron, tetap logout?'), findsOneWidget);

      // Tap Batal pada dialog peringatan pending
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Logout dibatalkan, user tetap login
      expect(authController.isAuthenticated, isTrue);

      // Coba lagi dan sekarang pilih tetap logout
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ada data belum tersinkron, tetap logout?'), findsOneWidget);

      await tester.tap(find.text('Tetap Logout'));
      await tester.pumpAndSettle();

      // Verifikasi: user ter-logout dan diarahkan ke /login, clearUserData dipanggil
      expect(authController.isAuthenticated, isFalse);
      expect(mockDbHelper.cleared, isTrue, reason: 'clearUserData harus dipanggil saat logout');
      expect(mockDbHelper.clearedUserId, userId);
      expect(find.text('Login Page'), findsOneWidget);
    });
  });

  group('Fase F1.5 — Resolusi Konflik Sinkronisasi', () {
    test('Dua perangkat menambah buku yang sama (google_books_id sama); hasil akhir satu baris, pending nol, reading_sessions dialihkan', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      const userId = '00000000-0000-4000-8000-000000000001';
      final remoteSource = _FakeSyncRemoteSource();
      final syncService = SyncService.forTesting(
        dbHelper: dbHelper,
        remoteSource: remoteSource,
      );

      // 1. Simulasi Perangkat A telah menyinkronkan buku ke remote terlebih dahulu
      final remoteBook = {
        'id': 'ub-remote-devA',
        'user_id': userId,
        'google_books_id': 'gb-conflict-1',
        'title': 'Buku Perangkat A',
        'list_type': 'collection',
        'status': 'not_started',
        'current_page': 0,
        'is_deleted': false,
        'created_at': DateTime.utc(2025, 5, 1, 10, 0, 0).toIso8601String(),
        'updated_at': DateTime.utc(2025, 5, 1, 10, 0, 0).toIso8601String(),
      };
      await remoteSource.upsert('user_books', remoteBook);

      // 2. Perangkat B (lokal) menambahkan buku yang sama saat offline dengan ID berbeda & updated_at lebih baru
      const localBookId = 'ub-local-devB';
      await db.insert('user_books', {
        'id': localBookId,
        'user_id': userId,
        'google_books_id': 'gb-conflict-1',
        'title': 'Buku Perangkat B (Menang LWW)',
        'list_type': 'collection',
        'status': 'reading',
        'current_page': 42,
        'is_deleted': 0,
        'created_at': DateTime.utc(2025, 5, 1, 9, 0, 0).toIso8601String(),
        'updated_at': DateTime.utc(2025, 5, 1, 12, 0, 0).toIso8601String(),
        'sync_status': 'pending',
      });

      // Perangkat B juga memiliki sesi baca lokal yang merujuk localBookId
      await db.insert('reading_sessions', {
        'id': 'rs-local-1',
        'user_id': userId,
        'user_book_id': localBookId,
        'started_at': DateTime.utc(2025, 5, 1, 11, 0, 0).toIso8601String(),
        'ended_at': DateTime.utc(2025, 5, 1, 12, 0, 0).toIso8601String(),
        'duration_seconds': 3600,
        'created_at': DateTime.utc(2025, 5, 1, 12, 0, 0).toIso8601String(),
        'sync_status': 'pending',
      });

      // Pastikan ada status pending sebelum push
      expect(await syncService.refreshPendingCount(userId: userId), greaterThan(0));

      // 3. Jalankan pushPending
      await syncService.pushPending(userId: userId);

      // 4. Verifikasi setelah resolusi konflik:
      // a. Pending count harus 0 (tidak boleh macet pending)
      final pendingCount = await syncService.refreshPendingCount(userId: userId);
      expect(pendingCount, 0, reason: 'Pending count harus 0 setelah resolusi konflik');

      // b. Hasil akhir di SQLite lokal hanya 1 baris untuk buku tersebut
      final localBooks = await db.query(
        'user_books',
        where: 'user_id = ? AND google_books_id = ?',
        whereArgs: [userId, 'gb-conflict-1'],
      );
      expect(localBooks.length, 1, reason: 'Hanya boleh ada satu baris buku');
      // ID remote dipertahankan
      expect(localBooks.first['id'], 'ub-remote-devA');
      // Data lokal menang (LWW)
      expect(localBooks.first['title'], 'Buku Perangkat B (Menang LWW)');
      expect(localBooks.first['sync_status'], 'synced');

      // c. reading_sessions lokal dialihkan ke remote ID ('ub-remote-devA')
      final sessions = await db.query('reading_sessions', where: 'id = ?', whereArgs: ['rs-local-1']);
      expect(sessions.first['user_book_id'], 'ub-remote-devA');
    });

    test('Konflik ledger_blocks tidak menimpa remote dan ditandai conflict agar tidak loop pending', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      const userId = '00000000-0000-4000-8000-000000000001';
      final remoteSource = _FakeSyncRemoteSource();
      final syncService = SyncService.forTesting(
        dbHelper: dbHelper,
        remoteSource: remoteSource,
      );

      // 1. Remote sudah punya block_index 1
      await remoteSource.upsert('ledger_blocks', {
        'id': 'block-remote-1',
        'user_id': userId,
        'block_index': 1,
        'timestamp': DateTime.utc(2025, 5, 1, 10, 0, 0).toIso8601String(),
        'data_json': jsonEncode({'type': 'remote'}),
        'previous_hash': 'prev-hash-remote',
        'nonce': 100,
        'hash': 'hash-remote-1',
        'created_at': DateTime.utc(2025, 5, 1, 10, 0, 0).toIso8601String(),
      });

      // 2. Lokal punya blok dengan block_index 1 dan ID berbeda
      await db.insert('ledger_blocks', {
        'id': 'block-local-1',
        'user_id': userId,
        'block_index': 1,
        'timestamp': DateTime.utc(2025, 5, 1, 11, 0, 0).toIso8601String(),
        'data_json': jsonEncode({'type': 'local'}),
        'previous_hash': 'prev-hash-local',
        'nonce': 200,
        'hash': 'hash-local-1',
        'created_at': DateTime.utc(2025, 5, 1, 11, 0, 0).toIso8601String(),
        'sync_status': 'pending',
      });

      expect(await syncService.refreshPendingCount(userId: userId), 1);

      // 3. Push pending
      await syncService.pushPending(userId: userId);

      // 4. Verifikasi:
      // Blok lokal ditandai conflict, pendingCount = 0
      final pendingCount = await syncService.refreshPendingCount(userId: userId);
      expect(pendingCount, 0, reason: 'Pending count harus 0, blok konflik tidak loop pending');

      final localBlock = (await db.query('ledger_blocks', where: 'id = ?', whereArgs: ['block-local-1'])).first;
      expect(localBlock['sync_status'], 'conflict');

      // Remote tidak tertimpa
      final remoteRows = await remoteSource.fetchRows('ledger_blocks', userId);
      expect(remoteRows.first['id'], 'block-remote-1');
    });
  });

  group('Fase F1.6 — Perbaikan Kecil Terkait', () {
    test('LocalLibraryRepository.getBookById memfilter user_id aktif sehingga tidak mengakses buku user lain', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      final sessionStore = _MockSessionStore();
      final userA = AppUser(
        id: '00000000-0000-4000-8000-00000000000A',
        name: 'User A',
        email: 'userA@test.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final userB = AppUser(
        id: '00000000-0000-4000-8000-00000000000B',
        name: 'User B',
        email: 'userB@test.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = LocalLibraryRepository(dbHelper: dbHelper, sessionStore: sessionStore);

      // Simpan buku milik User A
      await sessionStore.saveSession(token: 'token-A', user: userA);
      final bookA = await repo.addBook(UserBook(
        id: 'book-A-1',
        userId: userA.id,
        googleBooksId: 'gb-A-1',
        title: 'Buku Rahasia User A',
        listType: ListType.collection,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // User A bisa mengambil bukunya
      final retrievedA = await repo.getBookById(bookA.id);
      expect(retrievedA, isNotNull);
      expect(retrievedA?.title, 'Buku Rahasia User A');

      // Ganti sesi ke User B
      await sessionStore.saveSession(token: 'token-B', user: userB);

      // User B mencoba mengambil buku milik User A dengan ID yang diketahui
      final retrievedB = await repo.getBookById(bookA.id);
      expect(retrievedB, isNull, reason: 'getBookById harus memfilter user_id aktif dan tidak mengembalikan buku user lain');
    });

    test('Buku yang dihidupkan kembali (is_deleted -> 0) statusnya kembali bersih kecuali ada progres disengaja', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      final sessionStore = _MockSessionStore();
      final user = AppUser(
        id: '00000000-0000-4000-8000-00000000000C',
        name: 'User Restore',
        email: 'restore@test.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await sessionStore.saveSession(token: 'token-restore', user: user);

      final repo = LocalLibraryRepository(dbHelper: dbHelper, sessionStore: sessionStore);

      // 1. Tambah buku dan ubah progresnya
      final initialBook = await repo.addBook(UserBook(
        id: 'book-restore-1',
        userId: user.id,
        googleBooksId: 'gb-restore-1',
        title: 'Buku Yang Dihapus Lalu Ditambah Lagi',
        pageCount: 300,
        listType: ListType.collection,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await repo.updateBook(initialBook.copyWith(
        status: BookStatus.reading,
        currentPage: 150,
        rating: 5,
        review: 'Ulasan lama',
        startedAt: DateTime.now(),
      ));

      // 2. Hapus buku (soft-delete)
      await repo.deleteBook(initialBook.id);
      final deleted = await repo.getBookById(initialBook.id);
      expect(deleted, isNull);

      // 3. User menambahkan buku yang sama lagi dari pencarian (status fresh/bersih)
      final reAddedFresh = await repo.addBook(UserBook(
        id: 'book-new-id',
        userId: user.id,
        googleBooksId: 'gb-restore-1',
        title: 'Buku Yang Dihapus Lalu Ditambah Lagi',
        pageCount: 300,
        listType: ListType.collection,
        status: BookStatus.notStarted,
        currentPage: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // ID lama dipertahankan, tetapi status baca kembali bersih
      expect(reAddedFresh.isDeleted, isFalse);
      expect(reAddedFresh.status, BookStatus.notStarted, reason: 'Status harus bersih kembali ke not_started');
      expect(reAddedFresh.currentPage, 0, reason: 'currentPage harus bersih kembali ke 0');
      expect(reAddedFresh.rating, isNull, reason: 'Rating lama harus dibersihkan');
      expect(reAddedFresh.review, isNull, reason: 'Review lama harus dibersihkan');
    });

    test('moveToCollection memindahkan buku tanpa mereset progres baca sesuai PRD §7.6', () async {
      final db = await _createInMemoryDb();
      addTearDown(() async => await db.close());
      DatabaseHelper.setTestDatabase(db);
      final dbHelper = DatabaseHelper.instance;

      final sessionStore = _MockSessionStore();
      final user = AppUser(
        id: '00000000-0000-4000-8000-00000000000D',
        name: 'User Move',
        email: 'move@test.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await sessionStore.saveSession(token: 'token-move', user: user);

      final repo = LocalLibraryRepository(dbHelper: dbHelper, sessionStore: sessionStore);

      // Tambah buku ke wishlist dengan progres
      final wishBook = await repo.addBook(UserBook(
        id: 'book-wish-1',
        userId: user.id,
        googleBooksId: 'gb-wish-1',
        title: 'Buku Wishlist',
        listType: ListType.wishlist,
        status: BookStatus.reading,
        currentPage: 45,
        pageCount: 200,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final moved = await repo.moveToCollection(wishBook.id);
      expect(moved.listType, ListType.collection);
      expect(moved.status, BookStatus.reading, reason: 'Status membaca tidak boleh direset');
      expect(moved.currentPage, 45, reason: 'Progres membaca tidak boleh direset');
    });
  });
}

int _firstIntValue(List<Map<String, Object?>> rows) =>
    (rows.first.values.first as num?)?.toInt() ?? 0;

class _MockProfileRepository implements ProfileRepository {
  @override
  Future<AppUser> getProfile() async {
    return AppUser(
      id: 'mock-user-1',
      name: 'Mock User',
      email: 'mock@test.com',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<AppUser> updateProfile({
    required String name,
    String? bio,
    String? avatarPath,
  }) async {
    return AppUser(
      id: 'mock-user-1',
      name: name,
      email: 'mock@test.com',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _MockSessionStore extends SecureSessionStore {
  final Map<String, String> _data = {};

  @override
  Future<void> saveSession({
    required String token,
    required AppUser user,
    String? mode = 'real',
  }) async {
    _data['token'] = token;
    _data['user'] = jsonEncode(user.toJson());
    _data['mode'] = mode ?? 'real';
  }

  @override
  Future<String?> getSessionMode() async => _data['mode'];

  @override
  Future<void> saveUser(AppUser user) async {
    _data['user'] = jsonEncode(user.toJson());
  }

  @override
  Future<String?> getToken() async => _data['token'];

  @override
  Future<AppUser?> getUser() async {
    final str = _data['user'];
    if (str == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasSession() async {
    final token = _data['token'];
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> clearSession() async {
    _data.clear();
  }

  @override
  Future<bool> isBiometricEnabled() async => _data['bio'] == 'true';

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    _data['bio'] = enabled ? 'true' : 'false';
  }
}

class _StaticAuthRepository implements AuthRepository {
  final AppUser user;
  final SecureSessionStore? sessionStore;
  _StaticAuthRepository(this.user, {this.sessionStore});

  @override
  Future<AppUser> login(String email, String password) async {
    if (sessionStore != null) {
      await sessionStore!.saveSession(
        token: 'token-static-123',
        user: user,
        mode: 'real',
      );
    }
    return user;
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    if (sessionStore != null) {
      await sessionStore!.saveSession(
        token: 'token-static-123',
        user: user,
        mode: 'real',
      );
    }
    return user;
  }

  @override
  Future<AppUser?> validateSession() async => user;

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<void> logout() async {
    await sessionStore?.clearSession();
  }
}

class _InMemoryLedgerRepository implements LedgerRepository {
  final List<LedgerBlock> _blocks = [];

  @override
  Future<List<LedgerBlock>> getBlocks() async => List.unmodifiable(_blocks);

  @override
  Future<LedgerBlock?> getLastBlock() async =>
      _blocks.isEmpty ? null : _blocks.last;

  @override
  Future<void> saveBlock(LedgerBlock block) async {
    _blocks.add(block);
  }
}

class _FakeSyncRemoteSource extends SyncRemoteSource {
  final Map<String, List<Map<String, dynamic>>> tables = {
    'user_books': [],
    'reading_sessions': [],
    'ledger_blocks': [],
    'feedbacks': [],
    'game_scores': [],
  };

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final list = tables[table] ?? [];
    if (table == 'ledger_blocks') {
      final conflict = list.any((item) =>
          item['user_id'] == data['user_id'] &&
          item['block_index'] == data['block_index'] &&
          item['id'] != data['id']);
      if (conflict) {
        throw const PostgrestException(
          message:
              'duplicate key value violates unique constraint "ledger_blocks_user_id_block_index_key"',
          code: '23505',
        );
      }
    }
    if (table == 'user_books') {
      final conflict = list.any((item) =>
          item['user_id'] == data['user_id'] &&
          item['google_books_id'] == data['google_books_id'] &&
          item['id'] != data['id']);
      if (conflict) {
        throw const PostgrestException(
          message:
              'duplicate key value violates unique constraint "user_books_user_id_google_books_id_key"',
          code: '23505',
        );
      }
    }
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
    return 'https://mock.url/avatar.jpg';
  }
}

Future<Database> _createInMemoryDb() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ledger_blocks (
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
    CREATE TABLE IF NOT EXISTS user_books (
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
    CREATE TABLE IF NOT EXISTS reading_sessions (
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
    CREATE TABLE IF NOT EXISTS feedbacks (
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
    CREATE TABLE IF NOT EXISTS chat_messages (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS game_scores (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      game_type TEXT NOT NULL,
      score INTEGER NOT NULL,
      played_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending'
    );
  ''');
  await db.delete('ledger_blocks');
  await db.delete('user_books');
  await db.delete('reading_sessions');
  await db.delete('feedbacks');
  await db.delete('chat_messages');
  await db.delete('game_scores');
  return db;
}


class _MockDatabaseHelper extends DatabaseHelper {
  bool cleared = false;
  String? clearedUserId;

  _MockDatabaseHelper() : super.forTesting();

  @override
  Future<void> clearUserData(String userId) async {
    cleared = true;
    clearedUserId = userId;
  }
}

class _PendingMockSyncService extends SyncService {
  final int customPendingCount;
  _PendingMockSyncService({this.customPendingCount = 1})
      : super.forTesting(remoteSource: _FakeSyncRemoteSource());

  @override
  int get pendingCount => customPendingCount;

  @override
  bool get hasPendingChanges => customPendingCount > 0;

  @override
  Future<int> refreshPendingCount({String? userId}) async => customPendingCount;

  @override
  Future<void> syncBeforeLogout(String userId) async {}

  @override
  Future<void> pullAll(String userId) async {}

  @override
  Future<int> pushPending({String? userId}) async => 0;
}




