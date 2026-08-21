part of '../app_shell.dart';

class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    // Not authenticated — should not reach here (router guards this)
    if (user == null) {
      return const Scaffold(
        backgroundColor: SportSphereColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: SportSphereColors.electricBlue,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Build FanProfileModel from real authenticated UserProfile
    final profile = FanProfileModel(
      firstName: user.firstName,
      lastName: user.lastName,
      handle: user.handle,
      email: user.email,
      fanOf: '',        // empty until user chooses a team via Edit Profile
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
