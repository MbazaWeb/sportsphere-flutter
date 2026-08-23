import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/admin/app_admin.dart';
import '../../../../core/theme/colors.dart';
import '../../presentation/edit_profile_sheet.dart'
    show showEntityEditSheet, EntityType;

// ══════════════════════════════════════════════════════════════════════════════
// COACH PROFILE VIEW  —  data-driven (#5.6)
// Previously a hardcoded stub. Now loads a Coach row from Supabase by
// `coachId` (preferred) or `handle` (slug), renders header + tabs, and
// exposes an admin-only "Edit Profile" entry that opens EntityEditSheet.
// ══════════════════════════════════════════════════════════════════════════════

class CoachProfileView extends StatefulWidget {
  /// Coach row id (e.g. "coach-123"). When null, [handle] is used.
  const CoachProfileView({super.key, this.coachId, this.handle});
  final String? coachId;
  /// Slug or display handle used to look up the Coach row when the id
  /// is unknown.
  final String? handle;


  @override
  State<CoachProfileView> createState() => _CoachProfileViewState();
}

class _CoachProfileViewState extends State<CoachProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic>? _coach;
  Map<String, dynamic>? _team;
  List<Map<String, dynamic>> _players = [];
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
    final sb = Supabase.instance.client;
    try {
      Map<String, dynamic>? row;
      final id = widget.coachId;
      if (id != null && id.isNotEmpty) {
        try {
          row = await sb.from('Coach').select().eq('id', id).maybeSingle();
        } catch (e) {
          debugPrint('coach load by id: $e');
        }
      }
      if (row == null) {
        final key = (widget.handle ?? '').replaceAll('@', '').trim();
        if (key.isNotEmpty) {
          try {
            row = await sb
                .from('Coach')
                .select()
                .or('slug.eq.$key,name.ilike.%$key%')
                .limit(1)
                .maybeSingle();
          } catch (e) {
            debugPrint('coach load by slug: $e');
          }
        }
      }
      if (row == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Coach not found';
          });
        }
        return;
      }

      // Load linked Team (for club name display).
      Map<String, dynamic>? team;
      final teamId = row['teamId']?.toString();
      if (teamId != null && teamId.isNotEmpty) {
        try {
          team = await sb.from('Team').select().eq('id', teamId).maybeSingle();
        } catch (e) {
          debugPrint('coach team load: $e');
        }
      }

      // Load players in the same team (squad overview).
      List<Map<String, dynamic>> players = [];
      if (teamId != null && teamId.isNotEmpty) {
        try {
          final rows = await sb
              .from('Player')
              .select()
              .eq('teamId', teamId)
              .order('shirtNumber')
              .limit(50);
          players = List<Map<String, dynamic>>.from(rows as List);
        } catch (e) {
          debugPrint('coach players load: $e');
        }
      }

      if (mounted) {
        setState(() {
          _coach = row;
          _team = team;
          _players = players;
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
      backgroundColor: SportSphereColors.background,
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
                        color: SportSphereColors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      _loading ? 'Loading…' : (_str(_coach?['name']).isEmpty ? 'Coach' : _str(_coach?['name'])),
                      style: const TextStyle(
                        color: SportSphereColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: SportSphereColors.white),
                    onPressed: () => _showMore(context, isAdmin),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    color: SportSphereColors.electricBlue, strokeWidth: 2),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    style:
                        const TextStyle(color: SportSphereColors.muted)),
              )
            else ...[
              _IdentityCard(coach: _coach!, team: _team),
              TabBar(
                controller: _tab,
                labelColor: SportSphereColors.white,
                unselectedLabelColor: SportSphereColors.muted,
                indicatorColor: const Color(0xFF9B6DFF),
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Squad'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _AboutTab(coach: _coach!, team: _team),
                    _StatsTab(coach: _coach!),
                    _SquadTab(players: _players),
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
    if (_coach == null) return;
    final id = _str(_coach!['id']);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SportSphereColors.surface,
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
                    color: SportSphereColors.electricBlue),
                title: const Text('Edit Profile',
                    style: TextStyle(color: SportSphereColors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await showEntityEditSheet(
                    context,
                    entityType: EntityType.coach,
                    entityId: id,
                    initialData: _coach!,
                  );
                  if (mounted) _load();
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: SportSphereColors.white),
              title: const Text('Share Profile',
                  style: TextStyle(color: SportSphereColors.white)),
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
  const _IdentityCard({required this.coach, this.team});
  final Map<String, dynamic> coach;
  final Map<String, dynamic>? team;

  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    final name = _s(coach['name']);
    final photo = _s(coach['photoUrl']);
    final role = _s(coach['role']).replaceAll('_', ' ');
    final nationality = _s(coach['nationality']);
    final teamName = _s(team?['name']);

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
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF9B6DFF).withValues(alpha: 0.15),
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? const Icon(Icons.sports_rounded,
                    color: Color(0xFF9B6DFF), size: 28)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      name.isEmpty ? 'Coach' : name,
                      style: const TextStyle(
                        color: SportSphereColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (coach['verified'] == true)
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFFFFD700), size: 16),
                ]),
                const SizedBox(height: 4),
                if (role.isNotEmpty)
                  Text('Role: ${_capitalise(role)}',
                      style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 13)),
                if (teamName.isNotEmpty)
                  Text('Team: $teamName',
                      style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 13)),
                if (nationality.isNotEmpty)
                  Text('Nationality: $nationality',
                      style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ── About tab ─────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.coach, this.team});
  final Map<String, dynamic> coach;
  final Map<String, dynamic>? team;

  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    final fields = <(IconData, String, String)>[
      (Icons.work_outline_rounded, 'Role', _s(coach['role']).replaceAll('_', ' ')),
      (Icons.groups_rounded, 'Team', _s(team?['name'])),
      (Icons.place_rounded, 'Nationality', _s(coach['nationality'])),
      (Icons.calendar_today_rounded, 'Date of birth', _s(coach['dateOfBirth'])),
      (Icons.sports_soccer_rounded, 'Sport', _s(coach['sportSlug'] ?? coach['sport_slug'] ?? 'football')),
    ].where((f) => f.$3.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        const Text('About',
            style: TextStyle(
                color: SportSphereColors.white,
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
                  Icon(f.$1, color: SportSphereColors.electricBlue, size: 18),
                  const SizedBox(width: 10),
                  Text(f.$2,
                      style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 13)),
                  const Spacer(),
                  Flexible(
                    child: Text(f.$3,
                        style: const TextStyle(
                            color: SportSphereColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis),
                  ),
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
  const _StatsTab({required this.coach});
  final Map<String, dynamic> coach;

  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    // Coaches don't yet have direct stats tables — surface metadata fields.
    final tiles = <_StatTile>[
      _StatTile(
        'Active',
        coach['isActive'] == true ? 'Yes' : 'No',
        Icons.check_circle_outline,
        SportSphereColors.sportGreen,
      ),
      _StatTile(
        'Verified',
        coach['verified'] == true ? 'Yes' : 'No',
        Icons.verified_outlined,
        const Color(0xFFFFD700),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        const Text('Stats',
            style: TextStyle(
                color: SportSphereColors.white,
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
          children: tiles,
        ),
        const SizedBox(height: 16),
        const Text('Note',
            style: TextStyle(
                color: SportSphereColors.muted,
                fontSize: 12)),
        const SizedBox(height: 4),
        const Text(
          'Detailed coach statistics (matches managed, win rate, trophies) '
          'will appear here once the analytics pipeline populates them.',
          style: const TextStyle(color: SportSphereColors.muted, fontSize: 12),
        ),
        if (_s(coach['metadata']).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Metadata: ${_s(coach['metadata'])}',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
        ],
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
                        color: SportSphereColors.muted, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
}

// ── Squad tab ─────────────────────────────────────────────────────────────────

class _SquadTab extends StatelessWidget {
  const _SquadTab({required this.players});
  final List<Map<String, dynamic>> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text('No squad members visible',
            style: TextStyle(color: SportSphereColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: players.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, color: Colors.white.withValues(alpha: 0.06)),
      itemBuilder: (_, i) {
        final p = players[i];
        final name = p['name'] ?? '';
        final position = p['position'] ?? '';
        final shirt = p['shirtNumber'];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: SportSphereColors.sportOrange.withValues(alpha: 0.15),
            child: Text(
              shirt == null ? '?' : '$shirt',
              style: const TextStyle(
                  color: SportSphereColors.sportOrange,
                  fontWeight: FontWeight.w800),
            ),
          ),
          title: Text('$name',
              style: const TextStyle(
                  color: SportSphereColors.white, fontWeight: FontWeight.w600)),
          subtitle: Text('$position',
              style: const TextStyle(
                  color: SportSphereColors.muted, fontSize: 12)),
        );
      },
    );
  }
}
