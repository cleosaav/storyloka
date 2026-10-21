import 'package:flutter/foundation.dart';
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

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isBiometricLocked = false;
  String? _errorMessage;

  AuthController({
    required this.authRepository,
    required this.sessionStore,
    required this.demoControls,
  });

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isBiometricLocked => _isBiometricLocked;
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
    notifyListeners();

    try {
      if (demoControls.simulateSlowLatency) {
        await Future.delayed(const Duration(seconds: 2));
      }

      final user = await authRepository.validateSession();
      if (user != null) {
        _currentUser = user;
        final bioEnabled = await sessionStore.isBiometricEnabled();
        if (bioEnabled && !demoControls.bypassBiometric) {
          _isBiometricLocked = true;
        } else {
          _isBiometricLocked = false;
        }
      } else {
        _currentUser = null;
        _isBiometricLocked = false;
      }
    } catch (_) {
      _currentUser = null;
      _isBiometricLocked = false;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
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

      // PRD §8.3: Pull data setelah login berhasil
      SyncService.instance.pullAll(user.id);

      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('INVALID_CREDENTIALS')) {
        _errorMessage = 'Email atau password salah.';
      } else if (msg.contains('EMAIL_TAKEN')) {
        _errorMessage = 'Email sudah terdaftar.';
      } else if (msg.contains('NETWORK_ERROR')) {
        _errorMessage = 'Gagal terhubung ke jaringan (simulasi error).';
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

      // PRD §8.3: Pull data setelah register berhasil
      SyncService.instance.pullAll(user.id);

      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('EMAIL_TAKEN')) {
        _errorMessage = 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
      } else if (msg.contains('NETWORK_ERROR')) {
        _errorMessage = 'Gagal terhubung ke jaringan (simulasi error).';
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
