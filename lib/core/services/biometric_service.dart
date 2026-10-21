import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service biometrik perangkat nyata — PRD §7.1, §7.8 & §14.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Cek apakah perangkat mendukung dan memiliki sensor biometrik terdaftar.
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Dapatkan daftar tipe biometrik yang tersedia di perangkat (mis. fingerprint, face).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Minta autentikasi biometrik pengguna.
  /// Mengembalikan true jika verifikasi sukses, false jika gagal / dibatalkan.
  Future<bool> authenticate({
    String localizedReason = 'Gunakan biometrik untuk masuk ke StoryLoka',
  }) async {
    try {
      final available = await canAuthenticate();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
