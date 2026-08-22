part of '../app_shell.dart';

class _FullScreenSearch extends StatefulWidget {
  const _FullScreenSearch();
  @override
  State<_FullScreenSearch> createState() => _FullScreenSearchState();
}

class _FullScreenSearchState extends State<_FullScreenSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final q = _controller.text.trim();
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final sb = Supabase.instance.client;
    final pattern = '%$q%';
    final merged = <Map<String, dynamic>>[];
    try {
      final profiles = await sb
          .from('profiles')
          .select('id, handle, first_name, last_name, role, avatar_url')
          .or('handle.ilike.$pattern,first_name.ilike.$pattern,last_name.ilike.$pattern')
          .limit(20);
      for (final r in profiles as List) {
        final m = Map<String, dynamic>.from(r as Map);
        m['_kind'] = 'user';
        merged.add(m);
      }
    } catch (_) {}
    try {
      final leagues = await sb
          .from('League')
          .select('id, name, country, type, season')
          .or('name.ilike.$pattern,country.ilike.$pattern,season.ilike.$pattern')
          .limit(15);
      for (final r in leagues as List) {
        final m = Map<String, dynamic>.from(r as Map);
        merged.add({
          'id': m['id'],
          'handle': (m['name'] as String? ?? 'league')
              .toLowerCase()
              .replaceAll(' ', '_'),
          'first_name': m['name'],
          'last_name': '',
          'role': 'league',
          'avatar_url': null,
          '_kind': 'league',
          '_subtitle':
              '${m['country'] ?? ''} · ${m['type'] ?? ''} · ${m['season'] ?? ''}',
        });
      }
    } catch (_) {}
    try {
      final teams = await sb
          .from('Team')
          .select('id, name, country, city, logoUrl')
          .or('name.ilike.$pattern,country.ilike.$pattern,city.ilike.$pattern')
          .limit(15);
      for (final r in teams as List) {
        final m = Map<String, dynamic>.from(r as Map);
        merged.add({
          'id': m['id'],
          'handle': (m['name'] as String? ?? 'team')
              .toLowerCase()
              .replaceAll(' ', '_'),
          'first_name': m['name'],
          'last_name': '',
          'role': 'team',
          'avatar_url': m['logoUrl'],
          '_kind': 'team',
          '_subtitle': '${m['city'] ?? ''} · ${m['country'] ?? ''}',
        });
      }
    } catch (_) {}
    try {
      final players = await sb
          .from('Player')
          .select('id, name, position, nationality, teamId')
          .or('name.ilike.$pattern,position.ilike.$pattern,nationality.ilike.$pattern')
          .limit(15);
      for (final r in players as List) {
        final m = Map<String, dynamic>.from(r as Map);
        merged.add({
          'id': m['id'],
          'handle': (m['name'] as String? ?? 'player')
              .toLowerCase()
              .replaceAll(' ', '_'),
          'first_name': m['name'],
          'last_name': '',
          'role': 'player',
          'avatar_url': null,
          '_kind': 'player',
          '_subtitle': '${m['position'] ?? ''} · ${m['nationality'] ?? ''}',
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _results = merged;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.length >= 2;
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: SportSphereColors.white),
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: SportSphereColors.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: SportSphereColors.electricBlue
                              .withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SportSphereColors.electricBlue
                                .withValues(alpha: 0.08),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style:
                            const TextStyle(color: SportSphereColors.white),
                        cursorColor: SportSphereColors.electricBlue,
                        decoration: InputDecoration(
                          hintText: 'Search players, teams, fans...',
                          hintStyle: TextStyle(
                              color: SportSphereColors.muted
                                  .withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: SportSphereColors.electricBlue),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: SportSphereColors.muted,
                                      size: 18),
                                  onPressed: () => _controller.clear(),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: SportSphereColors.electricBlue,
                          strokeWidth: 2))
                  : !hasQuery
                      ? _Discover()
                      : _results.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded,
                                      size: 48,
                                      color: SportSphereColors.muted
                                          .withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  Text('No results for "$_query"',
                                      style: const TextStyle(
                                          color: SportSphereColors.muted,
                                          fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 40),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color:
                                      Colors.white.withValues(alpha: 0.06)),
                              itemBuilder: (_, i) {
                                final r = _results[i];
                                final first =
                                    (r['first_name'] as String?) ?? '';
                                final last =
                                    (r['last_name'] as String?) ?? '';
                                final name = '$first $last'.trim();
                                final handle =
                                    (r['handle'] as String?) ?? '';
                                final role =
                                    (r['role'] as String?) ?? 'fan';
                                final avatarUrl =
                                    r['avatar_url'] as String?;
                                final displayRole = role.isNotEmpty
                                    ? role[0].toUpperCase() +
                                        role.substring(1)
                                    : 'Fan';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: SportSphereColors
                                        .electricBlue
                                        .withValues(alpha: 0.15),
                                    backgroundImage: avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? const Icon(Icons.person_rounded,
                                            color:
                                                SportSphereColors.electricBlue)
                                        : null,
                                  ),
                                  title: Text(
                                    name.isNotEmpty ? name : '@$handle',
                                    style: const TextStyle(
                                        color: SportSphereColors.white,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '@$handle  ·  $displayRole',
                                    style: const TextStyle(
                                        color: SportSphereColors.muted,
                                        fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: SportSphereColors.muted,
                                      size: 20),
                                  onTap: () {
                                    Navigator.pop(context);
                                    final r = role.toLowerCase();
                                    if (r == 'team') {
                                      context.push('/team/$handle');
                                    } else if (r == 'player') {
                                      context.push('/player/$handle');
                                    } else if (r == 'fan' || r == '') {
                                      context.push('/profile/$handle');
                                    } else {
                                      context.push('/role/$r/$handle');
                                    }
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Discover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Text(
          'EXPLORE',
          style: TextStyle(
            color: SportSphereColors.muted.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _DiscoverChip(
            label: 'Players', icon: Icons.sports_soccer_rounded),
        _DiscoverChip(
            label: 'Teams', icon: Icons.groups_rounded),
        _DiscoverChip(
            label: 'Coaches', icon: Icons.sports_rounded),
        _DiscoverChip(
            label: 'Communities', icon: Icons.forum_rounded),
      ],
    );
  }
}

class _DiscoverChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DiscoverChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: SportSphereColors.electricBlue, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: SportSphereColors.muted.withValues(alpha: 0.5),
              size: 20),
        ],
      ),
    );
  }
}
