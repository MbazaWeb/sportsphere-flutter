part of '../app_shell.dart';

class _ProfileScreen extends ConsumerStatefulWidget {
  const _ProfileScreen();

  @override
  ConsumerState<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<_ProfileScreen> {
  List<String> _fanBadges = const [];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final badges = await SocialRepository().fanTeamNames(uid);
      if (mounted) setState(() => _fanBadges = badges);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final badges = _fanBadges.isNotEmpty
        ? _fanBadges
        : (user?.fanBadges ?? const <String>[]);

    final profile = user != null
        ? FanProfileModel(
            firstName: user.firstName,
            lastName: user.lastName,
            handle: user.handle,
            fanOf: badges.isNotEmpty ? badges.first : 'SportSphere Fan',
            fanOfAccent: Color(int.parse(user.themeColor.replaceFirst('#', '0xFF'))),
            bio: user.bio.isEmpty ? 'New on SportSphere' : user.bio,
            sport: 'Football',
            location: user.country,
            joinedDate: user.dob,
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
            avatarAsset: user.avatarUrl ?? 'assets/images/sport_sphere_icon.png',
            coverAsset: user.coverUrl,
            isVerified: user.isVerified,
            isOwnProfile: true,
            userId: Supabase.instance.client.auth.currentUser?.id,
          )
        : FanProfileModel(
            firstName: 'Guest',
            lastName: '',
            handle: 'guest',
            fanOf: 'SportSphere',
            fanOfAccent: const Color(0xFF009DFF),
            bio: 'Sign in to build your profile',
            sport: 'Football',
            location: '',
            joinedDate: DateTime.now(),
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
            isOwnProfile: true,
          );

    return FanProfileView(
      profile: profile,
      onEdit: user == null ? null : () => showEditProfileSheet(context, user),
    );
  }
}

// _PageTitle and _ProfileStat kept for other parts that still reference them

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
