part of '../app_shell.dart';

class _InvisibleScrollBehavior extends ScrollBehavior {
  const _InvisibleScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

class _Stories extends StatelessWidget {
  const _Stories();

  @override
  Widget build(BuildContext context) {
    const names = [
      'Your Story',
    ];

    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          return SizedBox(
            width: 68,
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        SportSphereSportSphereColors.electricBlue,
                        SportSphereSportSphereColors.sportGreen,
                        SportSphereSportSphereColors.sportOrange,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SportSphereSportSphereColors.electricBlue.withValues(
                          alpha: 0.16,
                        ),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SportSphereSportSphereColors.background,
                    ),
                    child: index == 0
                        ? const Icon(
                            Icons.add_rounded,
                            color: SportSphereSportSphereColors.electricBlue,
                            size: 28,
                          )
                        : const Icon(
                            Icons.sports_soccer_rounded,
                            color: SportSphereSportSphereColors.white,
                            size: 27,
                          ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  names[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SportSphereSportSphereColors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String username;
  final String handle;
  final String time;
  final String title;
  final String description;
  final String? imageAsset;
  final String likes;
  final String comments;
  final String reposts;
  final bool featured;

  const _PostCard({
    required this.username,
    required this.handle,
    required this.time,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.likes,
    required this.comments,
    required this.reposts,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      SportSphereSportSphereColors.electricBlue,
                      SportSphereSportSphereColors.sportGreen,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SportSphereSportSphereColors.background,
                    ),
                    child: const Icon(
                      Icons.sports_soccer_rounded,
                      color: SportSphereSportSphereColors.muted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: SportSphereSportSphereColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: SportSphereSportSphereColors.electricBlue,
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$handle · $time',
                      style: const TextStyle(
                        color: SportSphereSportSphereColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.more_horiz_rounded,
                color: SportSphereSportSphereColors.muted,
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (featured)
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B3150), Color(0xFF03101E)],
                ),
              ),
              child: const Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      Icons.sports_soccer_rounded,
                      size: 150,
                      color: Color(0x2200A8FF),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: SportSphereSportSphereColors.white,
                      size: 52,
                    ),
                  ),
                ],
              ),
            ),

          if (featured) const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(
              color: SportSphereSportSphereColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFD1DCE8),
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              _Action(icon: Icons.favorite_border_rounded, value: likes),
              const SizedBox(width: 24),
              _Action(icon: Icons.chat_bubble_outline_rounded, value: comments),
              const SizedBox(width: 24),
              _Action(icon: Icons.repeat_rounded, value: reposts),
              const Spacer(),
              const Icon(
                Icons.bookmark_border_rounded,
                color: SportSphereSportSphereColors.muted,
                size: 21,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Action({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: SportSphereSportSphereColors.muted, size: 20),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(color: SportSphereSportSphereColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
