import '../../../core/data/vps_repository.dart';
import '../../../../core/data/vps_supabase_compat.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/admin/app_admin.dart';
import '../../../../core/theme/colors.dart';
import '../../presentation/edit_profile_sheet.dart'
    show showEntityEditSheet, EntityType;

// ══════════════════════════════════════════════════════════════════════════════
// COMPETITION PROFILE VIEW  —  data-driven (#5.5)
// Previously a hardcoded stub. Now loads a Competition row from Supabase by
// `competitionId` (preferred) or `handle` (slug), renders header + tabs, and
// exposes an admin-only "Edit Profile" entry that opens EntityEditSheet.
// ══════════════════════════════════════════════════════════════════════════════

class CompetitionProfileView extends StatefulWidget {
  const CompetitionProfileView({super.key, this.competitionId, this.handle});

  /// Competition row id (e.g. "league-123"). When null, [handle] is used.
  final String? competitionId;
  /// Slug or display handle used to look up the Competition row when the id
  /// is unknown (mirrors the lookup strategy used elsewhere in the app).
  final String? handle;

  @override
  State<CompetitionProfileView> createState() => _CompetitionProfileViewState();
}

class _CompetitionProfileViewState extends State<CompetitionProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _comp;
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final sb = VpsSupabaseCompat.client;
    try {
      Map<String, dynamic>? row;
      // Preferred: lookup by id.
      final id = widget.competitionId;
      if (id != null && id.isNotEmpty) {
        try {
          final r1 = await const VpsRepository().get<Map<String,dynamic>>('/v1/admin/leagues');
          final leagues = (r1.data?['leagues'] as List? ?? []).cast<Map<String,dynamic>>();
          row = leagues.where((l) => l['id'] == id).firstOrNull;
        } catch (e) {
          debugPrint('competition load by id: $e');
        }
      }
      // Fallback: lookup by slug / handle.
      if (row == null) {
        final key = (widget.handle ?? '').replaceAll('@', '').trim();
        if (key.isNotEmpty) {
          try {
            row = await sb
                // competition from VPS
                .select()
                .or('slug.eq.$key,name.ilike.%$key%')
                .limit(1)
                .maybeSingle();
          } catch (e) {
            debugPrint('competition load by slug: $e');
          }
          if (row == null) {
            try {
              final rows = await sb
                  // league from VPS
                  .select()
                  .or('slug.eq.$key,name.ilike.%$key%')
                  .limit(1);
              if ((rows as List).isNotEmpty) {
                row = Map<String, dynamic>.from(rows.first as Map);
              }
            } catch (e) {
              debugPrint('league load by slug: $e');
            }
          }
        }
      }
      if (row == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Competition not found';
          });
        }
        return;
      }

      // Load related matches (by league name or season).
      List<Map<String, dynamic>> matches = [];
      try {
        final name = (row['name'] ?? '').toString();
        if (name.isNotEmpty) {
          final mRows = await sb
              // matches now from VPS
              .select()
              .ilike('league', '%$name%')
              .order('kickoffAt', ascending: false)
              .limit(50);
          matches = List<Map<String, dynamic>>.from(mRows as List);
        }
      } catch (e) {
        debugPrint('competition matches load: $e');
      }

      if (mounted) {
        setState(() {
          _comp = row;
          _matches = matches;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  String _str(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppAdmin.isSessionAdmin;
    return Scaffold(
      backgroundColor: PlayifyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: PlayifyColors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      _loading
                          ? 'Loading…'
                          : (_str(_comp?['name']).isEmpty
                              ? 'Competition'
                              : _str(_comp?['name'])),
                      style: const TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: PlayifyColors.white),
                    onPressed: () => _showMore(context, isAdmin),
                  ),
                ],
              ),
            ),
            // ── Identity card ─────────────────────────────────────
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    color: PlayifyColors.electricBlue, strokeWidth: 2),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style:
                        const TextStyle(color: PlayifyColors.muted)),
              )
            else ...[
              _IdentityCard(comp: _comp!),
              TabBar(
                controller: _tab,
                labelColor: PlayifyColors.white,
                unselectedLabelColor: PlayifyColors.muted,
                indicatorColor: const Color(0xFFFFD700),
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Fixtures'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _AboutTab(comp: _comp!),
                    _StatsTab(comp: _comp!, matches: _matches),
                    _FixturesTab(matches: _matches),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMore(BuildContext context, bool isAdmin) {
    if (_comp == null) return;
    final id = _str(_comp!['id']);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PlayifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            if (isAdmin && id.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: PlayifyColors.electricBlue),
                title: const Text('Edit Profile',
                    style: TextStyle(color: PlayifyColors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await showEntityEditSheet(
                    context,
                    entityType: EntityType.competition,
                    entityId: id,
                    initialData: _comp!,
                  );
                  if (mounted) _load();
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: PlayifyColors.white),
              title: const Text('Share Profile',
                  style: TextStyle(color: PlayifyColors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Identity card ──────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.comp});

  final Map<String, dynamic> comp;

  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    final name = _s(comp['name']);
    final logo = _s(comp['logoUrl'] ?? comp['logo_url']);
    final season = _s(comp['season']);
    final sport = _s(comp['sportSlug'] ?? comp['sport_slug'] ?? 'football');
    final country = _s(comp['country']);
    final compType = _s(comp['competitionType'] ?? comp['competition_type'] ?? comp['type']);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: logo.isNotEmpty
                ? Image.network(
                    logo,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                      child: const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD700), size: 32),
                    ),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Color(0xFFFFD700), size: 32),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      name.isEmpty ? 'Competition' : name,
                      style: const TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFFFFD700), size: 16),
                ]),
                const SizedBox(height: 4),
                if (season.isNotEmpty)
                  Text('Season: $season',
                      style: const TextStyle(
                          color: PlayifyColors.muted, fontSize: 13)),
                if (sport.isNotEmpty)
                  Text('Sport: ${_labelForSport(sport)}',
                      style: const TextStyle(
                          color: PlayifyColors.muted, fontSize: 13)),
                if (country.isNotEmpty)
                  Text('Country: $country',
                      style: const TextStyle(
                          color: PlayifyColors.muted, fontSize: 13)),
                if (compType.isNotEmpty)
                  Text('Type: $compType',
                      style: const TextStyle(
                          color: PlayifyColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _labelForSport(String slug) {
    switch (slug.toLowerCase()) {
      case 'football':
      case 'soccer':
        return 'Football';
      case 'basketball':
        return 'Basketball';
      case 'rugby':
        return 'Rugby';
      case 'cricket':
        return 'Cricket';
      case 'tennis':
        return 'Tennis';
      default:
        return slug[0].toUpperCase() + slug.substring(1);
    }
  }
}

// ── About tab ─────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.comp});

  final Map<String, dynamic> comp;

  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    final fields = <(IconData, String, String)>[
      (
        Icons.sports_soccer_rounded,
        'Sport',
        _s(comp['sportSlug'] ?? comp['sport_slug'] ?? 'football'),
      ),
      (
        Icons.calendar_today_rounded,
        'Season',
        _s(comp['season']),
      ),
      (
        Icons.category_rounded,
        'Type',
        _s(comp['competitionType'] ??
            comp['competition_type'] ??
            comp['type']),
      ),
      (
        Icons.place_rounded,
        'Country',
        _s(comp['country']),
      ),
      (
        Icons.flag_outlined,
        'Format',
        _s(comp['competitionFormat'] ?? comp['competition_format']),
      ),
      (
        Icons.layers_rounded,
        'Level',
        _s(comp['competitionLevel'] ?? comp['competition_level']),
      ),
    ].where((f) => f.$3.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        const Text('About',
            style: TextStyle(
                color: PlayifyColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF071422),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              for (final f in fields) ...[
                Row(children: [
                  Icon(f.$1, color: PlayifyColors.electricBlue, size: 18),
                  const SizedBox(width: 10),
                  Text(f.$2,
                      style: const TextStyle(
                          color: PlayifyColors.muted, fontSize: 13)),
                  const Spacer(),
                  Text(f.$3,
                      style: const TextStyle(
                          color: PlayifyColors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
                if (f != fields.last)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.comp, required this.matches});

  final Map<String, dynamic> comp;
  final List<Map<String, dynamic>> matches;

  @override
  Widget build(BuildContext context) {
    final total = matches.length;
    final finished = matches
        .where((m) =>
            '${m['status']}'.toLowerCase() == 'finished' ||
            '${m['status']}'.toLowerCase() == 'ft' ||
            '${m['status']}'.toLowerCase() == 'completed')
        .length;
    final live = matches
        .where((m) => '${m['status']}'.toLowerCase() == 'live')
        .length;
    final upcoming = matches
        .where((m) =>
            '${m['status']}'.toLowerCase() == 'upcoming' ||
            '${m['status']}'.toLowerCase() == 'scheduled')
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        const Text('Stats',
            style: TextStyle(
                color: PlayifyColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _StatTile('Total matches', '$total', Icons.sports_soccer_rounded,
                PlayifyColors.electricBlue),
            _StatTile('Finished', '$finished', Icons.check_circle_outline,
                PlayifyColors.sportGreen),
            _StatTile('Live', '$live', Icons.sensors_rounded,
                const Color(0xFFE31B23)),
            _StatTile('Upcoming', '$upcoming', Icons.schedule_rounded,
                PlayifyColors.sportOrange),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, this.color);

  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                Text(label,
                    style: const TextStyle(
                        color: PlayifyColors.muted, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
}

// ── Fixtures tab ──────────────────────────────────────────────────────────────

class _FixturesTab extends StatelessWidget {
  const _FixturesTab({required this.matches});

  final List<Map<String, dynamic>> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Text('No fixtures yet',
            style: TextStyle(color: PlayifyColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: matches.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, color: Colors.white.withValues(alpha: 0.06)),
      itemBuilder: (_, i) {
        final m = matches[i];
        final home = m['homeTeam'] ?? '';
        final away = m['awayTeam'] ?? '';
        final hs = m['homeScore'] ?? 0;
        final as = m['awayScore'] ?? 0;
        final status = (m['status'] ?? 'upcoming').toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text('$home',
                    style: const TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PlayifyColors.electricBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$hs - $as',
                        style: const TextStyle(
                            color: PlayifyColors.electricBlue,
                            fontWeight: FontWeight.w800)),
                    Text(status,
                        style: const TextStyle(
                            color: PlayifyColors.muted, fontSize: 10)),
                  ],
                ),
              ),
              Expanded(
                child: Text('$away',
                    style: const TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      },
    );
  }
}
