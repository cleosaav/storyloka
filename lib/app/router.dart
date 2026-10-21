import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/book_search_repository.dart';
import '../features/add_book/add_book_page.dart';
import '../features/add_book/scan_page.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/lock_screen_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/splash_page.dart';
import '../features/book_detail/collection_book_detail_page.dart';
import '../features/book_detail/search_book_detail_page.dart';
import '../features/book_detail/wishlist_book_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/reading_ledger_page.dart';
import '../features/reading/finished_book_page.dart';
import '../features/reading/reading_progress_page.dart';
import '../features/reading/reading_timer_page.dart';
import '../features/tools/ai_chat_page.dart';
import '../features/tools/currency_converter_page.dart';
import '../features/tools/feedback_page.dart';
import '../features/tools/snake/snake_page.dart';
import '../features/tools/time_converter_page.dart';
import '../features/tools/tools_page.dart';
import 'main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Factory untuk membuat router dengan redirect guard berbasis AuthController — PRD §6 & §7.1.
GoRouter createAppRouter([AuthController? authController]) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authController,
    redirect: (BuildContext context, GoRouterState state) {
      if (authController == null) return null;

      final isInitialized = authController.isInitialized;
      final isAuthenticated = authController.isAuthenticated;
      final isLocked = authController.isBiometricLocked;

      final matchedPath = state.matchedLocation;
      final isSplash = matchedPath == '/splash';
      final isLogin = matchedPath == '/login';
      final isRegister = matchedPath == '/register';
      final isLock = matchedPath == '/lock';
      final isAuthRoute = isLogin || isRegister;

      // 1. Saat startup, tahan di splash sampai verifikasi session selesai
      if (!isInitialized) {
        return isSplash ? null : '/splash';
      }

      // 2. Jika tidak ada session (belum login)
      if (!isAuthenticated) {
        if (isAuthRoute) return null;
        return '/login';
      }

      // 3. Jika ada session dan biometrik aktif tapi belum lolos kunci
      if (isLocked) {
        return isLock ? null : '/lock';
      }

      // 4. Jika sudah login dan tidak terkunci, jangan biarkan di auth screen
      if (isSplash || isAuthRoute || isLock) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Rute Autentikasi — PRD §6 & §7.1
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreenPage(),
      ),

      // Bottom Navigation Shell (5 cabang)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Cabang 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),

          // Cabang 1: Library
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) {
                  final filter = state.uri.queryParameters['filter'];
                  return LibraryPage(filter: filter);
                },
              ),
            ],
          ),

          // Cabang 2: Add Book
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                builder: (context, state) => const AddBookPage(),
              ),
            ],
          ),

          // Cabang 3: Tools
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tools',
                builder: (context, state) => const ToolsPage(),
              ),
            ],
          ),


          // Cabang 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // Di atas shell (push) — PRD §6, §7.3, §7.4, §7.6
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/scan',
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/book/search',
        builder: (context, state) {
          final book = state.extra as BookSearchResult?;
          if (book == null) {
            return const Scaffold(
              body: Center(child: Text('Data buku tidak ditemukan')),
            );
          }
          return SearchBookDetailPage(book: book);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/book/wishlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WishlistBookDetailPage(id: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/book/collection/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CollectionBookDetailPage(id: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/reading/timer/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReadingTimerPage(id: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/reading/progress/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final durationParam = state.uri.queryParameters['duration'];
          final durationSec =
              durationParam != null ? int.tryParse(durationParam) : null;
          return ReadingProgressPage(
            id: id,
            sessionDurationSeconds: durationSec,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/reading/finished/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FinishedBookPage(id: id);
        },
      ),

      // Tools sub-routes — PRD §7.7
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/tools/feedback',
        builder: (context, state) => const FeedbackPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/tools/ai-chat',
        builder: (context, state) => const AiChatPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/tools/games',
        builder: (context, state) => const SnakePage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/tools/currency',
        builder: (context, state) => const CurrencyConverterPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/tools/time',
        builder: (context, state) => const TimeConverterPage(),
      ),

      // Profile sub-routes — PRD §7.8
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/profile/edit',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/profile/ledger',
        builder: (context, state) => const ReadingLedgerPage(),
      ),
    ],
  );
}

/// Router default (dapat dipakai untuk smoke test / direct access)
final GoRouter appRouter = createAppRouter();
