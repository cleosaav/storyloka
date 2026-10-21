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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

    // Jika mode backend aktif tetapi kredensial .env kosong, tampilkan ConfigErrorPage
    if (!isFakeMode && !AppConfig.useFakeData && !Env.isSupabaseConfigured) {
      return MaterialApp(
        title: 'StoryLoka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.themeMode,
        home: ConfigErrorPage(
          onRetry: () async {
            await Env.load();
            setState(() {});
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
