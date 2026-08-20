import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/profile/Profile/academy/academy_profile_view.dart';
import '../../features/profile/Profile/agent/agent_profile_view.dart';
import '../../features/profile/Profile/analyst/analyst_profile_view.dart';
import '../../features/profile/Profile/business/business_profile_view.dart';
import '../../features/profile/Profile/coach/coach_profile_view.dart';
import '../../features/profile/Profile/commentator/commentator_profile_view.dart';
import '../../features/profile/Profile/commercial_partner/commercial_partner_profile_view.dart';
import '../../features/profile/Profile/community/community_profile_view.dart';
import '../../features/profile/Profile/competition/competition_profile_view.dart';
import '../../features/profile/Profile/creator/creator_profile_view.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/profile/Profile/journalist/journalist_profile_view.dart';
import '../../features/profile/Profile/league/league_profile_view.dart';
import '../../features/profile/Profile/media_broadcast/media_broadcast_profile_view.dart';
import '../../features/profile/Profile/moderator/moderator_profile_view.dart';
import '../../features/profile/Profile/official/official_profile_view.dart';
import '../../features/profile/Profile/organization/organization_profile_view.dart';
import '../../features/profile/Profile/player/player_profile_view.dart';
import '../../features/profile/Profile/scout/scout_profile_view.dart';
import '../../features/profile/Profile/sponsor/sponsor_profile_view.dart';
import '../../features/profile/Profile/support_staff/support_staff_profile_view.dart';
import '../../features/profile/Profile/team/team_profile_view.dart';
import '../../features/profile/data/team_profile_lookup.dart';
import '../../features/profile/Profile/venue/venue_profile_view.dart';
import '../../features/profile/templates/role_profile_shell.dart';
import '../../features/profile/data/role_mocks.dart';
import '../../features/shell/app_shell.dart';
import '../../splash_screen.dart';

const _protectedRoutes = {'/create'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc  = state.uri.toString();
      if (auth.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      if (_protectedRoutes.contains(loc) && !auth.isAuthenticated) {
        return '/login';
      }
      if ((loc == '/login' || loc == '/register') && auth.isAuthenticated) {
        return '/home';
      }
      // Splash navigates itself after animation.
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => const NoTransitionPage(
          key: ValueKey('splash'),
          child: SplashScreen(),
        ),
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
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, state) => const NoTransitionPage(
          key: ValueKey('home'),
          child: SportSphereShell(),
        ),
      ),

      // ── Fan profile  /profile/:handle ──────────────────────
      GoRoute(
        path: '/profile/:handle',
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
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
          return _slideTransition(state.pageKey, FanProfileView(profile: profile));
        },
      ),

      // ── Player profile  /player/:handle ────────────────────
      GoRoute(
        path: '/player/:handle',
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          final profile = handle == mockClatousChama.handle
              ? mockClatousChama
              : PlayerProfileModel(
                  firstName: handle, lastName: '', handle: handle,
                  fullName: handle, position: 'Forward', nationality: 'Unknown',
                  dob: DateTime(1995), heightCm: 175, preferredFoot: 'Right',
                  currentClub: 'Unknown', currentLeague: 'Unknown',
                  squadNumber: 0, contractStatus: 'Active',
                  accentColor: const Color(0xFF009DFF),
                  postCount: 0, fanCount: 0, followerCount: 0, followingCount: 0,
                  career: const [], seasonStats: const [],
                  allTimeGoals: 0, allTimeAssists: 0, allTimeAppearances: 0,
                  allTimeMinutes: 0, allTimeYellowCards: 0, allTimeRedCards: 0,
                );
          return _slideTransition(state.pageKey, PlayerProfileView(profile: profile));
        },
      ),

      // ── Team profile  /team/:handle ─────────────────────────
      GoRoute(
        path: '/team/:handle',
        pageBuilder: (_, state) {
          final handle = state.pathParameters['handle'] ?? '';
          return _slideTransition(
            state.pageKey,
            FutureBuilder<TeamProfileModel>(
              future: loadTeamProfile(handle),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF071422),
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return TeamProfileView(profile: snap.data!);
              },
            ),
          );
        },
      ),

      // Role profiles (Admin is web-only — not routed here)
      ..._roleRoutes(),
    ],
  );
});

List<GoRoute> _roleRoutes() {
  Widget page(String role, String handle) =>
      RoleProfileShell(profile: roleProfileFor(role, handle));

  GoRoute r(String path, Widget Function(String handle) build) {
    return GoRoute(
      path: path,
      pageBuilder: (_, state) {
        final handle = state.pathParameters['handle'] ?? '';
        return _slideTransition(state.pageKey, build(handle));
      },
    );
  }

  return [
    r('/coach/:handle', (h) => CoachProfileView(handle: h)),
    r('/scout/:handle', (h) => ScoutProfileView(handle: h)),
    r('/agent/:handle', (h) => AgentProfileView(handle: h)),
    r('/support-staff/:handle', (h) => SupportStaffProfileView(handle: h)),
    r('/analyst/:handle', (h) => AnalystProfileView(handle: h)),
    r('/commentator/:handle', (h) => CommentatorProfileView(handle: h)),
    r('/journalist/:handle', (h) => JournalistProfileView(handle: h)),
    r('/creator/:handle', (h) => CreatorProfileView(handle: h)),
    r('/moderator/:handle', (h) => ModeratorProfileView(handle: h)),
    r('/official/:handle', (h) => OfficialProfileView(handle: h)),
    r('/academy/:handle', (h) => AcademyProfileView(handle: h)),
    r('/league/:handle', (h) => LeagueProfileView(handle: h)),
    r('/competition/:handle', (h) => CompetitionProfileView(handle: h)),
    r('/organization/:handle', (h) => OrganizationProfileView(handle: h)),
    r('/media/:handle', (h) => MediaBroadcastProfileView(handle: h)),
    r('/community/:handle', (h) => CommunityProfileView(handle: h)),
    r('/business/:handle', (h) => BusinessProfileView(handle: h)),
    r('/sponsor/:handle', (h) => SponsorProfileView(handle: h)),
    r('/partner/:handle', (h) => CommercialPartnerProfileView(handle: h)),
    r('/venue/:handle', (h) => VenueProfileView(handle: h)),
    GoRoute(
      path: '/role/:role/:handle',
      pageBuilder: (_, state) {
        final role = state.pathParameters['role'] ?? 'fan';
        final handle = state.pathParameters['handle'] ?? role;
        return _slideTransition(state.pageKey, page(role, handle));
      },
    ),
  ];
}

CustomTransitionPage<void> _slideTransition(
    LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(
              begin: const Offset(0, 0.04), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}
