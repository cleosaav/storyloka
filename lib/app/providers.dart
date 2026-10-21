import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/services/ledger_service.dart';
import '../core/services/secure_session_store.dart';
import '../core/services/sync_service.dart';
import '../core/widgets/demo_widgets.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/book_search_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/currency_repository.dart';
import '../data/repositories/fake/fake_repositories.dart';
import '../data/repositories/feedback_repository.dart';
import '../data/repositories/ledger_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/reading_repository.dart';
import '../data/repositories/remote/exchange_rate_repository.dart';
import '../data/repositories/remote/gemini_chat_repository.dart';
import '../data/repositories/remote/google_books_repository.dart';
import '../data/repositories/score_repository.dart';
import '../features/auth/auth_controller.dart';
import '../core/config/env.dart';
import '../core/services/biometric_service.dart';
import '../core/services/light_sensor_service.dart';
import '../data/database_helper.dart';
import '../data/repositories/local/local_repositories.dart';
import '../data/repositories/supabase/supabase_repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Konfigurasi aplikasi — PRD §13.0 aturan 3.
class AppConfig {
  AppConfig._();

  /// Flag penentu implementasi repository: Fake vs Nyata (SQLite/Supabase).
  /// Default true selama Tahap A; diubah menjadi false pada Fase B7.
  static const bool useFakeData =
      bool.fromEnvironment('USE_FAKE', defaultValue: false);
}

/// Pengontrol tema dinamis (Light / Dark / System/Auto) — PRD §4.7 & §10.4.
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode? _sensorResolvedMode;

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

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _sensorResolvedMode = null;
      if (mode == ThemeMode.system) {
        LightSensorService.instance.startListening(
          onThemeChanged: (resolved) {
            _sensorResolvedMode = resolved;
            notifyListeners();
          },
        );
      } else {
        LightSensorService.instance.stopListening();
      }
      notifyListeners();
    }
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}

/// Factory tunggal untuk mendaftarkan semua provider aplikasi — PRD §13.0 aturan 3.
List<SingleChildWidget> buildAppProviders({
  bool? useFakeData,
  DatabaseHelper? dbHelper,
  AuthRepository? authRepo,
  ProfileRepository? profileRepo,
  BiometricService? biometricService,
  SupabaseClient? supabaseClient,
}) {
  // Demo controls untuk kDebugMode
  final demoControls = DemoControls();
  final themeController = ThemeController();
  final sessionStore = SecureSessionStore();
  final bioService = biometricService ?? BiometricService();
  final isFake = useFakeData ?? AppConfig.useFakeData;

  if (isFake) {
    final fakeAuth = authRepo ?? FakeAuthRepository(sessionStore: sessionStore);
    final fakeProfile = profileRepo ??
        FakeProfileRepository(
          fakeAuth is FakeAuthRepository
              ? fakeAuth
              : FakeAuthRepository(sessionStore: sessionStore),
        );
    final fakeSearch = FakeBookSearchRepository(demoControls: demoControls);
    final fakeLibrary = FakeLibraryRepository(demoControls: demoControls);
    final fakeReading = FakeReadingRepository(demoControls: demoControls);
    final fakeLedger = FakeLedgerRepository(demoControls: demoControls);
    final fakeFeedback = FakeFeedbackRepository(demoControls: demoControls);
    final fakeScore = FakeScoreRepository(demoControls: demoControls);
    final fakeChat = FakeChatRepository(demoControls: demoControls);
    final fakeCurrency = FakeCurrencyRepository(demoControls: demoControls);

    final authController = AuthController(
      authRepository: fakeAuth,
      sessionStore: sessionStore,
      demoControls: demoControls,
    );

    return [
      Provider<SecureSessionStore>.value(value: sessionStore),
      Provider<BiometricService>.value(value: bioService),
      ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ChangeNotifierProvider<DemoControls>.value(value: demoControls),
      ChangeNotifierProvider<AuthController>.value(value: authController),
      Provider<AuthRepository>.value(value: fakeAuth),
      Provider<ProfileRepository>.value(value: fakeProfile),
      Provider<BookSearchRepository>.value(value: fakeSearch),
      Provider<LibraryRepository>.value(value: fakeLibrary),
      Provider<ReadingRepository>.value(value: fakeReading),
      Provider<LedgerRepository>.value(value: fakeLedger),
      Provider<LedgerService>.value(value: LedgerService(fakeLedger)),
      Provider<FeedbackRepository>.value(value: fakeFeedback),
      Provider<ScoreRepository>.value(value: fakeScore),
      Provider<ChatRepository>.value(value: fakeChat),
      Provider<CurrencyRepository>.value(value: fakeCurrency),
      ChangeNotifierProvider<SyncService>.value(value: SyncService.instance),
    ];
  } else {
    // Fase B1 & B2: Implementasi nyata (SQLite + Supabase + Biometrik)
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
    final localFeedback = LocalFeedbackRepository(
      dbHelper: helper,
      sessionStore: sessionStore,
    );
    final localScore = LocalScoreRepository(
      dbHelper: helper,
      sessionStore: sessionStore,
    );

    // Fase B2: Supabase Auth & Profile Repository nyata
    final realAuth = authRepo ??
        (Env.isSupabaseConfigured
            ? SupabaseAuthRepository(
                client: supabaseClient,
                sessionStore: sessionStore,
              )
            : FakeAuthRepository(sessionStore: sessionStore));
    final realProfile = profileRepo ??
        (Env.isSupabaseConfigured
            ? SupabaseProfileRepository(
                client: supabaseClient,
                sessionStore: sessionStore,
              )
            : FakeProfileRepository(
                realAuth is FakeAuthRepository
                    ? realAuth
                    : FakeAuthRepository(sessionStore: sessionStore),
              ));

    // Fase B3: Google Books API nyata sebagai BookSearchRepository
    final searchRepo = GoogleBooksRepository();
    // Fase B5: Kurs nyata (open.er-api.com) & Gemini AI nyata
    final currencyRepo = OpenExchangeRateRepository();
    final chatRepo = GeminiChatRepository(
      dbHelper: helper,
      userIdProvider: () async =>
          (await sessionStore.getUser())?.id ?? 'default_user',
    );

    final authController = AuthController(
      authRepository: realAuth,
      sessionStore: sessionStore,
      demoControls: demoControls,
    );

    return [
      Provider<SecureSessionStore>.value(value: sessionStore),
      Provider<BiometricService>.value(value: bioService),
      ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ChangeNotifierProvider<DemoControls>.value(value: demoControls),
      ChangeNotifierProvider<AuthController>.value(value: authController),
      Provider<DatabaseHelper>.value(value: helper),
      Provider<AuthRepository>.value(value: realAuth),
      Provider<ProfileRepository>.value(value: realProfile),
      Provider<BookSearchRepository>.value(value: searchRepo),
      Provider<LibraryRepository>.value(value: localLibrary),
      Provider<ReadingRepository>.value(value: localReading),
      Provider<LedgerRepository>.value(value: localLedger),
      Provider<LedgerService>.value(value: LedgerService(localLedger)),
      Provider<FeedbackRepository>.value(value: localFeedback),
      Provider<ScoreRepository>.value(value: localScore),
      Provider<ChatRepository>.value(value: chatRepo),
      Provider<CurrencyRepository>.value(value: currencyRepo),
      ChangeNotifierProvider<SyncService>.value(value: SyncService.instance),
    ];
  }
}
