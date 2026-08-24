part of '../app_shell.dart';

class _FullScreenSearch extends StatefulWidget {
  const _FullScreenSearch();
  @override
  State<_FullScreenSearch> createState() => _FullScreenSearchState();
}

class _FullScreenSearchState extends State<_FullScreenSearch>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ctrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    final q = _ctrl.text.trim();
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      final pattern = q.toLowerCase();

      final profiles = await sb
          .from('profiles')
          .select('id, handle, first_name, last_name, role, avatar_url')
          .or('handle.ilike.%$pattern%,first_name.ilike.%$pattern%,last_name.ilike.%$pattern%')
          .not('role', 'in', '(team,player,league,coach)')
          .limit(20);

      final teams = await sb
          .from('Team')
          .select('id, name, slug, country, city, logoUrl, shortName')
          .or('name.ilike.%$pattern%,slug.ilike.%$pattern%,city.ilike.%$pattern%,shortName.ilike.%$pattern%')
          .limit(10);

      final players = await sb
          .from('Player')
          .select('id, name, slug, position, nationality, teamId, photoUrl')
          .or('name.ilike.%$pattern%,nationality.ilike.%$pattern%')
          .limit(10);

      final results = <Map<String, dynamic>>[];

      for (final r in List<Map<String, dynamic>>.from(profiles as List)) {
        results.add({...r, '_kind': 'user'});
      }
      for (final r in List<Map<String, dynamic>>.from(teams as List)) {
        results.add({
          'handle': r['slug'] ?? '',
          'first_name': r['name'] ?? '',
          'last_name': r['country'] ?? '',
          'role': 'team',
          'avatar_url': r['logoUrl'],
          '_kind': 'team',
          '_id': r['id'],
        });
      }
      for (final r in List<Map<String, dynamic>>.from(players as List)) {
        results.add({
          'handle': r['slug'] ?? '',
          'first_name': r['name'] ?? '',
          'last_name': r['position'] ?? '',
          'role': 'player',
          'avatar_url': r['photoUrl'],
          '_kind': 'player',
          '_id': r['id'],
        });
      }

      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      appBar: AppBar(
        backgroundColor: SportSphereColors.surface,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: SportSphereColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          style: const TextStyle(color: SportSphereColors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search fans, teams, players…',
            hintStyle: TextStyle(color: SportSphereColors.muted),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: SportSphereColors.muted),
              onPressed: () => _ctrl.clear(),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: SportSphereColors.electricBlue,
          unselectedLabelColor: SportSphereColors.muted,
          indicatorColor: SportSphereColors.electricBlue,
          tabs: const [
            Tab(icon: Icon(Icons.search_rounded, size: 18), text: 'Search'),
            Tab(icon: Icon(Icons.near_me_rounded, size: 18), text: 'Nearby Fans'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Search tab ─────────────────────────────────────────────────
          _SearchResultsList(
            query: _query,
            results: _results,
            loading: _loading,
            onTap: (r) {
              Navigator.pop(context);
              final handle = (r['handle'] as String? ?? '').replaceAll('@', '');
              final role = (r['role'] as String? ?? '').toLowerCase();
              final kind = (r['_kind'] as String? ?? '');
              if (kind == 'team' || role == 'team') {
                context.push('/team/$handle');
              } else if (kind == 'player' || role == 'player') {
                context.push('/player/$handle');
              } else if (role == 'fan' || role == '') {
                context.push('/profile/$handle');
              } else {
                context.push('/role/$role/$handle');
              }
            },
          ),
          // ── Nearby Fans tab ────────────────────────────────────────────
          const _NearbyFansTab(),
        ],
      ),
    );
  }
}

// ── Search results list ───────────────────────────────────────────────────────

