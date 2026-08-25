part of '../app_shell.dart';

class _FullScreenSearch extends StatefulWidget {
  const _FullScreenSearch();
  @override
  State<_FullScreenSearch> createState() => _FullScreenSearchState();
}

class _FullScreenSearchState extends State<_FullScreenSearch>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
    _tabCtrl.dispose();
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

            // ── Tab bar ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: SportSphereColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: SportSphereColors.electricBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: SportSphereColors.electricBlue,
                unselectedLabelColor: SportSphereColors.muted,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.search_rounded, size: 16),
                    text: 'Search',
                  ),
                  Tab(
                    icon: Icon(Icons.people_alt_rounded, size: 16),
                    text: 'Nearby Fans',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Tab content ───────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 1: Search ─────────────────────────────────
                  _loading
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

                  // ── Tab 2: Nearby Fans ───────────────────────────
                  const _NearbyFansTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEARBY FANS TAB
// Scans for fans who share teams, sports, or country with the current user.
// ─────────────────────────────────────────────────────────────────────────────

class _NearbyFansTab extends StatefulWidget {
  const _NearbyFansTab();

  @override
  State<_NearbyFansTab> createState() => _NearbyFansTabState();
}

class _NearbyFansTabState extends State<_NearbyFansTab> {
  final SupabaseClient _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _fans = [];
  bool _loading = true;
  String? _error;

  // Filter chips
  _NearbyFilter _filter = _NearbyFilter.all;

  // Current user context
  String? _myUid;
  String? _myCountry;
  final Set<String> _myTeamIds = {};
  final Set<String> _mySportIds = {};

  @override
  void initState() {
    super.initState();
    _loadMyContext();
  }

  /// Load the current user's uid, country, favorite teams, and followed sports.
  /// This determines what "nearby" means for each filter.
  Future<void> _loadMyContext() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sign in to discover nearby fans';
        });
      }
      return;
    }
    _myUid = uid;

    try {
      // Load my profile (country)
      final me = await _sb
          .from('User')
          .select('currentCountry, countryOfOrigin, location')
          .eq('id', uid)
          .maybeSingle();
      if (me != null) {
        _myCountry = (me['currentCountry'] as String?) ??
            (me['countryOfOrigin'] as String?) ??
            (me['location'] as String?);
      }

      // Load my favorite teams (UserFavorite where targetType='TEAM')
      final favTeams = await _sb
          .from('UserFavorite')
          .select('targetId')
          .eq('userId', uid)
          .eq('targetType', 'TEAM');
      for (final r in favTeams as List) {
        final id = (r as Map)['targetId'] as String?;
        if (id != null && id.isNotEmpty) _myTeamIds.add(id);
      }

      // Load my sports (UserSport)
      final mySports = await _sb
          .from('UserSport')
          .select('sportId')
          .eq('userId', uid);
      for (final r in mySports as List) {
        final id = (r as Map)['sportId'] as String?;
        if (id != null && id.isNotEmpty) _mySportIds.add(id);
      }

      _loadFans();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your profile: $e';
        });
      }
    }
  }

  /// Load fans based on the active filter.
  Future<void> _loadFans() async {
    if (_myUid == null) return;
    if (mounted) setState(() => _loading = true);

    try {
      final Set<String> matchedUids = {};
      final reasons = <String, String>{};

      // ── Filter: Same Team ─────────────────────────────────────
      if (_filter == _NearbyFilter.all || _filter == _NearbyFilter.team) {
        if (_myTeamIds.isNotEmpty) {
          // Find other users who also favorite any of my teams
          final teamFans = await _sb
              .from('UserFavorite')
              .select('userId, targetId, targetName')
              .inFilter('targetId', _myTeamIds.toList())
              .neq('userId', _myUid!);
          for (final r in teamFans as List) {
            final m = r as Map;
            final uid = m['userId'] as String?;
            if (uid != null && uid != _myUid) {
              matchedUids.add(uid);
              reasons[uid] = 'Fan of ${m['targetName'] ?? 'your team'}';
            }
          }
        }
      }

      // ── Filter: Same Sport ────────────────────────────────────
      if (_filter == _NearbyFilter.all || _filter == _NearbyFilter.sport) {
        if (_mySportIds.isNotEmpty) {
          final sportFans = await _sb
              .from('UserSport')
              .select('userId, sportId')
              .inFilter('sportId', _mySportIds.toList())
              .neq('userId', _myUid!);
          for (final r in sportFans as List) {
            final m = r as Map;
            final uid = m['userId'] as String?;
            if (uid != null && uid != _myUid) {
              matchedUids.add(uid);
              reasons.update(uid, (v) => '$v · Same sport',
                  ifAbsent: () => 'Follows a sport you like');
            }
          }
        }
      }

      // ── Filter: Same Country ──────────────────────────────────
      if (_filter == _NearbyFilter.all || _filter == _NearbyFilter.country) {
        if (_myCountry != null && _myCountry!.isNotEmpty) {
          // Query fans in the same country
          final countryFans = await _sb
              .from('User')
              .select('id, handle, name, avatarUrl, role, currentCountry, location')
              .or('currentCountry.ilike.%$_myCountry%,countryOfOrigin.ilike.%$_myCountry%,location.ilike.%$_myCountry%')
              .neq('id', _myUid!)
              .limit(100);
          for (final r in countryFans as List) {
            final m = r as Map;
            final uid = m['id'] as String?;
            if (uid != null) {
              matchedUids.add(uid);
              reasons.update(uid, (v) => '$v · Same country',
                  ifAbsent: () => 'In $_myCountry');
            }
          }
        }
      }

      // ── Filter: Fan Engagements (mutual fans — both fan of same targets)
      if (_filter == _NearbyFilter.engagements) {
        // Find users I am a fan of, then find OTHER users who also fan them
        if (_myTeamIds.isNotEmpty) {
          final engagements = await _sb
              .from('UserFavorite')
              .select('userId, targetId, targetName')
              .inFilter('targetId', _myTeamIds.toList())
              .neq('userId', _myUid!);
          for (final r in engagements as List) {
            final m = r as Map;
            final uid = m['userId'] as String?;
            if (uid != null && uid != _myUid) {
              matchedUids.add(uid);
              reasons[uid] = 'Also fans ${m['targetName'] ?? 'same team'}';
            }
          }
        }
      }

      // ── Fetch full profiles for matched UIDs ──────────────────
      if (matchedUids.isEmpty) {
        if (mounted) {
          setState(() {
            _fans = [];
            _loading = false;
            _error = null;
          });
        }
        return;
      }

      // Supabase inFilter has a max of ~300 items; chunk if needed
      final uidList = matchedUids.toList();
      final profiles = <Map<String, dynamic>>[];

      // Process in chunks of 100
      for (var i = 0; i < uidList.length; i += 100) {
        final chunk = uidList.sublist(
            i, (i + 100 > uidList.length) ? uidList.length : i + 100);
        final rows = await _sb
            .from('User')
            .select('id, handle, name, avatarUrl, role, currentCountry, location, bio')
            .inFilter('id', chunk);
        for (final r in rows as List) {
          final m = Map<String, dynamic>.from(r as Map);
          m['_reason'] = reasons[m['id']] ?? 'Nearby fan';
          profiles.add(m);
        }
      }

      if (mounted) {
        setState(() {
          _fans = profiles;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load nearby fans: $e';
        });
      }
    }
  }

  void _onFilterChanged(_NearbyFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _loadFans();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: SportSphereColors.electricBlue,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48,
                  color: SportSphereColors.muted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SportSphereColors.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadMyContext,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ── Filter chips ─────────────────────────────────────────
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All Fans',
                icon: Icons.people_rounded,
                selected: _filter == _NearbyFilter.all,
                onTap: () => _onFilterChanged(_NearbyFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Same Team',
                icon: Icons.shield_rounded,
                selected: _filter == _NearbyFilter.team,
                onTap: () => _onFilterChanged(_NearbyFilter.team),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Same Sport',
                icon: Icons.sports_soccer_rounded,
                selected: _filter == _NearbyFilter.sport,
                onTap: () => _onFilterChanged(_NearbyFilter.sport),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Same Country',
                icon: Icons.public_rounded,
                selected: _filter == _NearbyFilter.country,
                onTap: () => _onFilterChanged(_NearbyFilter.country),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Fan Engagements',
                icon: Icons.favorite_rounded,
                selected: _filter == _NearbyFilter.engagements,
                onTap: () => _onFilterChanged(_NearbyFilter.engagements),
              ),
            ],
          ),
        ),

        // ── Fans list ────────────────────────────────────────────
        Expanded(
          child: _fans.isEmpty
              ? _EmptyState(filter: _filter)
              : RefreshIndicator(
                  color: SportSphereColors.electricBlue,
                  onRefresh: _loadFans,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    itemCount: _fans.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (_, i) {
                      final f = _fans[i];
                      return _NearbyFanCard(
                        uid: (f['id'] as String?) ?? '',
                        name: (f['name'] as String?) ?? '',
                        handle: (f['handle'] as String?) ?? '',
                        avatarUrl: f['avatarUrl'] as String?,
                        role: (f['role'] as String?) ?? 'fan',
                        country: (f['currentCountry'] as String?) ??
                            (f['location'] as String?),
                        reason: (f['_reason'] as String?) ?? 'Nearby fan',
                        bio: f['bio'] as String?,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEARBY FAN CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NearbyFanCard extends StatelessWidget {
  final String uid;
  final String name;
  final String handle;
  final String? avatarUrl;
  final String role;
  final String? country;
  final String reason;
  final String? bio;

  const _NearbyFanCard({
    required this.uid,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.role,
    required this.country,
    required this.reason,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : '@$handle';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: SportSphereColors.electricBlue.withValues(alpha: 0.15),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: SportSphereColors.electricBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Name + reason
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: SportSphereColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (country != null && country!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SportSphereColors.sportGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          country!,
                          style: TextStyle(
                            color: SportSphereColors.sportGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '@$handle',
                  style: const TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.link_rounded,
                        size: 12,
                        color: SportSphereColors.electricBlue
                            .withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: SportSphereColors.electricBlue
                              .withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          _FanActionButtons(uid: uid, handle: handle),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAN ACTION BUTTONS — Follow + Message
// ─────────────────────────────────────────────────────────────────────────────

class _FanActionButtons extends StatefulWidget {
  final String uid;
  final String handle;

  const _FanActionButtons({
    required this.uid,
    required this.handle,
  });

  @override
  State<_FanActionButtons> createState() => _FanActionButtonsState();
}

class _FanActionButtonsState extends State<_FanActionButtons> {
  final SupabaseClient _sb = Supabase.instance.client;
  bool _following = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    try {
      final row = await _sb
          .from('Follow')
          .select()
          .eq('followerId', me)
          .eq('followingId', widget.uid)
          .maybeSingle();
      if (mounted) setState(() => _following = row != null);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    final me = _sb.auth.currentUser?.id;
    if (me == null) return;
    setState(() => _busy = true);
    final wasFollowing = _following;
    setState(() => _following = !wasFollowing);
    try {
      if (wasFollowing) {
        await _sb
            .from('Follow')
            .delete()
            .eq('followerId', me)
            .eq('followingId', widget.uid);
      } else {
        await _sb.from('Follow').insert({
          'followerId': me,
          'followingId': widget.uid,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _following = wasFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${wasFollowing ? 'unfollow' : 'follow'}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Follow / Following button
        GestureDetector(
          onTap: _busy ? null : _toggleFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _following
                  ? SportSphereColors.surface2
                  : SportSphereColors.electricBlue,
              borderRadius: BorderRadius.circular(20),
              border: _following
                  ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                  : null,
            ),
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SportSphereColors.white,
                    ),
                  )
                : Text(
                    _following ? 'Following' : 'Follow',
                    style: const TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        // View profile button
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            context.push('/profile/${widget.handle}');
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SportSphereColors.surface2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: SportSphereColors.muted,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? SportSphereColors.electricBlue.withValues(alpha: 0.15)
              : SportSphereColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? SportSphereColors.electricBlue.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? SportSphereColors.electricBlue
                  : SportSphereColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? SportSphereColors.electricBlue
                    : SportSphereColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _NearbyFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String title;
    String hint;
    IconData icon;

    switch (filter) {
      case _NearbyFilter.team:
        title = 'No fans of your teams yet';
        hint = 'Favorite a team from its profile to find fellow fans';
        icon = Icons.shield_outlined;
        break;
      case _NearbyFilter.sport:
        title = 'No fans of your sports yet';
        hint = 'Follow a sport to discover others who love it too';
        icon = Icons.sports_soccer_outlined;
        break;
      case _NearbyFilter.country:
        title = 'No fans in your country yet';
        hint = 'Set your country in your profile to find local fans';
        icon = Icons.public_outlined;
        break;
      case _NearbyFilter.engagements:
        title = 'No mutual fan engagements yet';
        hint = 'Fan a team to find others who also support them';
        icon = Icons.favorite_outline;
        break;
      case _NearbyFilter.all:
        title = 'No nearby fans found';
        hint = 'Favorite teams and follow sports to discover nearby fans';
        icon = Icons.people_outline_rounded;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56,
                color: SportSphereColors.muted.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: const TextStyle(
                color: SportSphereColors.muted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUM: Nearby fan filter type
// ─────────────────────────────────────────────────────────────────────────────

enum _NearbyFilter { all, team, sport, country, engagements }

// ─────────────────────────────────────────────────────────────────────────────
// DISCOVER (original — shown when search query is empty)
// ─────────────────────────────────────────────────────────────────────────────

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
