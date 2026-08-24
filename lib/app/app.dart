import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/profile/Profile/player/player_profile_view.dart';
import '../../features/profile/Profile/team/team_profile_view.dart';
import '../../features/admin/admin_dashboard.dart';
import '../../features/profile/presentation/profile_loader.dart';
import '../../features/profile/templates/role_profile_model.dart';
import '../../features/profile/templates/role_profile_shell.dart';
import '../../features/shell/app_shell.dart';
import '../../splash_screen.dart';

class SportSphereApp extends ConsumerWidget {
  const SportSphereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Playify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020A14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF009DFF),
          surface: Color(0xFF0B1628),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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

  // Protected routes requiring authentication.
  // Profiles (/profile, /team, /player, /role) are PUBLIC — guests can view.
  // Only actions inside those pages (follow, fan, comment) check auth individually.
  static const Set<String> protected = {
    '/create',
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
      // H4 — The previous implementation created a FutureBuilder inline
      // inside each pageBuilder, which re-invoked `ProfileLoader.load*Profile`
      // on every GoRouter rebuild (e.g. on auth state changes). Each rebuild
      // started a fresh fetch and wiped the existing snapshot. We now wrap
      // each future-driven page in a StatefulWidget that caches the Future
      // in `initState` so the FutureBuilder only subscribes once per route
      // instance. See `_FanProfilePage`, `_PlayerProfilePage`,
      // `_TeamProfilePage`, `_RoleProfilePage` below.
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return RouteTransitions.slideUp(
            state.pageKey,
            _FanProfilePage(handle: handle),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.player,
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return RouteTransitions.slideUp(
            state.pageKey,
            _PlayerProfilePage(handle: handle),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.team,
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return RouteTransitions.slideUp(
            state.pageKey,
            _TeamProfilePage(handle: handle),
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
            _RoleProfilePage(role: role, handle: handle),
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

  // Splash controls its own exit — never redirect away from it.
  // It will call context.go('/home') when the animation finishes,
  // and the router will then redirect to login if guest.
  if (location == AppRoutes.splash) return null;

  // Still hydrating — send non-splash routes to splash
  if (auth.status == AuthStatus.unknown) {
    return AppRoutes.splash;
  }

  // Check if current route requires authentication
  final isProtected = AppRoutes.protected.any(location.startsWith);
  if (isProtected && !auth.isAuthenticated) return AppRoutes.login;

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

// ============================================================
// PROFILE PAGE WRAPPERS (H4)
// ─────────────────────────────────────────────────────────────
// Each wrapper caches the loader Future in `initState` so the
// FutureBuilder only subscribes once per route instance — even
// when the GoRouter pageBuilder fires again on auth refreshes.
// ============================================================

class _FanProfilePage extends StatefulWidget {
  final String handle;
  const _FanProfilePage({required this.handle});
  @override
  State<_FanProfilePage> createState() => _FanProfilePageState();
}

class _FanProfilePageState extends State<_FanProfilePage> {
  late final Future<FanProfileModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileLoader.loadFanProfile(widget.handle);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FanProfileModel>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return FanProfileView(profile: snap.data!);
      },
    );
  }
}

class _PlayerProfilePage extends StatefulWidget {
  final String handle;
  const _PlayerProfilePage({required this.handle});
  @override
  State<_PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<_PlayerProfilePage> {
  late final Future<PlayerProfileModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileLoader.loadPlayerProfile(widget.handle);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerProfileModel>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return PlayerProfileView(profile: snap.data!);
      },
    );
  }
}

class _TeamProfilePage extends StatefulWidget {
  final String handle;
  const _TeamProfilePage({required this.handle});
  @override
  State<_TeamProfilePage> createState() => _TeamProfilePageState();
}

class _TeamProfilePageState extends State<_TeamProfilePage> {
  late final Future<TeamProfileModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileLoader.loadTeamProfile(widget.handle);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeamProfileModel>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return TeamProfileView(profile: snap.data!);
      },
    );
  }
}

class _RoleProfilePage extends StatefulWidget {
  final String role;
  final String handle;
  const _RoleProfilePage({required this.role, required this.handle});
  @override
  State<_RoleProfilePage> createState() => _RoleProfilePageState();
}

class _RoleProfilePageState extends State<_RoleProfilePage> {
  late final Future<RoleProfileModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileLoader.loadRoleProfile(widget.role, widget.handle);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoleProfileModel>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return RoleProfileShell(profile: snap.data!);
      },
    );
  }
}
