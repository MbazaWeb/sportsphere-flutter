import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/commerce_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/friendly_error.dart';
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
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 40;

  /// Re-entrancy guard for the realtime-driven reload.
  bool _refreshingFromRealtime = false;

  /// Tracks whether we've seen the initial emission from the realtime stream
  /// (so we don't re-fetch on the loading→data transition that always fires
  /// when the listener is first attached).
  bool _sawInitialTick = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadMatches(initial: true);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Listen to the shared `scores-realtime` channel — whenever a Match row
  /// changes (admin save, external feed, etc.) we re-fetch the admin list.
  ///
  /// Called from `build` so riverpod auto-cleans the listener between rebuilds
  /// (avoids leaking subscriptions when the sheet is dismissed).
  void _listenToRealtime() {
    ref.listen(matchRealtimeTickProvider, (_, __) {
      if (!_sawInitialTick) {
        _sawInitialTick = true;
        return;
      }
      if (!_refreshingFromRealtime && mounted) {
        _refreshingFromRealtime = true;
        _loadMatches(initial: true).whenComplete(() {
          _refreshingFromRealtime = false;
        });
      }
    });
  }

  Future<void> _loadMatches({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _offset = 0;
      });
    }
    try {
      final rows = await _repo.listMatchesForAdmin(
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        if (initial) {
          _matches = rows;
        } else {
          // Defensive dedupe in case the page window overlaps (status changes
          // between fetches can shift rows).
          final seen = <String>{};
          _matches = [
            ..._matches,
            for (final r in rows)
              if (r['id'] != null && seen.add(r['id'].toString())) r,
          ];
        }
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    _offset += _pageSize;
    await _loadMatches(initial: false);
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
                    labelText: 'Minute (live)',
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
                const SizedBox(height: 8),
                // Quick link to add player stats for THIS match — passes the
                // matchId from parent context so the admin no longer has to
                // type it in (issue #1.30).
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(d, false);
                      _editPlayerStats(matchId: id);
                    },
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('Add player stats for this match'),
                  ),
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
        await _loadMatches(initial: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  /// Player stats editor.
  ///
  /// [matchId] is now passed from the parent context (the matches list /
  /// edit-match dialog) instead of requiring the admin to type it in.
  /// When called from the "Player stats" tab (no parent match context) we
  /// surface a dropdown of the matches loaded in this sheet so the admin can
  /// pick one with a tap.
  Future<void> _editPlayerStats({String? matchId}) async {
    final search = TextEditingController();
    List<Map<String, dynamic>> found = [];
    Map<String, dynamic>? selected;
    final goals = TextEditingController(text: '0');
    final assists = TextEditingController(text: '0');
    final saves = TextEditingController(text: '0');
    final minutes = TextEditingController(text: '90');
    final yellow = TextEditingController(text: '0');
    final red = TextEditingController(text: '0');
    String? chosenMatchId = matchId;

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
                  // Match picker — populated from the sheet's loaded matches
                  // (replaces the free-text "Match id (optional)" field).
                  DropdownButtonFormField<String>(
                    value: chosenMatchId,
                    dropdownColor: const Color(0xFF0C1A2A),
                    decoration: const InputDecoration(
                      labelText: 'Match',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: [
                      for (final m in _matches)
                        DropdownMenuItem<String>(
                          value: m['id']?.toString() ?? '',
                          child: Text(
                            '${m['homeTeam'] ?? '?'} vs ${m['awayTeam'] ?? '?'}',
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setLocal(() => chosenMatchId = v?.isEmpty == true ? null : v),
                  ),
                  const SizedBox(height: 8),
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
                          try {
                            final rows = await _repo.searchPlayers(q);
                            setLocal(() => found = rows);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))),
                              );
                            }
                          }
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
                    decoration:
                        const InputDecoration(labelText: 'Yellow cards'),
                  ),
                  TextField(
                    controller: red,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Red cards'),
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
                          matchId: chosenMatchId,
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
                            SnackBar(content: Text(friendlyError(e))),
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
    // Subscribe to the shared realtime channel the first time we build.
    // (Called here rather than in initState so [ref] is available.)
    _listenToRealtime();

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
                    'Playify Official · Live control',
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
            labelColor: PlayifyColors.electricBlue,
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
                        color: PlayifyColors.electricBlue,
                        onRefresh: () => _loadMatches(initial: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          // Make sure the RefreshIndicator is draggable even
                          // when the list is short.
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _matches.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _matches.length) {
                              if (!_hasMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      '— end of list —',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: TextButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.expand_more,
                                        size: 18),
                                    label: const Text('Load more'),
                                  ),
                                ),
                              );
                            }
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
                        // No parent match context here — open the dialog and
                        // let the admin pick a match from the dropdown (which
                        // is populated from the matches loaded above).
                        onPressed: () => _editPlayerStats(matchId: null),
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
