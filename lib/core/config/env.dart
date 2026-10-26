import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Satu-satunya titik akses konfigurasi dan secrets dari .env — PRD §3.
class Env {
  Env._();

  static bool _isLoaded = false;
  static bool get isLoaded => _isLoaded;

  static bool _envFileNotFound = false;
  static bool get isEnvFileNotFound => _envFileNotFound;

  /// Inisialisasi dan memuat file .env.
  static Future<void> load({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
      _isLoaded = true;
      _envFileNotFound = false;
    } catch (_) {
      _isLoaded = false;
      _envFileNotFound = true;
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
    _envFileNotFound = false;
  }

  /// Reset state dan cache environment (berguna untuk pengujian).
  static void reset() {
    _isLoaded = false;
    _envFileNotFound = false;
    if (dotenv.isInitialized) {
      dotenv.env.clear();
    }
  }

  static String _safeGet(String key, [String defaultValue = '']) {
    try {
      if (!dotenv.isInitialized) return defaultValue;
      var val = dotenv.maybeGet(key)?.trim() ?? defaultValue;
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1).trim();
      }
      return val;
    } catch (_) {
      return defaultValue;
    }
  }

  static String get supabaseUrl {
    final url = _safeGet('SUPABASE_URL');
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Mendukung alias SUPABASE_ANON_KEY atau SUPABASE_PUBLISHABLE_KEY — PRD §3.
  static String get supabaseAnonKey {
    final anonKey = _safeGet('SUPABASE_ANON_KEY');
    if (anonKey.trim().isNotEmpty) return anonKey;
    return _safeGet('SUPABASE_PUBLISHABLE_KEY');
  }

  static String get geminiApiKey => _safeGet('GEMINI_API_KEY');
  static String get geminiModel => _safeGet('GEMINI_MODEL', 'gemini-3.5-flash-lite');
  static String get googleBooksApiKey => _safeGet('GOOGLE_BOOKS_API_KEY');
  static String get deepseekApiKey => _safeGet('DEEPSEEK_API_KEY');

  /// Daftar nama variabel inti yang masih kosong di file .env (tanpa mencetak nilai).
  static List<String> get missingVariables {
    final missing = <String>[];
    if (supabaseUrl.trim().isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.trim().isEmpty) {
      missing.add('SUPABASE_ANON_KEY / SUPABASE_PUBLISHABLE_KEY');
    }
    return missing;
  }

  /// Cek kelengkapan konfigurasi Supabase (URL dan Anon/Publishable Key).
  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Cek validitas konfigurasi inti.
  static bool get isConfigValid => !_envFileNotFound && isSupabaseConfigured;
}
