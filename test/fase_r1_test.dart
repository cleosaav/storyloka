import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/config/env.dart';
import 'package:storyloka/core/config/startup_status.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/widgets/config_error_page.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/models/app_user.dart';
import 'package:storyloka/data/repositories/auth_repository.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/data/repositories/profile_repository.dart';
import 'package:storyloka/data/repositories/supabase/supabase_repositories.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/splash_page.dart';

class _HangingAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> validateSession() async {
    // Delay 15 detik untuk memicu batas waktu 10 detik
    await Future.delayed(const Duration(seconds: 15));
    return null;
  }

  @override
  Future<AppUser> login(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasSession() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Env.reset();
    StartupStatus.instance.reset();
  });

  tearDown(() {
    Env.reset();
    StartupStatus.instance.reset();
  });

  group('Fase R1: Konfigurasi, Mode Nyata, dan Startup Tests', () {
    testWidgets('(a) useFakeData=false + Env tidak valid -> ConfigErrorPage dengan nama variabel kosong',
        (tester) async {
      // Env tidak valid (kosong)
      Env.reset();
      expect(Env.isConfigValid, isFalse);

      final providers = buildAppProviders(useFakeData: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: const StoryLokaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan ConfigErrorPage tampil
      expect(find.byType(ConfigErrorPage), findsOneWidget);
      // Memastikan nama variabel kosong disebut tanpa nilai
      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
      expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
    });

    testWidgets('(b) useFakeData=false + Env valid -> repository yang terikat adalah versi nyata (bukan Fake)',
        (tester) async {
      Env.setMockValues({
        'SUPABASE_URL': 'https://mock.supabase.co',
        'SUPABASE_ANON_KEY': 'mock-anon-key',
      });
      expect(Env.isConfigValid, isTrue);

      final providers = buildAppProviders(useFakeData: false);

      late AuthRepository resolvedAuth;
      late ProfileRepository resolvedProfile;

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) {
              resolvedAuth = context.read<AuthRepository>();
              resolvedProfile = context.read<ProfileRepository>();
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedAuth, isA<SupabaseAuthRepository>());
      expect(resolvedAuth, isNot(isA<FakeAuthRepository>()));

      expect(resolvedProfile, isA<SupabaseProfileRepository>());
      expect(resolvedProfile, isNot(isA<FakeProfileRepository>()));
    });

    test('(c) sesi fake dibersihkan di mode nyata saat startup checkSession',
        () async {
      final sessionStore = SecureSessionStore();
      final dummyUser = AppUser(
        id: 'fake-user-123',
        name: 'Demo Reader',
        email: 'demo@storyloka.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Simpan session fake
      await sessionStore.saveSession(
        token: 'fake-token-abc',
        user: dummyUser,
        mode: 'fake',
      );

      expect(await sessionStore.hasSession(), isTrue);
      expect(await sessionStore.getSessionMode(), 'fake');

      final authController = AuthController(
        authRepository: _HangingAuthRepository(),
        sessionStore: sessionStore,
        demoControls: DemoControls(),
      );

      // Jalankan checkSession (AppConfig.useFakeData adalah false secara default)
      await authController.checkSession();

      // Sesi fake harus otomatis dihapus di mode nyata
      expect(await sessionStore.hasSession(), isFalse);
      expect(await sessionStore.getSessionMode(), isNull);
      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentUser, isNull);
      expect(authController.isInitialized, isTrue);
    });

    testWidgets('(d) timeout splash (10 detik) menampilkan layar error koneksi, Coba Lagi, dan Masuk ulang',
        (tester) async {
      // Tanpa sesi user lokal tersimpan (atau sesi korup), timeout splash memicu error koneksi
      final sessionStore = SecureSessionStore();
      final hangingRepo = _HangingAuthRepository();

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

      // Awalnya menampilkan splash loading
      expect(find.text('StoryLoka'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Jalankan frame berikutnya agar postFrameCallback mengeksekusi checkSession
      await tester.pump();

      // Majukan waktu 11 detik agar timeout 10 detik terpicu
      await tester.pump(const Duration(seconds: 11));
      // Rebuild tampilan setelah notifyListeners dari catch timeout
      await tester.pump();

      // Setelah timeout 10 detik, harus menampilkan error state
      expect(find.text('Koneksi Terputus'), findsOneWidget);
      expect(find.textContaining('timeout 10 detik'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.text('Masuk ulang'), findsOneWidget);

      // Menekan tombol 'Masuk ulang' harus membersihkan sesi dan mereset status
      await tester.tap(find.text('Masuk ulang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(await sessionStore.hasSession(), isFalse);
      expect(authController.hasSplashTimeout, isFalse);
      expect(authController.isInitialized, isTrue);
      expect(authController.isAuthenticated, isFalse);

      // Flush sisa timer Future.delayed (15 detik total)
      await tester.pump(const Duration(seconds: 5));
    });

    test('Env menerima alias SUPABASE_ANON_KEY dan SUPABASE_PUBLISHABLE_KEY', () {
      Env.reset();
      Env.setMockValues({
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'pub-key-alias-123',
      });

      expect(Env.supabaseUrl, 'https://test.supabase.co');
      expect(Env.supabaseAnonKey, 'pub-key-alias-123');
      expect(Env.isSupabaseConfigured, isTrue);
    });

    test('StartupStatus mencatat hasil berhasil dan gagal', () {
      final status = StartupStatus.instance;
      status.reset();
      expect(status.isSupabaseInitialized, isFalse);
      expect(status.isSupabaseFailed, isFalse);

      status.recordSupabaseError('Network timeout');
      expect(status.isSupabaseFailed, isTrue);
      expect(status.supabaseErrorMessage, 'Network timeout');
      expect(status.statusText, contains('FAILED'));

      status.recordSupabaseSuccess();
      expect(status.isSupabaseInitialized, isTrue);
      expect(status.isSupabaseFailed, isFalse);
      expect(status.statusText, 'SUCCESS');
    });
  });
}
