part of '../app_shell.dart';

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  static const _tabs = ['Spotlights', 'Trending', 'Community', 'E-Shop'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Sticky header + tab bar ───────────────────────────
        _Header(),
        _HomeTabBar(
          tabs: _tabs,
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),

        // ── Tab content ───────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              _SpotlightsContent(),
              _TrendingContent(),
              _CommunityContent(),
              _EShopContent(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────

class _HomeTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _HomeTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GlassContainer(
        height: 48,
        radius: 26,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final active = selectedIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: active
                        ? const LinearGradient(
                            colors: [Color(0xFF082C4A), Color(0xFF06304F)],
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        color: active
                            ? SportSphereColors.white
                            : SportSphereColors.muted,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Spotlights tab ─────────────────────────────────────────

class _SpotlightsContent extends StatelessWidget {
  const _SpotlightsContent();

  @override
  Widget build(BuildContext context) {
    return const SportlightsTab();
  }
}

// ── Trending tab ───────────────────────────────────────────

class _TrendingContent extends StatelessWidget {
  const _TrendingContent();

  @override
  Widget build(BuildContext context) {
    return _ComingSoonPlaceholder(
      icon: Icons.trending_up_rounded,
      label: 'Trending',
      subtitle: 'Top stories, viral moments and what the\nsports world is talking about.',
      accent: const Color(0xFFFF8A00),
    );
  }
}

// ── Community tab ──────────────────────────────────────────

class _CommunityContent extends StatefulWidget {
  const _CommunityContent();
  @override
  State<_CommunityContent> createState() => _CommunityContentState();
}

class _CommunityContentState extends State<_CommunityContent> {
  final _joined = <String>{};

  static const _groups = [
    ('Simba SC Official Fans', '42.1K members'),
    ('TPL Tactics Room', '8.4K members'),
    ('Dar Matchday Meetups', '3.2K members'),
    ('Women in Football TZ', '1.9K members'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const Text('Communities',
            style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        for (final g in _groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassContainer(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: SportSphereColors.sportGreen.withValues(alpha: 0.18),
                    child: const Icon(Icons.groups_rounded, color: SportSphereColors.sportGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.$1, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
                        Text(g.$2, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_joined.contains(g.$1)) {
                        _joined.remove(g.$1);
                      } else {
                        _joined.add(g.$1);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _joined.contains(g.$1)
                            ? Colors.white.withValues(alpha: 0.08)
                            : SportSphereColors.sportGreen.withValues(alpha: 0.18),
                      ),
                      child: Text(
                        _joined.contains(g.$1) ? 'Joined' : 'Join',
                        style: TextStyle(
                          color: _joined.contains(g.$1) ? SportSphereColors.muted : SportSphereColors.sportGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── E-Shop tab ─────────────────────────────────────────────

class _EShopContent extends StatelessWidget {
  const _EShopContent();

  static const _items = [
    ('Home Kit 25/26', 'TZS 65,000'),
    ('Away Kit 25/26', 'TZS 65,000'),
    ('Match Ticket', 'TZS 10,000'),
    ('Fan Membership', 'TZS 25,000'),
    ('Club Scarf', 'TZS 18,000'),
    ('Training Cap', 'TZS 15,000'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const Text('E-Shop',
            style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassContainer(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SportSphereColors.electricBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: SportSphereColors.electricBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
                        Text(item.$2, style: const TextStyle(color: SportSphereColors.electricBlue, fontWeight: FontWeight.w800, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Text('View', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Coming-soon placeholder ────────────────────────────────

class _ComingSoonPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;

  const _ComingSoonPlaceholder({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.10),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: accent, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SportSphereColors.muted.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Coming Soon',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SimpleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SimpleCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