class _SearchResultsList extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> results;
  final bool loading;
  final void Function(Map<String, dynamic>) onTap;

  const _SearchResultsList({
    required this.query,
    required this.results,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (query.length < 2) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded, color: SportSphereColors.muted, size: 48),
          SizedBox(height: 12),
          Text('Type to search fans, teams, players',
              style: TextStyle(color: SportSphereColors.muted)),
        ]),
      );
    }
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: SportSphereColors.electricBlue, strokeWidth: 2));
    }
    if (results.isEmpty) {
      return Center(child: Text('No results for "$query"',
          style: const TextStyle(color: SportSphereColors.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final r = results[i];
        final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
        final handle = '@${r['handle'] ?? ''}';
        final role = (r['role'] as String? ?? '').toLowerCase();
        final avatarUrl = r['avatar_url'] as String?;
        final roleColor = role == 'team' ? const Color(0xFF9B6DFF)
            : role == 'player' ? SportSphereColors.sportOrange
            : SportSphereColors.electricBlue;
        return ListTile(
          onTap: () => onTap(r),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            backgroundImage: (avatarUrl != null && avatarUrl.startsWith('http'))
                ? NetworkImage(avatarUrl) : null,
            child: (avatarUrl == null || !avatarUrl.startsWith('http'))
                ? Icon(_roleIcon(role), color: roleColor, size: 20)
                : null,
          ),
          title: Text(name.isEmpty ? handle : name,
              style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w600)),
          subtitle: Text('$handle  ·  ${_roleLabel(role)}',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
          trailing: Icon(_roleIcon(role), color: roleColor, size: 16),
        );
      },
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'team': return Icons.groups_rounded;
      case 'player': return Icons.sports_rounded;
      case 'coach': return Icons.manage_accounts_rounded;
      default: return Icons.person_rounded;
    }
  }

  String _roleLabel(String role) {
    if (role.isEmpty || role == 'fan') return 'Fan';
    return role[0].toUpperCase() + role.substring(1);
  }
}

// ── Nearby Fans tab ───────────────────────────────────────────────────────────

class _NearbyFansTab extends StatefulWidget {
  const _NearbyFansTab();
  @override State<_NearbyFansTab> createState() => _NearbyFansTabState();
}

