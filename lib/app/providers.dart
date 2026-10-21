import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/services/ledger_service.dart';
import '../core/services/secure_session_store.dart';
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
import '../data/repositories/score_repository.dart';
import '../features/auth/auth_controller.dart';
import '../data/database_helper.dart';
import '../data/repositories/local/local_repositories.dart';

/// Konfigurasi aplikasi — PRD §13.0 aturan 3.
class AppConfig {
  AppConfig._();

  /// Flag penentu implementasi repository: Fake vs Nyata (SQLite/Supabase).
  /// Default true selama Tahap A; diubah menjadi false pada Fase B7.
  static const bool useFakeData =
      bool.fromEnvironment('USE_FAKE', defaultValue: true);
}

/// Pengontrol tema dinamis (Light / Dark / System/Auto) — PRD §4.7.
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isAuto => _themeMode == ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
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
}) {
  // Demo controls untuk kDebugMode
  final demoControls = DemoControls();
  final themeController = ThemeController();
  final sessionStore = SecureSessionStore();
  final isFake = useFakeData ?? AppConfig.useFakeData;

  if (isFake) {
    final fakeAuth = FakeAuthRepository(sessionStore: sessionStore);
    final fakeProfile = FakeProfileRepository(fakeAuth);
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
    ];
  } else {
    // Fase B1: Implementasi lokal SQLite nyata
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
    final localChat = LocalChatRepository(
      dbHelper: helper,
      sessionStore: sessionStore,
    );

    // Repository yang baru diimplementasikan di fase berikutnya (B2, B3, B5)
    final authRepo = FakeAuthRepository(sessionStore: sessionStore);
    final profileRepo = FakeProfileRepository(authRepo);
    final searchRepo = FakeBookSearchRepository(demoControls: demoControls);
    final currencyRepo = FakeCurrencyRepository(demoControls: demoControls);

    final authController = AuthController(
      authRepository: authRepo,
      sessionStore: sessionStore,
      demoControls: demoControls,
    );

    return [
      Provider<SecureSessionStore>.value(value: sessionStore),
      ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ChangeNotifierProvider<DemoControls>.value(value: demoControls),
      ChangeNotifierProvider<AuthController>.value(value: authController),
      Provider<DatabaseHelper>.value(value: helper),
      Provider<AuthRepository>.value(value: authRepo),
      Provider<ProfileRepository>.value(value: profileRepo),
      Provider<BookSearchRepository>.value(value: searchRepo),
      Provider<LibraryRepository>.value(value: localLibrary),
      Provider<ReadingRepository>.value(value: localReading),
      Provider<LedgerRepository>.value(value: localLedger),
      Provider<LedgerService>.value(value: LedgerService(localLedger)),
      Provider<FeedbackRepository>.value(value: localFeedback),
      Provider<ScoreRepository>.value(value: localScore),
      Provider<ChatRepository>.value(value: localChat),
      Provider<CurrencyRepository>.value(value: currencyRepo),
    ];
  }
}
