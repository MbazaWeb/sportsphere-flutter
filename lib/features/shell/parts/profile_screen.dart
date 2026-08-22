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

    // ── Admin users get the dedicated Admin Profile view ──────────────────────
    if (AppAdmin.isAdminUser(user)) {
      return const AdminProfileView();
    }

    // ── Regular users get the Fan Profile view ────────────────────────────────
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

    return FanProfileView(profile: profile);
  }
}
