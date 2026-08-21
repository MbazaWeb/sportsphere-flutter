import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/profile/Profile/player/player_profile_view.dart';
import '../../features/profile/Profile/team/team_profile_view.dart';
import '../../features/admin/admin_dashboard.dart';
import '../../features/profile/presentation/profile_loader.dart';
import '../../features/profile/templates/role_profile_shell.dart';
import '../../features/shell/app_shell.dart';
import '../../splash_screen.dart';

class SportSphereApp extends ConsumerWidget {
  const SportSphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SportSphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020A14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF009DFF),
          surface: Color(0xFF0B1628),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

// ============================================================
// CONSTANTS - Route paths (Single source of truth)
// ============================================================

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile/:handle';
  static const String team = '/team/:handle';
  static const String player = '/player/:handle';
  static const String roleProfile = '/role/:role/:handle';

  // Protected routes requiring authentication
  static const Set<String> protected = {
    '/create',
    '/profile',
    '/team',
    '/player',
  };
}

// ============================================================
// TRANSITION HELPERS
// ============================================================

class RouteTransitions {
  const RouteTransitions._();

  static const Duration duration = Duration(milliseconds: 350);

  static CustomTransitionPage<void> fade(LocalKey key, Widget child) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  static CustomTransitionPage<void> slideUp(LocalKey key, Widget child) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  static CustomTransitionPage<void> slideRight(LocalKey key, Widget child) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

// ============================================================
// ROUTER PROVIDER
// ============================================================

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (_, state) => _redirectLogic(ref, state),
    routes: [
      // ─── PUBLIC ROUTES ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, state) => const NoTransitionPage(
          key: ValueKey('splash'),
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) =>
            RouteTransitions.fade(state.pageKey, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (_, state) =>
            RouteTransitions.slideRight(state.pageKey, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (_, state) => const NoTransitionPage(
          key: ValueKey('home'),
          child: SportSphereShell(),
        ),
      ),

      // ─── PROTECTED ROUTES ──────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return RouteTransitions.slideUp(
            state.pageKey,
            FutureBuilder(
              future: ProfileLoader.loadFanProfile(handle),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return FanProfileView(profile: snap.data!);
              },
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.player,
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return RouteTransitions.slideUp(
            state.pageKey,
            FutureBuilder(
              future: ProfileLoader.loadPlayerProfile(handle),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return PlayerProfileView(profile: snap.data!);
              },
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.team,
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return RouteTransitions.slideUp(
            state.pageKey,
            FutureBuilder(
              future: ProfileLoader.loadTeamProfile(handle),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return TeamProfileView(profile: snap.data!);
              },
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.roleProfile,
        pageBuilder: (_, state) {
          final role = state.pathParameters['role'] ?? 'fan';
          final handle = state.pathParameters['handle'] ?? role;
          return RouteTransitions.slideUp(
            state.pageKey,
            FutureBuilder(
              future: ProfileLoader.loadRoleProfile(role, handle),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return RoleProfileShell(profile: snap.data!);
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AdminDashboard(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
    ],
  );
});

// ============================================================
// REDIRECT LOGIC
// ============================================================

String? _redirectLogic(Ref ref, GoRouterState state) {
  final auth = ref.read(authControllerProvider);
  final location = state.uri.toString();

  // Still hydrating — hold on splash only, don't redirect other routes
  if (auth.status == AuthStatus.unknown) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  // Auth resolved — redirect away from splash
  if (location == AppRoutes.splash) {
    return auth.isAuthenticated ? AppRoutes.home : AppRoutes.login;
  }

  // Check if current route requires authentication
  final isProtected = AppRoutes.protected.any(location.startsWith);

  // Redirect unauthenticated users away from protected routes
  if (isProtected && !auth.isAuthenticated) {
    return AppRoutes.login;
  }

  // Redirect authenticated users away from auth pages
  if ((location == AppRoutes.login || location == AppRoutes.register) &&
      auth.isAuthenticated) {
    return AppRoutes.home;
  }

  return null;
}

// ============================================================
// AUTH LISTENABLE
// ============================================================

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
