import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/shell/app_shell.dart';
import '../../splash_screen.dart';

// Routes that require authentication
const _protectedRoutes = {'/create'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.uri.toString();

      if (auth.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      if (_protectedRoutes.contains(loc) && !auth.isAuthenticated) {
        return '/login';
      }

      if ((loc == '/login' || loc == '/register') && auth.isAuthenticated) {
        return '/home';
      }

      if (loc == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const NoTransitionPage(child: SplashScreen()),
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
      // Profile route — works for any user's handle
      GoRoute(
        path: '/profile/:handle',
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          // For now resolve to mock data; swap for API lookup when backend ready
          final profile = handle == mockOwnFanProfile.handle
              ? mockOwnFanProfile
              : FanProfileModel(
                  firstName: handle,
                  lastName: '',
                  handle: handle,
                  fanOf: 'SportSphere',
                  fanOfAccent: const Color(0xFF009DFF),
                  bio: '',
                  sport: 'Football',
                  location: '',
                  joinedDate: DateTime.now(),
                  postCount: 0,
                  followerCount: 0,
                  followingCount: 0,
                );
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: FanProfileView(profile: profile),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(opacity: anim, child: child),
            ),
          );
        },
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
