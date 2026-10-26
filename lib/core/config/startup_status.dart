import 'package:flutter/foundation.dart';

/// Status inisialisasi startup aplikasi (hasil Supabase.initialize) — PRD §3 & Fase R1.
class StartupStatus extends ChangeNotifier {
  StartupStatus._();
  static final StartupStatus instance = StartupStatus._();

  bool _supabaseInitialized = false;
  bool _supabaseFailed = false;
  String? _supabaseErrorMessage;

  bool get isSupabaseInitialized => _supabaseInitialized;
  bool get isSupabaseFailed => _supabaseFailed;
  String? get supabaseErrorMessage => _supabaseErrorMessage;

  String get statusText {
    if (_supabaseInitialized) return 'SUCCESS';
    if (_supabaseFailed) return 'FAILED ($_supabaseErrorMessage)';
    return 'NOT_INITIALIZED';
  }

  void recordSupabaseSuccess() {
    _supabaseInitialized = true;
    _supabaseFailed = false;
    _supabaseErrorMessage = null;
    notifyListeners();
  }

  void recordSupabaseError(String error) {
    _supabaseInitialized = false;
    _supabaseFailed = true;
    _supabaseErrorMessage = error;
    notifyListeners();
  }

  void reset() {
    _supabaseInitialized = false;
    _supabaseFailed = false;
    _supabaseErrorMessage = null;
    notifyListeners();
  }
}
