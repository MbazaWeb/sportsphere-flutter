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
        body: Center(child: CircularProgressIndicator(
            color: SportSphereColors.electricBlue, strokeWidth: 2)),
      );
    }

    final isAdmin = AppAdmin.isAdminUser(user);

    final profile = FanProfileModel(
      firstName: user.firstName,
      lastName: user.lastName,
      handle: user.handle,
      email: user.email,
      fanOf: '',
      fanOfAccent: SportSphereColors.electricBlue,
      bio: user.bio,
      sport: 'Football',
      location: user.country,
      joinedDate: user.joinedDate,
      postCount: user.postCount,
      followerCount: user.followerCount,
      followingCount: user.followingCount,
      avatarAsset: user.avatarUrl,
      isVerified: user.isVerified,
      isOwnProfile: true,
    );

    return Stack(
      children: [
        FanProfileView(profile: profile),
        if (isAdmin)
          Positioned(
            bottom: 120,
            right: 16,
            child: GestureDetector(
              onTap: () => context.push('/admin'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        color: Color(0xFFFFD700), size: 18),
                    SizedBox(width: 6),
                    Text('Admin', style: TextStyle(
                      color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
