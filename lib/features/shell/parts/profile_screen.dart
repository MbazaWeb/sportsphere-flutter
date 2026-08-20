part of '../app_shell.dart';

// Fix #12: Removed dead _ProfileStat and _PageTitle classes (nothing referenced them).
class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    // Fix #4: joinedDate is now properly distinct from dob.
    // email field now included so About tab can display it for own profile.
    final profile = user != null
        ? FanProfileModel(
            firstName: user.firstName,
            lastName: user.lastName,
            handle: user.handle,
            email: user.email,
            fanOf: 'SportSphere',
            fanOfAccent: SportSphereColors.electricBlue,
            bio: '',
            sport: 'Football',
            location: user.country,
            joinedDate: user.joinedDate,
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
            avatarAsset: user.avatarUrl,
            isVerified: false,
            isOwnProfile: true,
          )
        : mockOwnFanProfile;

    return FanProfileView(profile: profile);
  }
}
