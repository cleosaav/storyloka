import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/secure_session_store.dart';
import '../../models/app_user.dart';
import '../auth_repository.dart';
import '../profile_repository.dart';

/// Helper pemetaan exception Supabase/Postgrest ke pesan Bahasa Indonesia ramah pengguna — PRD §8.2.
/// PENTING: Jangan mencetak password atau token ke log!
String _mapAuthException(Object error) {
  final str = error.toString();

  if (kDebugMode) {
    debugPrint('[StoryLoka Supabase Auth Error] $error');
  }

  if (error is PostgrestException) {
    final msg = error.message.toUpperCase();
    if (msg.contains('EMAIL_TAKEN')) {
      return 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
    }
    if (msg.contains('INVALID_CREDENTIALS')) {
      return 'Email atau kata sandi salah.';
    }
    if (msg.contains('SESSION_INVALID')) {
      return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
    }
    if (msg.contains('NAME_REQUIRED')) {
      return 'Nama lengkap wajib diisi.';
    }
    if (msg.contains('EMAIL_INVALID')) {
      return 'Format email tidak valid.';
    }
    if (msg.contains('PASSWORD_TOO_SHORT')) {
      return 'Kata sandi minimal 8 karakter.';
    }
  }

  if (str.contains('EMAIL_TAKEN')) {
    return 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
  }
  if (str.contains('INVALID_CREDENTIALS')) {
    return 'Email atau kata sandi salah.';
  }
  if (str.contains('SESSION_INVALID')) {
    return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
  }
  if (str.contains('SocketException') ||
      str.contains('Failed host lookup') ||
      str.contains('Network') ||
      str.contains('HandshakeException') ||
      str.contains('TlsException') ||
      str.contains('Connection terminated') ||
      str.contains('Connection closed') ||
      str.contains('ClientException')) {
    return 'Koneksi internet HP ke Supabase terputus (HandshakeException). Coba ganti ke paket data seluler atau aktifkan Private DNS (dns.google) di HP.';
  }
  if (str.toLowerCase().contains('does not exist') ||
      str.toLowerCase().contains('schema cache') ||
      str.toLowerCase().contains('not found')) {
    return 'Skema database belum siap. Jalankan file supabase/schema.sql di SQL Editor Supabase.';
  }

  return 'Terjadi kesalahan pada layanan. Silakan coba beberapa saat lagi.';
}

// ═══════════════════════════════════════════════════
// Supabase Auth Repository — PRD §7.1, §8.2, Lampiran A
// Aturan keras: TANPA Firebase, TANPA supabase.auth
// ═══════════════════════════════════════════════════

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? _customClient;
  final SecureSessionStore sessionStore;

  SupabaseAuthRepository({
    SupabaseClient? client,
    required this.sessionStore,
  }) : _customClient = client;

  SupabaseClient get client => _customClient ?? Supabase.instance.client;

  @override
  Future<AppUser> register(String name, String email, String password) async {
    try {
      final res = await client.rpc(
        'register_user',
        params: {
          'p_name': name.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_password': password,
        },
      );

      final data = Map<String, dynamic>.from(res as Map);
      final token = data['token'] as String;
      final userMap = Map<String, dynamic>.from(data['user'] as Map);
      final user = AppUser.fromJson(userMap);

      // Simpan session aman (token dan user profil)
      await sessionStore.saveSession(token: token, user: user, mode: 'real');
      return user;
    } catch (e) {
      throw Exception(_mapAuthException(e));
    }
  }

  @override
  Future<AppUser> login(String email, String password) async {
    try {
      final res = await client.rpc(
        'login_user',
        params: {
          'p_email': email.trim().toLowerCase(),
          'p_password': password,
        },
      );

      final data = Map<String, dynamic>.from(res as Map);
      final token = data['token'] as String;
      final userMap = Map<String, dynamic>.from(data['user'] as Map);
      final user = AppUser.fromJson(userMap);

      // Simpan session aman
      await sessionStore.saveSession(token: token, user: user, mode: 'real');
      return user;
    } catch (e) {
      throw Exception(_mapAuthException(e));
    }
  }

  @override
  Future<AppUser?> validateSession() async {
    try {
      final token = await sessionStore.getToken();
      if (token == null || token.isEmpty) return null;

      final res = await client.rpc(
        'validate_session',
        params: {'p_token': token},
      );

      final userMap = Map<String, dynamic>.from(res as Map);
      final user = AppUser.fromJson(userMap);
      await sessionStore.saveUser(user);
      return user;
    } catch (e) {
      // Jika token invalid di server, bersihkan session lokal
      await sessionStore.clearSession();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      final token = await sessionStore.getToken();
      if (token != null && token.isNotEmpty) {
        // Hapus token session di server Supabase
        await client.rpc('logout_session', params: {'p_token': token});
      }
    } catch (_) {
      // Abaikan kegagalan jaringan saat logout agar pengguna tetap bisa keluar secara lokal
    } finally {
      await sessionStore.clearSession();
    }
  }

  @override
  Future<bool> hasSession() async {
    return await sessionStore.hasSession();
  }
}

// ═══════════════════════════════════════════════════
// Supabase Profile Repository — PRD §7.8, §8.2, Lampiran A
// ═══════════════════════════════════════════════════

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient? _customClient;
  final SecureSessionStore sessionStore;

  SupabaseProfileRepository({
    SupabaseClient? client,
    required this.sessionStore,
  }) : _customClient = client;

  SupabaseClient get client => _customClient ?? Supabase.instance.client;

  @override
  Future<AppUser> getProfile() async {
    final cached = await sessionStore.getUser();
    final token = await sessionStore.getToken();

    if (token == null || token.isEmpty) {
      if (cached != null) return cached;
      throw Exception('Sesi tidak ditemukan.');
    }

    try {
      final res = await client.rpc(
        'validate_session',
        params: {'p_token': token},
      );
      final userMap = Map<String, dynamic>.from(res as Map);
      final user = AppUser.fromJson(userMap);
      await sessionStore.saveUser(user);
      return user;
    } catch (e) {
      if (cached != null) return cached;
      throw Exception(_mapAuthException(e));
    }
  }

  @override
  Future<AppUser> updateProfile({
    required String name,
    String? bio,
    String? avatarPath,
  }) async {
    final token = await sessionStore.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi tidak ditemukan.');
    }

    String? publicAvatarUrl = avatarPath;

    // Unggah file avatar ke Supabase Storage bucket 'avatars' jika berupa file lokal
    if (avatarPath != null && !avatarPath.startsWith('http')) {
      try {
        final file = File(avatarPath);
        if (await file.exists()) {
          final user = await sessionStore.getUser();
          final userId = user?.id ?? 'user';
          final storagePath = '$userId/avatar.jpg';
          final bytes = await file.readAsBytes();

          await client.storage.from('avatars').uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );

          publicAvatarUrl = client.storage.from('avatars').getPublicUrl(storagePath);
        }
      } catch (_) {
        // Fallback: gunakan path lokal jika penyimpanan remote belum bisa dijangkau
        publicAvatarUrl = avatarPath;
      }
    }

    try {
      final res = await client.rpc(
        'update_profile',
        params: {
          'p_token': token,
          'p_name': name.trim(),
          'p_bio': bio,
          'p_avatar_url': publicAvatarUrl,
        },
      );

      final userMap = Map<String, dynamic>.from(res as Map);
      final user = AppUser.fromJson(userMap);
      await sessionStore.saveUser(user);
      return user;
    } catch (e) {
      throw Exception(_mapAuthException(e));
    }
  }
}
