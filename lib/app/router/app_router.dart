import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../splash_screen.dart';

// ── Protected routes (require auth) ───────────────────────────────────────────
const _protectedRoutes = {'/create', '/profile'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.uri.toString();

      // Still hydrating — hold on splash
      if (auth.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      // Auth-only screens redirect guests to login
      if (_protectedRoutes.contains(loc) && !auth.isAuthenticated) {
        return '/login';
      }

      // Auth users sent to login/register → go home
      if ((loc == '/login' || loc == '/register') &&
          auth.isAuthenticated) {
        return '/home';
      }

      // Splash done → home
      if (loc == '/splash') return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SportSphereShell(),
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
