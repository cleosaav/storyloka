import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/services/ledger_service.dart';
import '../core/services/secure_session_store.dart';
import '../core/services/sync_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/book_search_repository.dart';
import '../data/repositories/bookstore_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/currency_repository.dart';
import '../data/repositories/feedback_repository.dart';
import '../data/repositories/ledger_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/reading_repository.dart';
import '../data/repositories/remote/exchange_rate_repository.dart';
import '../data/repositories/remote/gemini_chat_repository.dart';
import '../data/repositories/remote/deepseek_chat_repository.dart';
import '../data/repositories/remote/fallback_chat_repository.dart';
import '../data/repositories/remote/overpass_bookstore_repository.dart';
import '../data/repositories/remote/composite_book_search_repository.dart';
import '../data/repositories/score_repository.dart';
import '../features/auth/auth_controller.dart';
import '../core/config/env.dart';
import '../core/services/biometric_service.dart';
import '../core/services/light_sensor_service.dart';
import '../data/database_helper.dart';
import '../data/repositories/local/local_repositories.dart';
import '../data/repositories/supabase/supabase_repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Konfigurasi global aplikasi
class AppConfig {
  AppConfig._();
  static bool useFakeData = false;
}

/// Pengontrol tema dinamis (Light / Dark / System/Auto) — PRD §4.7, §8.1 & §10.4.
class ThemeController extends ChangeNotifier {
  static const String prefKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode? _sensorResolvedMode;
  SharedPreferences? _prefs;

  ThemeMode get themeMode {
    if (_themeMode == ThemeMode.system && _sensorResolvedMode != null) {
      return _sensorResolvedMode!;
    }
    return _themeMode;
  }

  /// Pengaturan preferensi yang dipilih pengguna di UI (Light / Dark / Auto).
  ThemeMode get userPreferenceMode => _themeMode;

  bool get isDark => themeMode == ThemeMode.dark;
  bool get isAuto => _themeMode == ThemeMode.system;

  ThemeController({
    ThemeMode initialMode = ThemeMode.light,
    SharedPreferences? prefs,
  }) : _themeMode = initialMode {
    _prefs = prefs;
    if (_themeMode == ThemeMode.system) {
      _startSensorListening();
    }
  }

  /// Muat preferensi tema dari SharedPreferences saat startup sebelum runApp — PRD §8.1.
  static Future<ThemeController> create({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(prefKey);
    final mode = parseThemeMode(raw);
    return ThemeController(initialMode: mode, prefs: p);
  }

  static ThemeMode parseThemeMode(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'auto':
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static String serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'auto';
      case ThemeMode.light:
        return 'light';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    if (_themeMode == ThemeMode.system) {
      _stopSensorListening();
    }

    _themeMode = mode;
    _sensorResolvedMode = null;

    if (_themeMode == ThemeMode.system) {
      _startSensorListening();
    }

    notifyListeners();
    await _saveToPrefs(mode);
  }

  void _stopSensorListening() {
    LightSensorService.instance.stopListening();
  }

  void _startSensorListening() {
    LightSensorService.instance.startListening(
      onThemeChanged: (resolved) {
        _sensorResolvedMode = resolved;
        notifyListeners();
      },
    );
  }

  Future<void> _saveToPrefs(ThemeMode mode) async {
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setString(prefKey, serializeThemeMode(mode));
    } catch (_) {}
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}

/// Factory tunggal untuk mendaftarkan semua provider aplikasi versi rilis — PRD §13.0.
List<SingleChildWidget> buildAppProviders({
  DatabaseHelper? dbHelper,
  AuthRepository? authRepo,
  ProfileRepository? profileRepo,
  BookSearchRepository? bookSearchRepo,
  BiometricService? biometricService,
  SupabaseClient? supabaseClient,
  ThemeController? themeController,
  bool? useFakeData,
}) {
  final tController = themeController ?? ThemeController();
  final sessionStore = SecureSessionStore();
  final bioService = biometricService ?? BiometricService();

  final helper = dbHelper ?? DatabaseHelper.instance;
  final localLibrary = LocalLibraryRepository(
    dbHelper: helper,
    sessionStore: sessionStore,
  );
  final localReading = LocalReadingRepository(
    dbHelper: helper,
    sessionStore: sessionStore,
  );
  final localLedger = LocalLedgerRepository(
    dbHelper: helper,
    sessionStore: sessionStore,
  );
  final ledgerService = LedgerService(localLedger);
  final teamFeedback = const TeamFeedbackRepository();
  final localScore = LocalScoreRepository(
    dbHelper: helper,
    sessionStore: sessionStore,
  );

  final realAuth = authRepo ??
      SupabaseAuthRepository(
        client: supabaseClient,
        sessionStore: sessionStore,
      );
  final realProfile = profileRepo ??
      SupabaseProfileRepository(
        client: supabaseClient,
        sessionStore: sessionStore,
      );

  final searchRepo = bookSearchRepo ?? CompositeBookSearchRepository();
  final currencyRepo = OpenExchangeRateRepository();

  Future<String> userIdProvider() async {
    final user = await sessionStore.getUser();
    if (user != null && user.id.isNotEmpty && isValidUuid(user.id)) {
      return user.id;
    }
    throw StateError('NO_AUTHENTICATED_USER: Sesi pengguna tidak ditemukan.');
  }

  final geminiFallbacks = Env.geminiModelFallbacks;
  final chainProviders = <ChatRepository>[
    DeepSeekChatRepository(
      dbHelper: helper,
      userIdProvider: userIdProvider,
    ),
    GeminiChatRepository(
      dbHelper: helper,
      userIdProvider: userIdProvider,
      model: Env.geminiModel,
    ),
    for (final fbModel in geminiFallbacks)
      GeminiChatRepository(
        dbHelper: helper,
        userIdProvider: userIdProvider,
        model: fbModel,
      ),
  ];
  final chatRepo = FallbackChatRepository.chain(
    providers: chainProviders,
  );

  final authController = AuthController(
    authRepository: realAuth,
    sessionStore: sessionStore,
    ledgerService: ledgerService,
  );

  return [
    Provider<SecureSessionStore>.value(value: sessionStore),
    Provider<BiometricService>.value(value: bioService),
    ChangeNotifierProvider<ThemeController>.value(value: tController),
    ChangeNotifierProvider<AuthController>.value(value: authController),
    Provider<DatabaseHelper>.value(value: helper),
    Provider<AuthRepository>.value(value: realAuth),
    Provider<ProfileRepository>.value(value: realProfile),
    Provider<BookSearchRepository>.value(value: searchRepo),
    Provider<LibraryRepository>.value(value: localLibrary),
    Provider<ReadingRepository>.value(value: localReading),
    Provider<LedgerRepository>.value(value: localLedger),
    Provider<LedgerService>.value(value: ledgerService),
    Provider<FeedbackRepository>.value(value: teamFeedback),
    Provider<ScoreRepository>.value(value: localScore),
    Provider<ChatRepository>.value(value: chatRepo),
    Provider<CurrencyRepository>.value(value: currencyRepo),
    Provider<BookstoreRepository>.value(value: OverpassBookstoreRepository()),
    ChangeNotifierProvider<SyncService>.value(value: SyncService.instance),
  ];
}
