part of '../app_shell.dart';

class _CreateScreen extends StatelessWidget {
  const _CreateScreen();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: _PageTitle(
            title: 'Create',
            subtitle: 'Share something with the sports community',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
          sliver: SliverToBoxAdapter(
            child: GlassContainer(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: SportSphereColors.surface2,
                    child: Icon(
                      Icons.add_rounded,
                      color: SportSphereColors.electricBlue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Create a post',
                    style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share news, predictions, match reactions or moments.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SportSphereColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _CreateOption(
                    icon: Icons.edit_rounded,
                    title: 'Post',
                    subtitle: 'Write something',
                  ),
                  const SizedBox(height: 10),
                  _CreateOption(
                    icon: Icons.image_outlined,
                    title: 'Photo',
                    subtitle: 'Share a sports photo',
                  ),
                  const SizedBox(height: 10),
                  _CreateOption(
                    icon: Icons.videocam_outlined,
                    title: 'Video',
                    subtitle: 'Share a sports video',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: SportSphereColors.electricBlue.withValues(alpha: 0.10),
            ),
            child: Icon(icon, color: SportSphereColors.electricBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SportSphereColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: SportSphereColors.muted,
          ),
        ],
      ),
    );
  }
}
