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
            children: [
              const _SpotlightsContent(),
              const NewsTab(),
              const _TrendingContent(),
              const _CommunityContent(),
              ShopTab(catalog: marketplaceCatalog()),
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
                            ? PlayifyColors.white
                            : PlayifyColors.muted,
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

// ── NOTE ──────────────────────────────────────────────────────────────
// The previous _publicRead() wrapper called signOut(scope: local)
// when a data query failed with JWT/session/401 keywords. This was
// INCORRECT — a data query failure must NEVER destroy the auth session.
// Queries below now run directly; errors propagate to the UI which
// shows appropriate messages via friendlyError().
// ──────────────────────────────────────────────────────────────────

// ── Trending tab ───────────────────────────────────────────

class _TrendingContent extends StatefulWidget {
  const _TrendingContent();
  @override
  State<_TrendingContent> createState() => _TrendingContentState();
}

class _TrendingContentState extends State<_TrendingContent> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('Post')
          .select()
          .order('likeCount', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _rows = [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No trending posts yet', style: TextStyle(color: PlayifyColors.white54)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        itemCount: _rows.length,
        itemBuilder: (_, i) {
          final post = _rows[i];
          final content = (post['content'] as String? ?? '').trim();
          final likes = post['likeCount'] ?? 0;
          final comments = post['commentCount'] ?? 0;
          final userId = post['userId']?.toString() ?? '';
          final postType = post['postType'] as String? ?? 'text';

          return GestureDetector(
            onTap: () async {
              // Navigate to the author's profile
              try {
                final profile = await Supabase.instance.client
                    .from('profiles')
                    .select('handle')
                    .eq('id', userId)
                    .maybeSingle();
                final handle = profile?['handle'] as String?;
                if (handle != null && handle.isNotEmpty && context.mounted) {
                  context.push('/profile/$handle');
                }
              } catch (_) {}
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Post type badge
                if (postType != 'text') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PlayifyColors.electricBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(postType.toUpperCase(),
                        style: const TextStyle(color: PlayifyColors.electricBlue,
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                ],
                // Content
                if (content.isNotEmpty)
                  Text(content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PlayifyColors.white,
                          fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 10),
                // Stats row
                Row(children: [
                  const Icon(Icons.favorite_rounded, size: 14, color: PlayifyColors.danger),
                  const SizedBox(width: 4),
                  Text('$likes', style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: PlayifyColors.muted),
                  const SizedBox(width: 4),
                  Text('$comments', style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: PlayifyColors.muted),
                ]),
              ]),
            ),
          );
        },
      ),
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
      // Try Community table first
      List<Map<String, dynamic>> list = [];
      try {
        final rows = await Supabase.instance.client
            .from('Community')
            .select()
            .order('memberCount', ascending: false)
            .limit(40);
        list = [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
      } catch (_) {}

      // If empty, fall back to entity_communities (fan communities auto-created per team)
      if (list.isEmpty) {
        try {
          final rows = await Supabase.instance.client
              .from('entity_communities')
              .select()
              .order('member_count', ascending: false)
              .limit(40);
          list = [for (final r in rows as List) {
            'id': (r as Map)['id'],
            'name': r['name'],
            'description': r['description'] ?? 'Fan community',
            'memberCount': r['member_count'] ?? 0,
            'topic': 'Football',
            '_source': 'entity',
          }];
        } catch (_) {}
      }

      final uid = Supabase.instance.client.auth.currentUser?.id;
      final joined = <String>{};
      if (uid != null) {
        try {
          final mem = await Supabase.instance.client
              .from('CommunityMember')
              .select('communityId')
              .eq('userId', uid);
          for (final r in mem as List) {
            final id = (r as Map)['communityId']?.toString();
            if (id != null) joined.add(id);
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _groups = list;
          _joined..clear()..addAll(joined);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
              fillColor: PlayifyColors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.groups_rounded, size: 56,
                    color: PlayifyColors.muted.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text('No communities yet',
                    style: TextStyle(color: PlayifyColors.white,
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Communities are created automatically for every team. Ask admin to add teams.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PlayifyColors.muted, fontSize: 13)),
              ]),
            ),
          for (final g in groups)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1A2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: PlayifyColors.electricBlue.withValues(alpha: 0.15),
                  child: const Icon(Icons.groups_rounded,
                      color: PlayifyColors.electricBlue, size: 20),
                ),
                title: Text(
                  '${g['name'] ?? 'Community'}',
                  style: const TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${g['memberCount'] ?? 0} members · ${g['topic'] ?? g['description'] ?? ''}',
                  style: const TextStyle(color: PlayifyColors.muted, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                trailing: OutlinedButton(
                  onPressed: () => _toggle('${g['id']}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _joined.contains('${g['id']}')
                        ? PlayifyColors.muted
                        : PlayifyColors.electricBlue,
                    side: BorderSide(color: _joined.contains('${g['id']}')
                        ? PlayifyColors.muted.withValues(alpha: 0.3)
                        : PlayifyColors.electricBlue.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_joined.contains('${g['id']}') ? 'Joined' : 'Join',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



// ignore: unused_element
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
          Text(title, style: const TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
