import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/services/ledger_service.dart';
import '../core/services/secure_session_store.dart';
import '../core/services/sync_service.dart';
import '../core/widgets/demo_widgets.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/book_search_repository.dart';
import '../data/repositories/bookstore_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/currency_repository.dart';
import '../data/repositories/fake/fake_bookstore_repository.dart';
import '../data/repositories/fake/fake_repositories.dart';
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
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/startup_status.dart';

/// Konfigurasi aplikasi — PRD §13.0 aturan 3.
class AppConfig {
  AppConfig._();

  static bool? _overrideUseFakeData;

  /// Flag penentu implementasi repository: Fake vs Nyata (SQLite/Supabase).
  /// Default true selama Tahap A; diubah menjadi false pada Fase B7.
  static bool get useFakeData =>
      _overrideUseFakeData ??
      const bool.fromEnvironment('USE_FAKE', defaultValue: false);

  static set useFakeData(bool value) {
    _overrideUseFakeData = value;
  }

  static void resetForTesting() {
    _overrideUseFakeData = null;
  }
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
  BookSearchRepository? bookSearchRepo,
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
    final fakeSearch = bookSearchRepo ?? FakeBookSearchRepository(demoControls: demoControls);
    final fakeLibrary = FakeLibraryRepository(demoControls: demoControls);
    final fakeReading = FakeReadingRepository(demoControls: demoControls);
    final fakeLedger = FakeLedgerRepository(demoControls: demoControls);
    final ledgerService = LedgerService(fakeLedger);
    final fakeFeedback = const TeamFeedbackRepository();
    final fakeScore = FakeScoreRepository(demoControls: demoControls);
    final fakeChat = FakeChatRepository(demoControls: demoControls);
    final fakeCurrency = FakeCurrencyRepository(demoControls: demoControls);

    final authController = AuthController(
      authRepository: fakeAuth,
      sessionStore: sessionStore,
      demoControls: demoControls,
      ledgerService: ledgerService,
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
      Provider<LedgerService>.value(value: ledgerService),
      Provider<FeedbackRepository>.value(value: fakeFeedback),
      Provider<ScoreRepository>.value(value: fakeScore),
      Provider<ChatRepository>.value(value: fakeChat),
      Provider<CurrencyRepository>.value(value: fakeCurrency),
      Provider<BookstoreRepository>.value(value: FakeBookstoreRepository()),
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
    final ledgerService = LedgerService(localLedger);
    final teamFeedback = const TeamFeedbackRepository();
    final localScore = LocalScoreRepository(
      dbHelper: helper,
      sessionStore: sessionStore,
    );

    // Fase B2 & R1: Supabase Auth & Profile Repository NYATA (tanpa fallback diam-diam ke Fake!)
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

    // Fase B3 & R2: Pencarian buku hibrida (Google Books + Open Library)
    final searchRepo = bookSearchRepo ?? CompositeBookSearchRepository();
    // Fase B5 & R4: Kurs nyata + AI Chat DeepSeek (primary) → Gemini (fallback)
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
      demoControls: demoControls,
      ledgerService: ledgerService,
    );

    // Log debug (kDebugMode saja) — PRD §3 & Fase R1 (tanpa mencetak nilai kunci!)
    if (kDebugMode) {
      debugPrint('[StoryLoka Startup] useFakeData: ${AppConfig.useFakeData}');
      debugPrint('[StoryLoka Startup] Env.isSupabaseConfigured: ${Env.isSupabaseConfigured}');
      debugPrint('[StoryLoka Startup] Supabase.initialize: ${StartupStatus.instance.statusText}');
      debugPrint('[StoryLoka Startup] AuthRepository: ${realAuth.runtimeType}');
      debugPrint('[StoryLoka Startup] ProfileRepository: ${realProfile.runtimeType}');
      debugPrint('[StoryLoka Startup] BookSearchRepository: ${searchRepo.runtimeType}');
      debugPrint('[StoryLoka Startup] LibraryRepository: ${localLibrary.runtimeType}');
      debugPrint('[StoryLoka Startup] ReadingRepository: ${localReading.runtimeType}');
      debugPrint('[StoryLoka Startup] LedgerRepository: ${localLedger.runtimeType}');
      debugPrint('[StoryLoka Startup] FeedbackRepository: ${teamFeedback.runtimeType}');
      debugPrint('[StoryLoka Startup] ScoreRepository: ${localScore.runtimeType}');
      debugPrint('[StoryLoka Startup] ChatRepository: FallbackChatRepository(primary: DeepSeek, fallback: Gemini)');
      debugPrint('[StoryLoka Startup] CurrencyRepository: ${currencyRepo.runtimeType}');
    }

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
      Provider<LedgerService>.value(value: ledgerService),
      Provider<FeedbackRepository>.value(value: teamFeedback),
      Provider<ScoreRepository>.value(value: localScore),
      Provider<ChatRepository>.value(value: chatRepo),
      Provider<CurrencyRepository>.value(value: currencyRepo),
      Provider<BookstoreRepository>.value(value: OverpassBookstoreRepository()),
      ChangeNotifierProvider<SyncService>.value(value: SyncService.instance),
    ];
  }
}
