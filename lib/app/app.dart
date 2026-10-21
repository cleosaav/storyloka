import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/config_error_page.dart';
import '../features/auth/auth_controller.dart';
import 'providers.dart';
import 'router.dart';

/// Root widget StoryLoka — PRD §5.
class StoryLokaApp extends StatefulWidget {
  const StoryLokaApp({super.key});

  @override
  State<StoryLokaApp> createState() => _StoryLokaAppState();
}

class _StoryLokaAppState extends State<StoryLokaApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = context.read<AuthController>();
    _router ??= createAppRouter(authController);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    // Jika mode backend aktif tetapi kredensial .env kosong, tampilkan ConfigErrorPage
    if (!AppConfig.useFakeData && !Env.isSupabaseConfigured) {
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
