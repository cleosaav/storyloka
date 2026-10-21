import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/app_user.dart';

/// Penyimpanan sesi aman — PRD §7.1 & §13.0.
/// Menyimpan token session dan profil singkat di FlutterSecureStorage
/// dengan fallback in-memory untuk ketahanan di platform/lingkungan test.
class SecureSessionStore {
  static const String _keyToken = 'storyloka_session_token';
  static const String _keyUser = 'storyloka_session_user';
  static const String _keyBiometric = 'storyloka_biometric_enabled';

  final FlutterSecureStorage _storage;
  final Map<String, String> _fallback = {};

  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> _write(String key, String value) async {
    _fallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Abaikan bila platform channel belum tersedia di environment test
    }
  }

  Future<String?> _read(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null) return val;
    } catch (_) {
      // Fallback
    }
    return _fallback[key];
  }

  Future<void> _delete(String key) async {
    _fallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Fallback
    }
  }

  /// Simpan session setelah login/register berhasil.
  Future<void> saveSession({
    required String token,
    required AppUser user,
  }) async {
    await _write(_keyToken, token);
    await _write(_keyUser, jsonEncode(user.toJson()));
  }

  /// Simpan pembaruan data pengguna ke session store.
  Future<void> saveUser(AppUser user) async {
    await _write(_keyUser, jsonEncode(user.toJson()));
  }

  /// Ambil token session yang aktif.
  Future<String?> getToken() async {
    return await _read(_keyToken);
  }

  /// Ambil profil ringkas user yang tersimpan.
  Future<AppUser?> getUser() async {
    final userJson = await _read(_keyUser);
    if (userJson == null) return null;
    try {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      return AppUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Cek apakah session aktif ada di storage.
  Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Hapus token dan data user (saat logout / reset password).
  Future<void> clearSession() async {
    await _delete(_keyToken);
    await _delete(_keyUser);
  }

  /// Status pengaturan biometrik (aktif/nonaktif).
  Future<bool> isBiometricEnabled() async {
    final val = await _read(_keyBiometric);
    return val == 'true';
  }

  /// Atur status biometrik (dari menu Profile/Lock).
  Future<void> setBiometricEnabled(bool enabled) async {
    await _write(_keyBiometric, enabled ? 'true' : 'false');
  }
}
