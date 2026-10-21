import '../models/app_user.dart';

/// Kontrak autentikasi — PRD §13.0 aturan 1.
/// UI hanya bergantung pada abstraksi ini.
abstract class AuthRepository {
  /// Login dengan email dan password.
  /// Melempar [Exception] jika gagal (mis. INVALID_CREDENTIALS).
  Future<AppUser> login(String email, String password);

  /// Register user baru.
  /// Melempar [Exception] jika gagal (mis. EMAIL_TAKEN).
  Future<AppUser> register(String name, String email, String password);

  /// Logout. Membersihkan session.
  Future<void> logout();

  /// Validasi session yang tersimpan.
  /// Mengembalikan `null` jika tidak ada session / session tidak valid.
  Future<AppUser?> validateSession();

  /// Cek apakah ada session tersimpan.
  Future<bool> hasSession();
}
