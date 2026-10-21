import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Satu-satunya titik akses konfigurasi dan secrets dari .env — PRD §3.
class Env {
  Env._();

  static bool _isLoaded = false;
  static bool get isLoaded => _isLoaded;

  /// Inisialisasi dan memuat file .env.
  static Future<void> load({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
      _isLoaded = true;
    } catch (_) {
      // Abaikan error loading jika file tidak ditemukan / di test runner
      _isLoaded = false;
    }
  }

  /// Override untuk testing / mocking environment.
  static void setMockValues(Map<String, String> values) {
    if (!dotenv.isInitialized) {
      final content = values.entries.map((e) => '${e.key}=${e.value}').join('\n');
      dotenv.loadFromString(envString: content);
    } else {
      dotenv.env.addAll(values);
    }
    _isLoaded = true;
  }

  static String _safeGet(String key, [String defaultValue = '']) {
    try {
      if (!dotenv.isInitialized) return defaultValue;
      return dotenv.maybeGet(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  static String get supabaseUrl => _safeGet('SUPABASE_URL');
  static String get supabaseAnonKey => _safeGet('SUPABASE_ANON_KEY');
  static String get geminiApiKey => _safeGet('GEMINI_API_KEY');
  static String get geminiModel => _safeGet('GEMINI_MODEL', 'gemini-flash-latest');
  static String get googleBooksApiKey => _safeGet('GOOGLE_BOOKS_API_KEY');

  /// Cek kelengkapan konfigurasi Supabase (URL dan Anon Key).
  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Cek validitas konfigurasi inti.
  static bool get isConfigValid => isSupabaseConfigured;
}
