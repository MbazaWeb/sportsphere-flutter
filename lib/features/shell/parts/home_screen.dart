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
  final _search = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _groups = [];
  final _joined = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('Community')
          .select()
          .order('memberCount', ascending: false)
          .limit(40);
      final list = [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final joined = <String>{};
      if (uid != null) {
        final mem = await Supabase.instance.client
            .from('CommunityMember')
            .select('communityId')
            .eq('userId', uid);
        for (final r in mem as List) {
          final id = (r as Map)['communityId']?.toString();
          if (id != null) joined.add(id);
        }
      }
      if (mounted) {
        setState(() {
          _groups = list;
          _joined
            ..clear()
            ..addAll(joined);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(String id) async {
    final commerce = CommerceRepository();
    try {
      if (_joined.contains(id)) {
        await commerce.leaveCommunity(id);
        setState(() => _joined.remove(id));
      } else {
        await commerce.joinCommunity(id);
        setState(() => _joined.add(id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final groups = _groups.where((g) {
      final name = '${g['name'] ?? ''}'.toLowerCase();
      return q.isEmpty || name.contains(q);
    }).toList();

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search communities',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No communities yet. Official can seed Community rows in Supabase.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          for (final g in groups)
            Card(
              color: const Color(0xFF0C1A2A),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                  '${g['name'] ?? 'Community'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${g['memberCount'] ?? 0} members · ${g['topic'] ?? g['description'] ?? ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                ),
                trailing: TextButton(
                  onPressed: () => _toggle('${g['id']}'),
                  child: Text(_joined.contains('${g['id']}') ? 'Joined' : 'Join'),
                ),
              ),
            ),
        ],
      ),
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
