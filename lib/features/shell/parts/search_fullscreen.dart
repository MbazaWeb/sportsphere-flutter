part of '../app_shell.dart';

// VpsRepository + VpsSupabaseCompat are re-exported via the parent
// app_shell.dart import chain (core/data/* imported there).

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
    final merged = <Map<String, dynamic>>[];
    try {
      final res = await const VpsRepository().searchAll(q);
      merged.addAll(res);
    } catch (e) {
      debugPrint('[SEARCH] $e');
    }
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
      backgroundColor: PlayifyColors.background,
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
                        color: PlayifyColors.white),
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: PlayifyColors.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: PlayifyColors.electricBlue
                              .withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PlayifyColors.electricBlue
                                .withValues(alpha: 0.08),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style:
                            const TextStyle(color: PlayifyColors.white),
                        cursorColor: PlayifyColors.electricBlue,
                        decoration: InputDecoration(
                          hintText: 'Search players, teams, fans...',
                          hintStyle: TextStyle(
                              color: PlayifyColors.muted
                                  .withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: PlayifyColors.electricBlue),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: PlayifyColors.muted,
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
                color: PlayifyColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: PlayifyColors.electricBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: PlayifyColors.electricBlue,
                unselectedLabelColor: PlayifyColors.muted,
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
                              color: PlayifyColors.electricBlue,
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
                                          color: PlayifyColors.muted
                                              .withValues(alpha: 0.4)),
                                      const SizedBox(height: 12),
                                      Text('No results for "$_query"',
                                          style: const TextStyle(
                                              color: PlayifyColors.muted,
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
                                        backgroundColor: PlayifyColors
                                            .electricBlue
                                            .withValues(alpha: 0.15),
                                        backgroundImage: avatarUrl != null
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        child: avatarUrl == null
                                            ? const Icon(Icons.person_rounded,
                                                color:
                                                    PlayifyColors.electricBlue)
                                            : null,
                                      ),
                                      title: Text(
                                        name.isNotEmpty ? name : '@$handle',
                                        style: const TextStyle(
                                            color: PlayifyColors.white,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      subtitle: Text(
                                        '@$handle  ·  $displayRole',
                                        style: const TextStyle(
                                            color: PlayifyColors.muted,
                                            fontSize: 12),
                                      ),
                                      trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: PlayifyColors.muted,
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
// Scans for fans near you using GPS. Shows radar animation on tab open.
// Fans are sorted by distance. User can follow + message each fan.
// ─────────────────────────────────────────────────────────────────────────────

enum _NearbyFilter { all, team, sport, country, engagements }

class _NearbyFansTab extends StatefulWidget {
  const _NearbyFansTab();

  @override
  State<_NearbyFansTab> createState() => _NearbyFansTabState();
}

class _NearbyFansTabState extends State<_NearbyFansTab>
    with SingleTickerProviderStateMixin {
  final _sb = VpsSupabaseCompat.client;
  List<Map<String, dynamic>> _fans = [];
  bool _loading = true;
  bool _scanning = false;
  String? _error;

  // Radar animation
  late final AnimationController _radarCtrl;
  late final Animation<double> _radarAnim;

  // Filter chips
  _NearbyFilter _filter = _NearbyFilter.all;

  // Current user GPS location
  double? _myLat;
  double? _myLng;
  String? _myUid;
  String? _myCountry;

  // Current user context for non-GPS filters
  final Set<String> _myTeamIds = {};
  final Set<String> _mySportIds = {};

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _radarAnim = CurvedAnimation(
      parent: _radarCtrl,
      curve: Curves.easeOutCubic,
    );
    // Trigger radar scan on tab open
    _triggerScan();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  /// Trigger the radar scan animation + load nearby fans.
  Future<void> _triggerScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _loading = true;
      _error = null;
    });

    // Start radar animation
    _radarCtrl.forward(from: 0.0);

    // Get GPS location + load context in parallel
    await Future.wait([
      _getMyLocation(),
      _loadMyContext(),
    ]);

    // Wait for radar animation to complete (min 1.5s for visual effect)
    await Future.delayed(const Duration(milliseconds: 1500));

    // Load fans based on filter
    await _loadFans();

    if (mounted) {
      setState(() => _scanning = false);
    }
  }

  /// Get the current user's GPS location using geolocator.
  Future<void> _getMyLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fall back to country-based matching
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _myLat = position.latitude;
      _myLng = position.longitude;

      // Save location to profile for future queries
      if (VpsSupabaseCompat.client.auth.currentUser != null) {
        try {
          await const VpsRepository().updateLocation(_myLat!, _myLng!);
        } catch (_) {}
      }
    } catch (e) {
      // GPS failed — fall back to country-based matching
      debugPrint('GPS error: $e');
    }
  }

  /// Load the current user's uid, country, favorite teams, and followed sports.
  Future<void> _loadMyContext() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _error = 'Sign in to discover nearby fans';
        });
      }
      return;
    }
    _myUid = uid;

    try {
      // Load my profile (country + GPS)
      try {
        final me = await const VpsRepository().getProfile(uid);
        _myCountry = (me?['currentCountry'] as String?) ??
            (me?['country'] as String?) ??
            (me?['location'] as String?);
      } catch (_) {}

      // Load my favorite teams
      final favTeams = <Map<String, dynamic>>[];
      try {
        final res = await const VpsRepository().get<Map<String, dynamic>>(
          '/v1/social/my-favorites', query: {'type': 'TEAM'});
        favTeams.addAll((res.data?['favorites'] as List? ?? []).cast<Map<String, dynamic>>());
      } catch (_) {}
      for (final r in favTeams as List) {
        final id = (r as Map)['targetId'] as String?;
        if (id != null && id.isNotEmpty) _myTeamIds.add(id);
      }

      // Load my sports
      final mySports = _sb
          .from('UserSport')
          .select('sportId')
          .eq('userId', uid);
      for (final r in mySports as List) {
        final id = (r as Map)['sportId'] as String?;
        if (id != null && id.isNotEmpty) _mySportIds.add(id);
      }
    } catch (e) {
      debugPrint('_loadMyContext: $e');
    }
  }

  /// Load fans based on the active filter.
  Future<void> _loadFans() async {
    if (_myUid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // ── GPS-based nearby fans ─────────────────────────────────
      if (_myLat != null && _myLng != null &&
          (_filter == _NearbyFilter.all || _filter == _NearbyFilter.country)) {
        final rows = await const VpsRepository().getNearbyFans(
          lat: _myLat!, lng: _myLng!,
          radiusM: 100000, limit: 50,
        );
        final profiles = <Map<String, dynamic>>[];
        for (final m in rows) {
          final updated = Map<String, dynamic>.from(m);
          final distM = (m['distance_m'] as num?)?.toDouble() ?? 0;
          updated['_distance'] = _formatDistance(distM);
          updated['_reason'] = '\${_formatDistance(distM)} away';
          profiles.add(updated);
        }

        if (mounted) {
          setState(() {
            _fans = profiles;
            _loading = false;
            _error = null;
          });
        }
        return;
      }

      // ── Filter: Same Team ─────────────────────────────────────
      if (_filter == _NearbyFilter.team && _myTeamIds.isNotEmpty) {
        final teamFansRes = await const VpsRepository().get<Map<String, dynamic>>(
            '/v1/social/fans-by-teams',
            query: {'ids': _myTeamIds.join(','), 'exclude': _myUid!});
        final teamFans = (teamFansRes.data?['fans'] as List? ?? []).cast<Map<String,dynamic>>();
        final uids = <String>{};
        final reasons = <String, String>{};
        for (final r in teamFans as List) {
          final m = r as Map;
          final uid = m['userId'] as String?;
          if (uid != null && uid != _myUid) {
            uids.add(uid);
            reasons[uid] = 'Fan of ${m['targetName'] ?? 'your team'}';
          }
        }
        await _fetchProfilesByIds(uids, reasons);
        return;
      }

      // ── Filter: Same Sport ────────────────────────────────────
      if (_filter == _NearbyFilter.sport && _mySportIds.isNotEmpty) {
        final sportFansRes = await const VpsRepository().get<Map<String, dynamic>>(
            '/v1/social/fans-by-sports',
            query: {'ids': _mySportIds.join(','), 'exclude': _myUid!});
        final sportFans = (sportFansRes.data?['fans'] as List? ?? []).cast<Map<String,dynamic>>();
        final uids = <String>{};
        final reasons = <String, String>{};
        for (final r in sportFans as List) {
          final m = r as Map;
          final uid = m['userId'] as String?;
          if (uid != null && uid != _myUid) {
            uids.add(uid);
            reasons[uid] = 'Follows a sport you like';
          }
        }
        await _fetchProfilesByIds(uids, reasons);
        return;
      }

      // ── Filter: Fan Engagements ───────────────────────────────
      if (_filter == _NearbyFilter.engagements && _myTeamIds.isNotEmpty) {
        final engagementsRes = await const VpsRepository().get<Map<String, dynamic>>(
            '/v1/social/fans-by-teams',
            query: {'ids': _myTeamIds.join(','), 'exclude': _myUid!});
        final engagements = (engagementsRes.data?['fans'] as List? ?? []).cast<Map<String,dynamic>>();
        final uids = <String>{};
        final reasons = <String, String>{};
        for (final r in engagements as List) {
          final m = r as Map;
          final uid = m['userId'] as String?;
          if (uid != null && uid != _myUid) {
            uids.add(uid);
            reasons[uid] = 'Also fans ${m['targetName'] ?? 'same team'}';
          }
        }
        await _fetchProfilesByIds(uids, reasons);
        return;
      }

      // ── Fallback: Same Country (text-based) ───────────────────
      if (_myCountry != null && _myCountry!.isNotEmpty) {
        final countryFansRes = await const VpsRepository().get<Map<String, dynamic>>(
            '/v1/social/fans-by-country',
            query: {'country': _myCountry!, 'exclude': _myUid!, 'limit': '50'});
        final countryFans = (countryFansRes.data?['fans'] as List? ?? []).cast<Map<String,dynamic>>();
        final profiles = <Map<String, dynamic>>[];
        for (final r in countryFans as List) {
          final m = Map<String, dynamic>.from(r as Map);
          m['_reason'] = 'In $_myCountry';
          m['_distance'] = null;
          profiles.add(m);
        }
        if (mounted) {
          setState(() {
            _fans = profiles;
            _loading = false;
            _error = null;
          });
        }
        return;
      }

      // No data to match on
      if (mounted) {
        setState(() {
          _fans = [];
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

  /// Fetch full profiles for a set of user IDs.
  Future<void> _fetchProfilesByIds(
    Set<String> uids,
    Map<String, String> reasons,
  ) async {
    if (uids.isEmpty) {
      if (mounted) {
        setState(() {
          _fans = [];
          _loading = false;
        });
      }
      return;
    }

    final uidList = uids.toList();
    final profiles = <Map<String, dynamic>>[];

    for (var i = 0; i < uidList.length; i += 100) {
      final chunk = uidList.sublist(
          i, (i + 100 > uidList.length) ? uidList.length : i + 100);
      final batchRes = await const VpsRepository().post<Map<String, dynamic>>(
          '/v1/social/profiles/batch', data: {'ids': chunk});
      final profileMap = (batchRes.data?['profiles'] as Map? ?? {});
      for (final entry in profileMap.entries) {
        final m = Map<String, dynamic>.from(entry.value as Map);
        m['_reason'] = reasons[entry.key] ?? 'Nearby fan';
        m['_distance'] = null;
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
  }

  /// Format distance in meters to a human-readable string.
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else if (meters < 100000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${(meters / 1000).round()} km';
    }
  }

  void _onFilterChanged(_NearbyFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _loadFans();
  }

  @override
  Widget build(BuildContext context) {
    // Show radar scan animation when scanning
    if (_scanning || _loading) {
      return _RadarScanOverlay(
        animation: _radarAnim,
        message: _scanning ? 'Scanning for nearby fans...' : 'Loading...',
      );
    }

    if (_error != null) {
      final isGuest = _error == 'Sign in to discover nearby fans';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGuest ? Icons.near_me_rounded : Icons.wifi_off_rounded,
                size: 64,
                color: isGuest
                    ? PlayifyColors.electricBlue.withValues(alpha: 0.5)
                    : PlayifyColors.muted.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 20),
              Text(
                isGuest ? 'Discover Fans Near You' : 'Could not load',
                style: const TextStyle(
                  color: PlayifyColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isGuest
                    ? 'Log in to find fans of your favourite team who are close to you right now.'
                    : _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PlayifyColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (isGuest)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/login');
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Log In',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: PlayifyColors.electricBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _triggerScan,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: PlayifyColors.electricBlue),
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
                label: 'Nearby (GPS)',
                icon: Icons.my_location_rounded,
                selected: _filter == _NearbyFilter.all ||
                    _filter == _NearbyFilter.country,
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
                label: 'Engagements',
                icon: Icons.favorite_rounded,
                selected: _filter == _NearbyFilter.engagements,
                onTap: () => _onFilterChanged(_NearbyFilter.engagements),
              ),
            ],
          ),
        ),

        // ── Rescan button ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.radar_rounded,
                  size: 14, color: PlayifyColors.electricBlue),
              const SizedBox(width: 6),
              Text(
                _myLat != null
                    ? 'Location: ${_myLat!.toStringAsFixed(3)}, ${_myLng!.toStringAsFixed(3)}'
                    : 'GPS unavailable — showing text-based matches',
                style: const TextStyle(
                  color: PlayifyColors.muted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _triggerScan,
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 14, color: PlayifyColors.electricBlue),
                    SizedBox(width: 4),
                    Text(
                      'Rescan',
                      style: TextStyle(
                        color: PlayifyColors.electricBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Fans list ────────────────────────────────────────────
        Expanded(
          child: _fans.isEmpty
              ? _EmptyState(filter: _filter)
              : RefreshIndicator(
                  color: PlayifyColors.electricBlue,
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
                        distance: f['_distance'] as String?,
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
// RADAR SCAN OVERLAY — animated radar that plays while scanning for fans
// ─────────────────────────────────────────────────────────────────────────────

class _RadarScanOverlay extends StatelessWidget {

  const _RadarScanOverlay({
    required this.animation,
    required this.message,
  });
  final Animation<double> animation;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Radar animation
          SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RadarPainter(animation.value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Message
          Text(
            message,
            style: const TextStyle(
              color: PlayifyColors.electricBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Animated dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = (animation.value * 3 - i * 0.3) % 1.0;
                  final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: PlayifyColors.electricBlue
                          .withValues(alpha: opacity.clamp(0.1, 1.0)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RADAR PAINTER — draws concentric circles + sweeping radar line
// ─────────────────────────────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {

  _RadarPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = PlayifyColors.electricBlue.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    // Concentric circles
    final ringPaint = Paint()
      ..color = PlayifyColors.electricBlue.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ringPaint);
    }

    // Cross lines
    final linePaint = Paint()
      ..color = PlayifyColors.electricBlue.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );

    // Sweep gradient (the rotating radar beam)
    final sweepAngle = progress * 2 * 3.14159265;
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: 3.14159265 / 2, // 90-degree fan
        colors: [
          PlayifyColors.electricBlue.withValues(alpha: 0.4),
          PlayifyColors.electricBlue.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(sweepRect);
    canvas.drawArc(
      sweepRect,
      sweepAngle,
      3.14159265 / 2, // 90 degrees
      true,
      sweepPaint,
    );

    // Center dot (you)
    final centerPaint = Paint()
      ..color = PlayifyColors.electricBlue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, centerPaint);
    // Pulsing ring around center
    final pulseRadius = 6.0 + progress * 20;
    final pulsePaint = Paint()
      ..color = PlayifyColors.electricBlue
          .withValues(alpha: (1 - progress) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Random "detected" dots that appear as the sweep passes
    final rng = List.generate(8, (i) => i * 0.7853); // fixed positions
    for (var i = 0; i < rng.length; i++) {
      final angle = rng[i];
      final dist = maxRadius * (0.3 + (i % 3) * 0.2);
      final dx = center.dx + dist * math.cos(angle);
      final dy = center.dy + dist * math.sin(angle);
      final dotPos = Offset(dx, dy);

      // Dot appears when sweep is near
      final sweepPos = (sweepAngle % (2 * 3.14159265)) / (2 * 3.14159265);
      final dotPos2 = angle / (2 * 3.14159265);
      final delta = (sweepPos - dotPos2).abs();
      final visibility = delta < 0.15 ? (1 - delta / 0.15) : 0.0;

      if (visibility > 0) {
        final dotPaint = Paint()
          ..color = PlayifyColors.sportGreen.withValues(alpha: visibility)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(dotPos, 4 * visibility, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEARBY FAN CARD — shows fan info + distance + Follow + Message buttons
// ─────────────────────────────────────────────────────────────────────────────

class _NearbyFanCard extends StatelessWidget {

  const _NearbyFanCard({
    required this.uid,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.role,
    required this.country,
    required this.reason,
    required this.distance,
    required this.bio,
  });
  final String uid;
  final String name;
  final String handle;
  final String? avatarUrl;
  final String role;
  final String? country;
  final String reason;
  final String? distance;
  final String? bio;

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
            backgroundColor: PlayifyColors.electricBlue.withValues(alpha: 0.15),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: PlayifyColors.electricBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Name + reason + distance
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/$handle');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: PlayifyColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PlayifyColors.sportGreen
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_rounded,
                                  size: 10,
                                  color: PlayifyColors.sportGreen),
                              const SizedBox(width: 2),
                              Text(
                                distance!,
                                style: const TextStyle(
                                  color: PlayifyColors.sportGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (country != null && country!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PlayifyColors.sportGreen
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            country!,
                            style: const TextStyle(
                              color: PlayifyColors.sportGreen,
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
                      color: PlayifyColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.link_rounded,
                          size: 12,
                          color: PlayifyColors.electricBlue
                              .withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          reason,
                          style: TextStyle(
                            color: PlayifyColors.electricBlue
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
          ),

          // Action buttons: Follow + Message
          _FanActionButtons(uid: uid, handle: handle, name: displayName),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAN ACTION BUTTONS — Follow + Message + View profile
// ─────────────────────────────────────────────────────────────────────────────

class _FanActionButtons extends StatefulWidget {

  const _FanActionButtons({
    required this.uid,
    required this.handle,
    required this.name,
  });
  final String uid;
  final String handle;
  final String name;

  @override
  State<_FanActionButtons> createState() => _FanActionButtonsState();
}

class _FanActionButtonsState extends State<_FanActionButtons> {
  bool _following = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (VpsSupabaseCompat.client.auth.currentUser == null) return;
    try {
      final following = await const VpsRepository().isFollowing(widget.uid);
      if (mounted) setState(() => _following = following);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    if (VpsSupabaseCompat.client.auth.currentUser == null) return;
    setState(() => _busy = true);
    final wasFollowing = _following;
    setState(() => _following = !wasFollowing);
    try {
      if (wasFollowing) {
        await const VpsRepository().unfollowUser(widget.uid);
      } else {
        await const VpsRepository().followUser(widget.uid);
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

  void _startChat() {
    // Close the search page first, then open the message sheet with this peer
    Navigator.of(context).pop(); // close search
    // Use post-frame callback to ensure search is dismissed before opening sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _Header._showMessages(
        context,
        peerId: widget.uid,
        peerName: widget.name,
        peerHandle: widget.handle,
      );
    });
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _following
                  ? PlayifyColors.surface2
                  : PlayifyColors.electricBlue,
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
                      color: PlayifyColors.white,
                    ),
                  )
                : Text(
                    _following ? 'Following' : 'Follow',
                    style: const TextStyle(
                      color: PlayifyColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        // Message button
        GestureDetector(
          onTap: _startChat,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PlayifyColors.sportGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: PlayifyColors.sportGreen.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: PlayifyColors.sportGreen,
              size: 18,
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

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? PlayifyColors.electricBlue.withValues(alpha: 0.15)
              : PlayifyColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? PlayifyColors.electricBlue.withValues(alpha: 0.4)
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
                  ? PlayifyColors.electricBlue
                  : PlayifyColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? PlayifyColors.electricBlue
                    : PlayifyColors.muted,
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
  const _EmptyState({required this.filter});
  final _NearbyFilter filter;

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
                color: PlayifyColors.muted.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: PlayifyColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: const TextStyle(
                color: PlayifyColors.muted,
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
            color: PlayifyColors.muted.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const _DiscoverChip(
            label: 'Players', icon: Icons.sports_soccer_rounded),
        const _DiscoverChip(
            label: 'Teams', icon: Icons.groups_rounded),
        const _DiscoverChip(
            label: 'Coaches', icon: Icons.sports_rounded),
        const _DiscoverChip(
            label: 'Communities', icon: Icons.forum_rounded),
      ],
    );
  }
}

class _DiscoverChip extends StatelessWidget {
  const _DiscoverChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

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
          Icon(icon, color: PlayifyColors.electricBlue, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: PlayifyColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: PlayifyColors.muted.withValues(alpha: 0.5),
              size: 20),
        ],
      ),
    );
  }
}
