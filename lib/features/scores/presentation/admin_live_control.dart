import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/commerce_repository.dart';
import '../../../core/theme/colors.dart';
import '../data/scores_repository.dart';
import 'providers/scores_provider.dart';

Future<void> openAdminLiveControl(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071422),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _AdminLiveControlSheet(),
  ).then((_) {
    ref.invalidate(liveMatchesProvider);
    ref.invalidate(todayMatchesProvider);
    ref.invalidate(upcomingMatchesProvider);
    ref.invalidate(resultsProvider);
  });
}

class _AdminLiveControlSheet extends ConsumerStatefulWidget {
  const _AdminLiveControlSheet();

  @override
  ConsumerState<_AdminLiveControlSheet> createState() =>
      _AdminLiveControlSheetState();
}

class _AdminLiveControlSheetState extends ConsumerState<_AdminLiveControlSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _repo = const ScoresRepository();
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadMatches();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.listMatchesForAdmin();
      if (mounted) setState(() { _matches = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editMatch(Map<String, dynamic> m) async {
    final id = m['id']?.toString() ?? '';
    final homeCtrl = TextEditingController(text: '${m['homeScore'] ?? 0}');
    final awayCtrl = TextEditingController(text: '${m['awayScore'] ?? 0}');
    final minCtrl = TextEditingController(text: '${m['minute'] ?? 0}');
    String status = (m['status'] as String?) ?? 'scheduled';
    final statuses = [
      'scheduled',
      'live',
      'ht',
      'finished',
      'postponed',
      'cancelled',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF0C1A2A),
          title: Text(
            '${m['homeTeam']} vs ${m['awayTeam']}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: statuses.contains(status) ? status : 'scheduled',
                  dropdownColor: const Color(0xFF0C1A2A),
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in statuses)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
                TextField(
                  controller: homeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Home (${m['homeTeam']})',
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
                TextField(
                  controller: awayCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Away (${m['awayTeam']})',
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Minute (live)",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('+1 Home'),
                      onPressed: () => setLocal(() {
                        homeCtrl.text =
                            '${(int.tryParse(homeCtrl.text) ?? 0) + 1}';
                      }),
                    ),
                    ActionChip(
                      label: const Text('+1 Away'),
                      onPressed: () => setLocal(() {
                        awayCtrl.text =
                            '${(int.tryParse(awayCtrl.text) ?? 0) + 1}';
                      }),
                    ),
                    ActionChip(
                      label: const Text('Go LIVE'),
                      onPressed: () => setLocal(() => status = 'live'),
                    ),
                    ActionChip(
                      label: const Text('FT'),
                      onPressed: () => setLocal(() => status = 'finished'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Save live'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.updateMatchLive(
        matchId: id,
        homeScore: int.tryParse(homeCtrl.text) ?? 0,
        awayScore: int.tryParse(awayCtrl.text) ?? 0,
        status: status,
        minute: int.tryParse(minCtrl.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match updated · live')),
        );
        await _loadMatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editPlayerStats() async {
    final search = TextEditingController();
    List<Map<String, dynamic>> found = [];
    Map<String, dynamic>? selected;
    final goals = TextEditingController(text: '0');
    final assists = TextEditingController(text: '0');
    final saves = TextEditingController(text: '0');
    final minutes = TextEditingController(text: '90');
    final yellow = TextEditingController(text: '0');
    final red = TextEditingController(text: '0');
    String? matchId;

    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF0C1A2A),
          title: const Text('Player match stats',
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Search player',
                      labelStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          final q = search.text.trim();
                          if (q.isEmpty) return;
                          final rows = await _repo.searchPlayers(q);
                          setLocal(() => found = rows);
                        },
                      ),
                    ),
                  ),
                  if (found.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView(
                        children: [
                          for (final p in found)
                            ListTile(
                              dense: true,
                              title: Text(
                                '${p['name']}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${p['id']} · ${p['position'] ?? ''}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              selected: selected?['id'] == p['id'],
                              onTap: () => setLocal(() => selected = p),
                            ),
                        ],
                      ),
                    ),
                  if (selected != null)
                    Text(
                      'Selected: ${selected!['name']}',
                      style: const TextStyle(color: Color(0xFF22C55E)),
                    ),
                  TextField(
                    onChanged: (v) => matchId = v.trim().isEmpty ? null : v.trim(),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Match id (optional)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextField(
                    controller: goals,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Goals'),
                  ),
                  TextField(
                    controller: assists,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Assists'),
                  ),
                  TextField(
                    controller: saves,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Saves'),
                  ),
                  TextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Minutes'),
                  ),
                  TextField(
                    controller: yellow,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Yellow cards'),
                  ),
                  TextField(
                    controller: red,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Red cards'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      try {
                        await CommerceRepository().upsertPlayerMatchStat(
                          playerId: selected!['id'].toString(),
                          matchId: matchId,
                          goals: int.tryParse(goals.text) ?? 0,
                          assists: int.tryParse(assists.text) ?? 0,
                          saves: int.tryParse(saves.text) ?? 0,
                          minutes: int.tryParse(minutes.text) ?? 0,
                          yellowCards: int.tryParse(yellow.text) ?? 0,
                          redCards: int.tryParse(red.text) ?? 0,
                        );
                        if (context.mounted) {
                          Navigator.pop(d);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Player stats saved')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.sensors, color: Color(0xFFE31B23)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SportSphere Official · Live control',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: SportSphereColors.electricBlue,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Matches'),
              Tab(text: 'Player stats'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadMatches,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _matches.length,
                          itemBuilder: (_, i) {
                            final m = _matches[i];
                            final st = '${m['status'] ?? ''}';
                            final score =
                                '${m['homeScore'] ?? '-'} - ${m['awayScore'] ?? '-'}';
                            return Card(
                              color: const Color(0xFF0C1A2A),
                              child: ListTile(
                                title: Text(
                                  '${m['homeTeam']} vs ${m['awayTeam']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '$st · $score · ${m['id']}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                                trailing: const Icon(Icons.edit,
                                    color: Colors.white70, size: 18),
                                onTap: () => _editMatch(m),
                              ),
                            );
                          },
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Search a player and enter match line stats. Profile Stats tab updates from PlayerMatchStat.',
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _editPlayerStats,
                        icon: const Icon(Icons.person_search_rounded),
                        label: const Text('Update player stats'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
