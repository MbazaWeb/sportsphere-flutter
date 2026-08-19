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

class _CommunityContent extends StatelessWidget {
  const _CommunityContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: const [
        _SimpleCard(title: 'Simba SC Official Fans', subtitle: '42.1K members'),
        SizedBox(height: 10),
        _SimpleCard(title: 'TPL Tactics Room', subtitle: '8.4K members'),
        SizedBox(height: 10),
        _SimpleCard(title: 'Who wins the next derby?', subtitle: '1.2K votes'),
      ],
    );
  }
}

// ── E-Shop tab ─────────────────────────────────────────────

class _EShopContent extends StatelessWidget {
  const _EShopContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: const [
        _SimpleCard(title: 'Home Kit 25/26', subtitle: 'TZS 65,000'),
        SizedBox(height: 10),
        _SimpleCard(title: 'Match Ticket', subtitle: 'TZS 10,000'),
        SizedBox(height: 10),
        _SimpleCard(title: 'Fan Membership', subtitle: 'TZS 25,000'),
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
