import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/app/providers.dart';
import 'package:storyloka/core/services/secure_session_store.dart';
import 'package:storyloka/core/widgets/demo_widgets.dart';
import 'package:storyloka/data/repositories/fake/fake_repositories.dart';
import 'package:storyloka/features/auth/auth_controller.dart';

void main() {
  group('Fase A1 — Autentikasi & Fake Auth Tests', () {
    late SecureSessionStore sessionStore;
    late FakeAuthRepository authRepo;
    late DemoControls demoControls;
    late AuthController authController;

    setUp(() {
      AppConfig.useFakeData = true;
      sessionStore = SecureSessionStore();
      authRepo = FakeAuthRepository(sessionStore: sessionStore);
      demoControls = DemoControls();
      authController = AuthController(
        authRepository: authRepo,
        sessionStore: sessionStore,
        demoControls: demoControls,
      );
    });

    tearDown(() {
      AppConfig.useFakeData = false;
    });

    test('FakeAuthRepository register with taken@demo.com throws EMAIL_TAKEN', () async {
      expect(
        () => authRepo.register('Budi', 'taken@demo.com', 'password123'),
        throwsA(predicate((e) => e.toString().contains('EMAIL_TAKEN'))),
      );
    });

    test('FakeAuthRepository login with wrong password throws INVALID_CREDENTIALS', () async {
      expect(
        () => authRepo.login('user@demo.com', 'wrong'),
        throwsA(predicate((e) => e.toString().contains('INVALID_CREDENTIALS'))),
      );
    });

    test('FakeAuthRepository successful login and register saves session to storage', () async {
      // Register success
      final newUser = await authRepo.register('Siti', 'siti@demo.com', 'rahasia123');
      expect(newUser.name, 'Siti');
      expect(newUser.email, 'siti@demo.com');

      // Check session in store
      expect(await sessionStore.hasSession(), true);
      final storedUser = await sessionStore.getUser();
      expect(storedUser?.name, 'Siti');
      expect(storedUser?.email, 'siti@demo.com');

      // Logout
      await authRepo.logout();
      expect(await sessionStore.hasSession(), false);
      expect(await sessionStore.getUser(), null);

      // Login success
      final loggedIn = await authRepo.login('siti@demo.com', 'rahasia123');
      expect(loggedIn.email, 'siti@demo.com');
      expect(await sessionStore.hasSession(), true);
    });

    test('AuthController manages state and error messages correctly', () async {
      // Register with taken email
      final regFailed = await authController.register(
        name: 'Andi',
        email: 'taken@demo.com',
        password: 'password123',
      );
      expect(regFailed, false);
      expect(authController.errorMessage, contains('Email sudah terdaftar'));

      // Register with valid email
      final regSuccess = await authController.register(
        name: 'Andi',
        email: 'andi@demo.com',
        password: 'password123',
      );
      expect(regSuccess, true);
      expect(authController.isAuthenticated, true);
      expect(authController.currentUser?.name, 'Andi');

      // Logout
      await authController.logout();
      expect(authController.isAuthenticated, false);
      expect(authController.currentUser, null);

      // Login with wrong password
      final loginWrong = await authController.login('andi@demo.com', 'wrong');
      expect(loginWrong, false);
      expect(authController.errorMessage, 'Email atau password salah.');

      // Login with correct password
      final loginSuccess = await authController.login('andi@demo.com', 'password123');
      expect(loginSuccess, true);
      expect(authController.isAuthenticated, true);
    });

    test('Biometric lock workflow', () async {
      // Login first
      await authController.login('user@storyloka.app', 'password123');
      expect(authController.isBiometricLocked, false);

      // Enable biometric
      await authController.setBiometricEnabled(true);
      expect(await sessionStore.isBiometricEnabled(), true);

      // Simulate app restart / session check
      await authController.checkSession();
      expect(authController.isAuthenticated, true);
      expect(authController.isBiometricLocked, true);

      // Unlock biometric
      authController.unlockBiometric();
      expect(authController.isBiometricLocked, false);

      // Test bypass biometric from DemoControls
      demoControls.toggleBypassBiometric(true);
      await authController.checkSession();
      expect(authController.isBiometricLocked, false);
    });

    test('Password fallback from lock screen clears session', () async {
      await authController.login('reader@storyloka.app', 'password123');
      await authController.setBiometricEnabled(true);
      await authController.checkSession();
      expect(authController.isBiometricLocked, true);

      // User chooses password fallback
      await authController.loginWithPasswordFallback();
      expect(authController.isAuthenticated, false);
      expect(authController.isBiometricLocked, false);
      expect(await sessionStore.hasSession(), false);
    });
  });
}
