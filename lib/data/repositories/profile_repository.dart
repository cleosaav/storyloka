import '../models/app_user.dart';

/// Kontrak profil pengguna — PRD §13.0.
abstract class ProfileRepository {
  /// Ambil profil pengguna saat ini.
  Future<AppUser> getProfile();

  /// Perbarui profil (nama, bio, avatar).
  Future<AppUser> updateProfile({
    required String name,
    String? bio,
    String? avatarPath,
  });
}
