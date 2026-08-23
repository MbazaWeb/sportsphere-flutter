part of '../app_shell.dart';

class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return FutureBuilder(
      future: ProfileLoader.loadFanProfile(
          handle.isEmpty ? user.handle : handle),
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
            avatarAsset: profile.avatarAsset ?? user.avatarUrl,
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
