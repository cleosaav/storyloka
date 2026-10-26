import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/env.dart';
import '../core/services/sync_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/config_error_page.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/fake/fake_repositories.dart';
import '../features/auth/auth_controller.dart';
import 'providers.dart';
import 'router.dart';

import '../core/config/startup_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root widget StoryLoka — PRD §5 & §8.3.
class StoryLokaApp extends StatefulWidget {
  const StoryLokaApp({super.key});

  @override
  State<StoryLokaApp> createState() => _StoryLokaAppState();
}

class _StoryLokaAppState extends State<StoryLokaApp> with WidgetsBindingObserver {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    StartupStatus.instance.addListener(_onStartupStatusChanged);
  }

  @override
  void dispose() {
    StartupStatus.instance.removeListener(_onStartupStatusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onStartupStatusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PRD §8.3: Sinkronisasi saat aplikasi resume ke foreground
    if (state == AppLifecycleState.resumed) {
      SyncService.instance.syncOnResume();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = context.read<AuthController>();
    _router ??= createAppRouter(authController);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final authRepo = context.watch<AuthRepository?>();
    final isFakeMode = authRepo is FakeAuthRepository;

    // 1. Jika mode nyata tetapi konfigurasi .env tidak valid -> ConfigErrorPage (Fase R1)
    if (!isFakeMode && !AppConfig.useFakeData && !Env.isConfigValid) {
      return MaterialApp(
        title: 'StoryLoka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.themeMode,
        home: ConfigErrorPage(
          isFileNotFound: Env.isEnvFileNotFound,
          missingVariables: Env.missingVariables,
          onRetry: () async {
            await Env.load();
            if (Env.isSupabaseConfigured && !StartupStatus.instance.isSupabaseInitialized) {
              try {
                await Supabase.initialize(
                  url: Env.supabaseUrl,
                  publishableKey: Env.supabaseAnonKey,
                );
                StartupStatus.instance.recordSupabaseSuccess();
              } catch (e) {
                StartupStatus.instance.recordSupabaseError(e.toString());
              }
            }
            if (mounted) setState(() {});
          },
        ),
      );
    }

    // 2. Jika inisialisasi Supabase gagal -> Layar error dengan tombol Coba Lagi (Fase R1)
    if (!isFakeMode && !AppConfig.useFakeData && StartupStatus.instance.isSupabaseFailed) {
      return MaterialApp(
        title: 'StoryLoka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.themeMode,
        home: ConfigErrorPage(
          errorMessage: 'Gagal menginisialisasi koneksi Supabase:\n${StartupStatus.instance.supabaseErrorMessage}',
          onRetry: () async {
            try {
              await Supabase.initialize(
                url: Env.supabaseUrl,
                publishableKey: Env.supabaseAnonKey,
              );
              StartupStatus.instance.recordSupabaseSuccess();
            } catch (e) {
              StartupStatus.instance.recordSupabaseError(e.toString());
            }
            if (mounted) setState(() {});
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'StoryLoka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeController.themeMode,
      routerConfig: _router ?? appRouter,
    );
  }
}
