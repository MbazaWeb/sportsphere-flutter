part of '../app_shell.dart';

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  static const _tabs = ['Spotlights', 'News', 'Trending', 'Community', 'E-Shop'];

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
              NewsTab(),
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
                        fontSize: 11,
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
  final _joined = <String>{'Simba SC Official Fans'};
  final _search = TextEditingController();
  int? _pollVote;
  String _query = '';

  static const _groups = [
    ('Simba SC Official Fans', '42.1K members', 'Football · Official', 'Derby week thread is live. Share clips and meet-up points.'),
    ('TPL Tactics Room', '8.4K members', 'Analysis', 'Post-match xG, lineups and formations.'),
    ('Dar Matchday Meetups', '3.2K members', 'Local', 'Find fans going to Mkapa this weekend.'),
    ('Women in Football TZ', '1.9K members', 'Community', 'Players, coaches and fans building the game.'),
    ('Yanga Union', '31.6K members', 'Football · Official', 'Jangwani updates, away days and chants.'),
    ('Predictions League', '6.8K members', 'Fantasy', 'Weekly TPL and CAF score predictions.'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final groups = _groups.where((g) => q.isEmpty || g.$1.toLowerCase().contains(q)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search communities',
            hintStyle: const TextStyle(color: SportSphereColors.muted),
            prefixIcon: const Icon(Icons.search_rounded, color: SportSphereColors.muted),
            filled: true,
            fillColor: SportSphereColors.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Live poll', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        GlassContainer(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Who lifts the next Kariakoo derby?',
                  style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final e in ['Simba SC', 'Young Africans', 'Draw'].asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _pollVote = e.key),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _pollVote == e.key
                            ? SportSphereColors.electricBlue.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: _pollVote == e.key
                              ? SportSphereColors.electricBlue
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(e.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              Text(_pollVote == null ? '1.2K votes · tap to vote' : 'Vote saved · 1.2K votes',
                  style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Communities', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassContainer(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            Text('${g.$2} · ${g.$3}', style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
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
                  const SizedBox(height: 10),
                  Text(g.$4, style: const TextStyle(color: SportSphereColors.muted, fontSize: 13, height: 1.35)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _openGroup(context, g),
                    child: const Text('Open community',
                        style: TextStyle(color: SportSphereColors.electricBlue, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _openGroup(BuildContext context, (String, String, String, String) g) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Text(g.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
            Text('${g.$2} · ${g.$3}', style: const TextStyle(color: SportSphereColors.muted)),
            const SizedBox(height: 12),
            Text(g.$4, style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 16),
            const Text('Latest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('· @david posted a matchday clip', style: TextStyle(color: Colors.white70)),
            const Text('· @alikingu shared lineup notes', style: TextStyle(color: Colors.white70)),
            const Text('· Poll: best signing this window', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _EShopContent extends StatelessWidget {
  const _EShopContent();

  @override
  Widget build(BuildContext context) {
    return ShopTab(catalog: marketplaceCatalog());
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
