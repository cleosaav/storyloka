import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../app/providers.dart';
import '../../core/services/ledger_service.dart';
import '../../core/services/secure_session_store.dart';
import '../../core/services/sync_service.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';

/// Controller state autentikasi — PRD §7.1 & §13.0 Fase A1.
/// Mengelola status login, sesi aman, lock screen biometrik,
/// dan bertindak sebagai [Listenable] untuk redirect guard [GoRouter].
class AuthController extends ChangeNotifier {
  final AuthRepository authRepository;
  final SecureSessionStore sessionStore;
  final DemoControls demoControls;
  final LedgerService? ledgerService;

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isBiometricLocked = false;
  bool _hasSplashTimeout = false;
  String? _errorMessage;

  AuthController({
    required this.authRepository,
    required this.sessionStore,
    required this.demoControls,
    this.ledgerService,
  });

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isBiometricLocked => _isBiometricLocked;
  bool get hasSplashTimeout => _hasSplashTimeout;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Cek session tersimpan saat startup (di Splash Page).
  Future<void> checkSession() async {
    _isLoading = true;
    _hasSplashTimeout = false;
    _errorMessage = null;
    notifyListeners();

    try {
      // PRD §7.1 & Fase R1: Sesi tersimpan harus ditandai mode pembuatannya.
      // Jika ditemukan sesi dari mode fake saat app berjalan nyata, hapus dan arahkan ke /login.
      if (!AppConfig.useFakeData) {
        final sessionMode = await sessionStore.getSessionMode();
        if (sessionMode == 'fake') {
          await sessionStore.clearSession();
          _currentUser = null;
          _isBiometricLocked = false;
          _isInitialized = true;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (demoControls.simulateSlowLatency) {
        await Future.delayed(const Duration(seconds: 2));
      }

      // Batas waktu 10 detik pada proses di splash (termasuk validate_session) — Fase R1
      final user = await authRepository.validateSession().timeout(
        const Duration(seconds: 10),
      );

      if (user != null) {
        _currentUser = user;
        final bioEnabled = await sessionStore.isBiometricEnabled();
        if (bioEnabled && !demoControls.bypassBiometric) {
          _isBiometricLocked = true;
        } else {
          _isBiometricLocked = false;
        }
        // PRD §10.2: Genesis block dibuat saat sesi tervalidasi jika belum ada
        try {
          await ledgerService?.ensureGenesisBlock(user.id);
        } catch (_) {}
      } else {
        _currentUser = null;
        _isBiometricLocked = false;
      }
      _isInitialized = true;
      _hasSplashTimeout = false;
    } on TimeoutException {
      // Timeout 10 detik terjadi
      _hasSplashTimeout = true;
      _errorMessage = 'Koneksi ke server gagal (timeout 10 detik). Periksa jaringan Anda.';
      // Jangan set _isInitialized = true agar tetap berada di Splash menampilkan error state
    } catch (_) {
      _currentUser = null;
      _isBiometricLocked = false;
      _isInitialized = true;
      _hasSplashTimeout = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Aksi "Masuk Ulang" dari layar error Splash timeout — Fase R1.
  Future<void> forceReLogin() async {
    await sessionStore.clearSession();
    _currentUser = null;
    _isBiometricLocked = false;
    _hasSplashTimeout = false;
    _errorMessage = null;
    _isInitialized = true;
    notifyListeners();
  }

  /// Login email & password — PRD §7.1.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (demoControls.simulateNetworkError) {
        throw Exception('NETWORK_ERROR');
      }

      final user = await authRepository.login(email.trim(), password);
      _currentUser = user;
      _isBiometricLocked = false;
      _errorMessage = null;

      // PRD §10.2: Genesis block dibuat saat login jika belum ada
      try {
        await ledgerService?.ensureGenesisBlock(user.id);
      } catch (_) {}

      // PRD §8.3: Pull data setelah login berhasil
      SyncService.instance.pullAll(user.id);

      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      if (msg.contains('INVALID_CREDENTIALS') || msg.contains('Email atau kata sandi salah')) {
        _errorMessage = 'Email atau password salah.';
      } else if (msg.contains('EMAIL_TAKEN') || msg.contains('Email sudah terdaftar')) {
        _errorMessage = 'Email sudah terdaftar.';
      } else if (msg.contains('NETWORK_ERROR')) {
        _errorMessage = 'Gagal terhubung ke jaringan (simulasi error).';
      } else if (msg.isNotEmpty) {
        _errorMessage = msg;
      } else {
        _errorMessage = 'Terjadi kesalahan saat masuk. Silakan coba lagi.';
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register pengguna baru — PRD §7.1.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (demoControls.simulateNetworkError) {
        throw Exception('NETWORK_ERROR');
      }

      final user = await authRepository.register(
        name.trim(),
        email.trim(),
        password,
      );
      _currentUser = user;
      _isBiometricLocked = false;
      _errorMessage = null;

      // PRD §10.2: Genesis block dibuat saat register jika belum ada
      try {
        await ledgerService?.ensureGenesisBlock(user.id);
      } catch (_) {}

      // PRD §8.3: Pull data setelah register berhasil
      SyncService.instance.pullAll(user.id);

      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      if (msg.contains('EMAIL_TAKEN') || msg.contains('Email sudah terdaftar')) {
        _errorMessage = 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
      } else if (msg.contains('NETWORK_ERROR')) {
        _errorMessage = 'Gagal terhubung ke jaringan (simulasi error).';
      } else if (msg.isNotEmpty) {
        _errorMessage = msg;
      } else {
        _errorMessage = 'Gagal mendaftar. Silakan coba lagi.';
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout & bersihkan session — PRD §7.1 & §8.3.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // PRD §8.3: Sinkronkan pending changes sebelum logout
      if (_currentUser != null) {
        await SyncService.instance.syncBeforeLogout(_currentUser!.id);
      }
      await authRepository.logout();
    } finally {
      _currentUser = null;
      _isBiometricLocked = false;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Buka kunci biometrik berhasil.
  void unlockBiometric() {
    _isBiometricLocked = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Fallback login password dari Lock Screen (menghapus session lokal → /login).
  Future<void> loginWithPasswordFallback() async {
    await logout();
  }

  /// Pengaturan status biometrik (aktif/nonaktif).
  Future<void> setBiometricEnabled(bool enabled) async {
    await sessionStore.setBiometricEnabled(enabled);
    notifyListeners();
  }

  /// Memperbarui informasi profil pengguna saat ini.
  Future<void> updateProfile({
    required String name,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(
      name: name,
      bio: bio,
      avatarUrl: avatarUrl,
      updatedAt: DateTime.now(),
    );
    _currentUser = updated;
    await sessionStore.saveUser(updated);
    notifyListeners();
  }
}
