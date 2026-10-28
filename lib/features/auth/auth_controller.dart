import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../app/providers.dart';
import '../../core/services/ledger_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/secure_session_store.dart';
import '../../core/services/sync_service.dart';
import '../../core/widgets/demo_widgets.dart';
import '../../data/database_helper.dart';
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
  final DatabaseHelper dbHelper;

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
    DatabaseHelper? dbHelper,
  }) : dbHelper = dbHelper ?? DatabaseHelper.instance;

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
        // Panggil pushPending SEBELUM pullAll agar data lokal terkirim terlebih dahulu
        try {
          await SyncService.instance.pushPending(userId: user.id);
          await SyncService.instance.pullAll(user.id);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthController] Gagal sync saat checkSession: $e');
          }
        }
        // PRD §10.2: Genesis block dibuat saat sesi tervalidasi jika setelah pull masih belum ada
        try {
          await ledgerService?.ensureGenesisBlock(user.id);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthController] Gagal ensureGenesisBlock saat checkSession: $e');
          }
        }
      } else {
        _currentUser = null;
        _isBiometricLocked = false;
      }
      _isInitialized = true;
      _hasSplashTimeout = false;
    } on TimeoutException {
      // Timeout 10 detik terjadi
      final cachedUser = await sessionStore.getUser();
      final hasToken = await sessionStore.hasSession();

      if (cachedUser != null && hasToken) {
        // F1.1: timeout 10 detik tidak boleh membuat user menunggu di splash saat sudah ada sesi lokal;
        // lanjut ke Home dengan sesi lokal dan validasi ulang di latar belakang.
        _currentUser = cachedUser;
        final bioEnabled = await sessionStore.isBiometricEnabled();
        _isBiometricLocked = bioEnabled && !demoControls.bypassBiometric;
        _isInitialized = true;
        _hasSplashTimeout = false;

        unawaited(_revalidateInBackground());
      } else {
        _hasSplashTimeout = true;
        _errorMessage = 'Koneksi ke server gagal (timeout 10 detik). Periksa jaringan Anda.';
        // Jangan set _isInitialized = true agar tetap berada di Splash menampilkan error state
      }
    } catch (_) {
      final cachedUser = await sessionStore.getUser();
      final hasToken = await sessionStore.hasSession();

      if (cachedUser != null && hasToken) {
        _currentUser = cachedUser;
        final bioEnabled = await sessionStore.isBiometricEnabled();
        _isBiometricLocked = bioEnabled && !demoControls.bypassBiometric;
        _isInitialized = true;
        _hasSplashTimeout = false;

        unawaited(_revalidateInBackground());
      } else {
        _currentUser = null;
        _isBiometricLocked = false;
        _isInitialized = true;
        _hasSplashTimeout = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Validasi ulang sesi di latar belakang bila offline/timeout selesai (PRD §7.1).
  Future<void> _revalidateInBackground() async {
    try {
      final validatedUser = await authRepository.validateSession();
      if (validatedUser == null) {
        // Jika server menyatakan tidak valid -> logout paksa (PRD §7.1)
        _currentUser = null;
        _isBiometricLocked = false;
        _errorMessage = 'Sesi Anda telah berakhir. Silakan masuk kembali.';
        notifyListeners();
      } else {
        // F1.3: Sinkronisasi data saat revalidasi latar belakang sukses (push sebelum pull)
        try {
          await SyncService.instance.pushPending(userId: validatedUser.id);
          await SyncService.instance.pullAll(validatedUser.id);
          await ledgerService?.ensureGenesisBlock(validatedUser.id);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthController] Gagal sync/genesis latar belakang: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthController] Re-validasi latar belakang gagal: $e');
      }
      // Abaikan kegagalan jaringan saat background re-validation
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

      // PRD §8.3 & F1.3: Push data lokal pending terlebih dahulu, baru pull dari server
      try {
        await SyncService.instance.pushPending(userId: user.id);
        await SyncService.instance.pullAll(user.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthController] Gagal sync setelah login: $e');
        }
      }

      // PRD §10.2: Genesis block dibuat saat login jika setelah pull masih belum ada
      try {
        await ledgerService?.ensureGenesisBlock(user.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthController] Gagal ensureGenesisBlock setelah login: $e');
        }
      }

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

      // PRD §8.3 & F1.3: Push data lokal pending terlebih dahulu, baru pull dari server
      try {
        await SyncService.instance.pushPending(userId: user.id);
        await SyncService.instance.pullAll(user.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthController] Gagal sync setelah register: $e');
        }
      }

      // PRD §10.2: Genesis block dibuat saat register jika setelah pull masih belum ada
      try {
        await ledgerService?.ensureGenesisBlock(user.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthController] Gagal ensureGenesisBlock setelah register: $e');
        }
      }

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

  /// Logout & bersihkan session — PRD §7.1, §7.8, & §8.3.
  Future<void> logout({bool skipSync = false, bool forceClearUserData = false}) async {
    _isLoading = true;
    notifyListeners();

    final userId = _currentUser?.id;

    try {
      // PRD §8.3: Sinkronkan pending changes sebelum logout jika belum di-sync
      if (!skipSync && userId != null && userId.isNotEmpty) {
        try {
          await SyncService.instance.syncBeforeLogout(userId);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthController] Gagal syncBeforeLogout: $e');
          }
        }
      }

      // 1. logout_session di server (PRD §7.8)
      try {
        await authRepository.logout();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthController] Gagal logout remote: $e');
        }
      }

      // 2. hapus sesi lokal
      await sessionStore.clearSession();

      // 3. Poin 3d: Cek apakah masih ada baris pending/error setelah push.
      // Jika logout dipanggil tanpa dialog (skipSync: false) dan masih ada pending/error setelah push,
      // lewati clearUserData agar data lokal tidak hilang (tetap terisolasi per user_id).
      // Namun jika user sudah mengonfirmasi di dialog ProfilePage (skipSync: true / forceClearUserData: true),
      // clearUserData tetap dijalankan sesuai PRD §7.8.
      if (userId != null && userId.isNotEmpty) {
        try {
          final pendingOrError =
              await SyncService.instance.refreshPendingCount(userId: userId);
          final shouldSkipClear = !skipSync && !forceClearUserData && pendingOrError > 0;
          if (shouldSkipClear) {
            if (kDebugMode) {
              debugPrint(
                  '[AuthController] Lewati clearUserData untuk $userId karena masih ada $pendingOrError baris pending/error.');
            }
          } else {
            await dbHelper.clearUserData(userId);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AuthController] Gagal memeriksa status sync / clearUserData: $e');
          }
        }
      }

      // 4. batalkan notifikasi terjadwal dan stopwatch — PRD §7.8 & §10.5
      try {
        await NotificationService.instance.cancelDailyReadingReminder();
        await NotificationService.instance.cancelStopwatchNotification();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthController] Gagal membatalkan notifikasi saat logout: $e');
        }
      }
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