class _NearbyFansTabState extends State<_NearbyFansTab> {
  List<Map<String, dynamic>> _nearby = [];
  bool _loading = false;
  bool _locationDenied = false;
  bool _shareEnabled = false;
  double? _myLat, _myLng;
  static const double _radiusKm = 10.0;

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles').select('latitude,longitude').eq('id', uid).maybeSingle();
      if (row != null && row['latitude'] != null) {
        setState(() {
          _myLat = (row['latitude'] as num).toDouble();
          _myLng = (row['longitude'] as num).toDouble();
          _shareEnabled = true;
        });
        _fetchNearby();
      }
    } catch (_) {}
  }

  Future<void> _enableSharing() async {
    setState(() => _loading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() { _locationDenied = true; _loading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10));

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client.from('profiles').update({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);
      }
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
        _shareEnabled = true;
        _loading = false;
      });
      _fetchNearby();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disableSharing() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('profiles').update({
      'latitude': null,
      'longitude': null,
      'location_updated_at': null,
    }).eq('id', uid);
    setState(() { _shareEnabled = false; _myLat = null; _myLng = null; _nearby = []; });
  }

  Future<void> _fetchNearby() async {
    if (_myLat == null || _myLng == null) return;
    setState(() => _loading = true);
    try {
      // Bounding box approximation: 1° lat ≈ 111km
      final latDelta = _radiusKm / 111.0;
      final lngDelta = _radiusKm / (111.0 * _cosLat(_myLat!));
      final uid = Supabase.instance.client.auth.currentUser?.id;

      var q = Supabase.instance.client
          .from('profiles')
          .select('id, handle, first_name, last_name, avatar_url, latitude, longitude')
          .gte('latitude', _myLat! - latDelta)
          .lte('latitude', _myLat! + latDelta)
          .gte('longitude', _myLng! - lngDelta)
          .lte('longitude', _myLng! + lngDelta)
          .not('latitude', 'is', null)
          .limit(50);

      final rows = List<Map<String, dynamic>>.from(await q as List);

      // Filter to radius and exclude self
      final filtered = rows.where((r) {
        if (r['id'] == uid) return false;
        final lat = (r['latitude'] as num?)?.toDouble();
        final lng = (r['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return false;
        return _distanceKm(_myLat!, _myLng!, lat, lng) <= _radiusKm;
      }).toList();

      // Sort by distance
      filtered.sort((a, b) {
        final da = _distanceKm(_myLat!, _myLng!,
            (a['latitude'] as num).toDouble(), (a['longitude'] as num).toDouble());
        final db = _distanceKm(_myLat!, _myLng!,
            (b['latitude'] as num).toDouble(), (b['longitude'] as num).toDouble());
        return da.compareTo(db);
      });

      if (mounted) setState(() { _nearby = filtered; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin(dLng / 2) * _sin(dLng / 2);
    return r * 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  }

  double _rad(double deg) => deg * 3.141592653589793 / 180;
  double _sin(double x) => x - x*x*x/6 + x*x*x*x*x/120;
  double _cos(double x) => 1 - x*x/2 + x*x*x*x/24;
  double _cosLat(double lat) => _cos(_rad(lat));
  double _sqrt(double x) => x <= 0 ? 0 : x < 1 ? (x + 1) / 2 : x;
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (y > 0) return 3.141592653589793 / 2;
    if (y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  double _atan(double x) {
    double s = x, t = x, n = 1;
    for (int i = 1; i < 8; i++) {
      n += 2; t *= -x * x; s += t / n;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;

    if (uid == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.near_me_rounded, color: SportSphereColors.muted, size: 48),
          const SizedBox(height: 16),
          const Text('Sign in to discover nearby fans',
              textAlign: TextAlign.center,
              style: TextStyle(color: SportSphereColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('See who supports the same team near you',
              textAlign: TextAlign.center,
              style: TextStyle(color: SportSphereColors.muted, fontSize: 13)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.push('/login'),
            style: FilledButton.styleFrom(backgroundColor: SportSphereColors.electricBlue),
            child: const Text('Sign In'),
          ),
        ]),
      ));
    }

    return Column(children: [
      // ── Location sharing toggle ─────────────────────────────────────────
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SportSphereColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _shareEnabled
                ? SportSphereColors.electricBlue.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_shareEnabled ? SportSphereColors.electricBlue : SportSphereColors.muted)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              _shareEnabled ? Icons.near_me_rounded : Icons.near_me_disabled_rounded,
              color: _shareEnabled ? SportSphereColors.electricBlue : SportSphereColors.muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _shareEnabled ? 'Location sharing ON' : 'Share your location',
              style: TextStyle(
                color: _shareEnabled ? SportSphereColors.electricBlue : SportSphereColors.white,
                fontWeight: FontWeight.w700, fontSize: 14,
              ),
            ),
            Text(
              _shareEnabled
                  ? 'Fans within ${_radiusKm.toInt()}km can see you'
                  : 'Discover fans near you',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 12),
            ),
          ])),
          Switch(
            value: _shareEnabled,
            onChanged: (v) => v ? _enableSharing() : _disableSharing(),
            activeColor: SportSphereColors.electricBlue,
          ),
        ]),
      ),

      if (_locationDenied)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SportSphereColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SportSphereColors.danger.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.location_off_rounded, color: SportSphereColors.danger, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Location permission denied. Enable in Settings.',
                style: TextStyle(color: SportSphereColors.danger, fontSize: 12))),
          ]),
        ),

      // ── Nearby fans list ────────────────────────────────────────────────
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(
              color: SportSphereColors.electricBlue, strokeWidth: 2))
          : !_shareEnabled
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_rounded, size: 56,
                        color: SportSphereColors.muted.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    const Text('Enable location to see nearby fans',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SportSphereColors.muted, fontSize: 14)),
                  ]),
                ))
              : _nearby.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded, size: 56,
                            color: SportSphereColors.muted.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('No fans found nearby',
                            style: TextStyle(color: SportSphereColors.white,
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Nobody within ${_radiusKm.toInt()}km has location sharing on yet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: SportSphereColors.muted, fontSize: 13)),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _fetchNearby,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh'),
                          style: OutlinedButton.styleFrom(foregroundColor: SportSphereColors.electricBlue),
                        ),
                      ]),
                    ))
                  : RefreshIndicator(
                      onRefresh: _fetchNearby,
                      color: SportSphereColors.electricBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _nearby.length,
                        itemBuilder: (_, i) {
                          final r = _nearby[i];
                          final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
                          final handle = '@${r['handle'] ?? ''}';
                          final avatarUrl = r['avatar_url'] as String?;
                          final lat = (r['latitude'] as num?)?.toDouble();
                          final lng = (r['longitude'] as num?)?.toDouble();
                          final dist = (_myLat != null && _myLng != null && lat != null && lng != null)
                              ? _distanceKm(_myLat!, _myLng!, lat, lng) : null;
                          final distLabel = dist == null ? ''
                              : dist < 1 ? '${(dist * 1000).round()}m away'
                              : '${dist.toStringAsFixed(1)}km away';

                          return ListTile(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/profile/${r['handle']}');
                            },
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: SportSphereColors.electricBlue.withValues(alpha: 0.15),
                              backgroundImage: (avatarUrl != null && avatarUrl.startsWith('http'))
                                  ? NetworkImage(avatarUrl) : null,
                              child: (avatarUrl == null || !avatarUrl.startsWith('http'))
                                  ? const Icon(Icons.person_rounded,
                                      color: SportSphereColors.electricBlue, size: 22)
                                  : null,
                            ),
                            title: Text(name.isEmpty ? handle : name,
                                style: const TextStyle(color: SportSphereColors.white,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('$handle  ·  $distLabel',
                                style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: SportSphereColors.electricBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: SportSphereColors.electricBlue.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.near_me_rounded,
                                  color: SportSphereColors.electricBlue, size: 14),
                            ),
                          );
                        },
                      ),
                    )),
    ]);
  }
}
