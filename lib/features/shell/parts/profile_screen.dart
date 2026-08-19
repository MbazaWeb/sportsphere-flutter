part of '../app_shell.dart';

class _ProfileScreen extends ConsumerWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    // Build a profile model from auth state; fall back to mock for display
    final profile = user != null
        ? FanProfileModel(
            firstName: user.firstName,
            lastName: user.lastName,
            handle: user.handle,
            fanOf: 'SportSphere',
            fanOfAccent: SportSphereColors.electricBlue,
            bio: user.bio.isEmpty ? 'New on SportSphere' : user.bio,
            sport: 'Football',
            location: user.country,
            joinedDate: user.dob,
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
            avatarAsset: 'assets/images/sport_sphere_icon.png',
            isVerified: false,
            isOwnProfile: true,
          )
        : mockOwnFanProfile;

    return FanProfileView(
      profile: profile,
      onEdit: user == null ? null : () => showEditProfileSheet(context, user),
    );
  }
}

// _PageTitle and _ProfileStat kept for other parts that still reference them
class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SportSphereColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: SportSphereColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SportSphereColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: SportSphereColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
