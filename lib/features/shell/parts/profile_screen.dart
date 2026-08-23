part of '../app_shell.dart';

class _ProfileScreen extends ConsumerStatefulWidget {
  const _ProfileScreen();

  @override
  ConsumerState<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<_ProfileScreen> {
  // H5 — Cache the profile Future per (handle) so the FutureBuilder does not
  // re-fire on every rebuild (e.g. when the parent shell re-fires build due
  // to other tab state changes). The future is invalidated whenever the
  // resolved handle changes.
  String? _cachedHandle;
  int _profileVersion = 0; // increments after edit to force re-resolve
  late Future<FanProfileModel> _profileFuture;

  Future<FanProfileModel> _resolveFuture() {
    final auth = ref.read(authControllerProvider);
    final user = auth.user;
    if (user == null) {
      // Never actually awaited — the build() short-circuits when user == null.
      // Still return a fully-formed model so the Future type-checks.
      return Future.value(FanProfileModel(
        firstName: '',
        lastName: '',
        handle: '',
        fanOf: '',
        fanOfAccent: SportSphereColors.electricBlue,
        bio: '',
        sport: '',
        location: '',
        joinedDate: DateTime.now(),
        postCount: 0,
        followerCount: 0,
        followingCount: 0,
      ));
    }
    final isAdmin = AppAdmin.isAdminUser(user);
    final handle = isAdmin
        ? 'playify'
        : user.handle.replaceAll('@', '').trim();
    final effective = handle.isEmpty ? user.handle : handle;
    return ProfileLoader.loadFanProfile(effective);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: SportSphereColors.background,
        body: Center(
            child: CircularProgressIndicator(
                color: SportSphereColors.electricBlue, strokeWidth: 2)),
      );
    }

    final isAdmin = AppAdmin.isAdminUser(user);
    final handle = isAdmin
        ? 'playify'
        : user.handle.replaceAll('@', '').trim();

    // Re-resolve only when the handle changes — this preserves the cached
    // future across unrelated rebuilds (e.g. when other tabs setState).
    // Re-resolve when handle, avatar, or bio changes.
    // refreshProfile() updates user object → new avatarUrl → new cacheKey → fresh future.
    final cacheKey = '$handle:${user.avatarUrl}:$_profileVersion';
    if (_cachedHandle != cacheKey) {
      _cachedHandle = cacheKey;
      _profileFuture = _resolveFuture();
    }

    return FutureBuilder<FanProfileModel>(
      future: _profileFuture,
      builder: (context, snap) {
        FanProfileModel profile;
        if (snap.hasData) {
          profile = snap.data!;
          // Force own profile chrome on this tab.
          // #3.3 — Preserve the isAdmin / role flags from the loader so the
          // "Become PRO" button is correctly hidden for admin accounts.
          profile = FanProfileModel(
            firstName: isAdmin ? 'Playify' : profile.firstName,
            lastName: isAdmin ? '' : profile.lastName,
            handle: isAdmin ? 'playify' : profile.handle,
            email: user.email,
            fanOf: isAdmin ? '' : profile.fanOf,
            fanOfAccent: profile.fanOfAccent,
            bio: isAdmin
                ? 'Official Playify platform account.'
                : profile.bio,
            sport: isAdmin ? '' : profile.sport,
            location: isAdmin ? '' : profile.location,
            joinedDate: profile.joinedDate,
            postCount: profile.postCount > 0
                ? profile.postCount
                : user.postCount,
            followerCount: profile.followerCount,
            followingCount: profile.followingCount,
            avatarAsset: profile.avatarAsset?.isNotEmpty == true
                ? profile.avatarAsset
                : (user.avatarUrl?.isNotEmpty == true
                    ? user.avatarUrl
                    : 'assets/images/Playify_logo.png'),
            coverAsset: profile.coverAsset ?? user.coverUrl,
            isVerified: true,
            isOwnProfile: true,
            isAdmin: isAdmin || profile.isAdmin,
            role: isAdmin ? 'admin' : profile.role,
          );
        } else {
          profile = FanProfileModel(
            firstName: isAdmin ? 'Playify' : user.firstName,
            lastName: isAdmin ? '' : user.lastName,
            handle: isAdmin ? 'playify' : user.handle,
            email: user.email,
            fanOf: '',
            fanOfAccent: SportSphereColors.electricBlue,
            bio: isAdmin
                ? 'Official Playify platform account.'
                : user.bio,
            sport: isAdmin ? '' : 'Football',
            location: isAdmin ? '' : user.country,
            joinedDate: user.joinedDate,
            postCount: user.postCount,
            followerCount: user.followerCount,
            followingCount: user.followingCount,
            avatarAsset: user.avatarUrl,
            coverAsset: user.coverUrl,
            isVerified: true,
            isOwnProfile: true,
            isAdmin: isAdmin,
            role: user.role,
          );
        }

        return Stack(
          children: [
            FanProfileView(profile: profile),
            if (snap.connectionState == ConnectionState.waiting)
              const Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (isAdmin)
              Positioned(
                bottom: 120,
                right: 16,
                child: GestureDetector(
                  onTap: () => context.push('/admin'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings_rounded,
                            color: Color(0xFFFFD700), size: 18),
                        SizedBox(width: 6),
                        Text('Admin',
                            style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
