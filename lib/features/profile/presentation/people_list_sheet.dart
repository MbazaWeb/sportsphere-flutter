import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/social_graph.dart';

enum PeopleListKind { fans, followers, following }

class PeopleListSheet extends StatefulWidget {
  const PeopleListSheet({super.key, required this.userId, required this.handle, required this.kind});
  final String userId;
  final String handle;
  final PeopleListKind kind;

  @override
  State<PeopleListSheet> createState() => _PeopleListSheetState();
}

class _PeopleListSheetState extends State<PeopleListSheet> {
  final _graph = const SocialGraph();
  late Future<List<GraphPerson>> _future;

  /// Local cache of the latest fetched people — used for optimistic count
  /// updates (#7.10) so the header badge can be refreshed without a full
  /// refetch round-trip.
  List<GraphPerson> _people = const [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GraphPerson>> _load() async {
    final list = await _loadRaw();
    if (mounted) setState(() => _people = list);
    return list;
  }

  Future<List<GraphPerson>> _loadRaw() {
    switch (widget.kind) {
      case PeopleListKind.fans:
        return _graph.fans(widget.userId);
      case PeopleListKind.followers:
        return _graph.followers(widget.userId);
      case PeopleListKind.following:
        return _graph.following(widget.userId);
    }
  }

  String get _title => switch (widget.kind) {
        PeopleListKind.fans => 'Fans',
        PeopleListKind.followers => 'Followers',
        PeopleListKind.following => 'Following',
      };

  /// #7.9 — Toggles follow state for [p] in both directions.
  /// #7.10 — Updates the local list optimistically and then refetches from
  /// the server so the count badge stays in sync.
  Future<void> _toggleFollow(GraphPerson p) async {
    final next = !p.youFollow;
    // Optimistic: flip the local flag immediately.
    setState(() {
      _people = [
        for (final it in _people)
          if (it.id == p.id) it.copyWith(youFollow: next) else it,
      ];
    });
    try {
      await _graph.follow(p.id, on: next);
    } catch (e) {
      debugPrint('[PeopleListSheet] follow(${p.id}, on=$next) failed: $e');
      // Revert on failure.
      if (mounted) {
        setState(() {
          _people = [
            for (final it in _people)
              if (it.id == p.id) it.copyWith(youFollow: !next) else it,
          ];
        });
      }
      return;
    }
    // Refetch from server to get accurate counts and any other drift.
    if (mounted) setState(() => _future = _load());
  }

  /// #7.9 — Toggles fan state for [p] in both directions.
  /// #7.10 — Updates the local list optimistically and then refetches.
  Future<void> _toggleFan(GraphPerson p) async {
    final next = !p.youFan;
    setState(() {
      _people = [
        for (final it in _people)
          if (it.id == p.id) it.copyWith(youFan: next) else it,
      ];
    });
    try {
      await _graph.fan(p.id, on: next);
    } catch (e) {
      debugPrint('[PeopleListSheet] fan(${p.id}, on=$next) failed: $e');
      if (mounted) {
        setState(() {
          _people = [
            for (final it in _people)
              if (it.id == p.id) it.copyWith(youFan: !next) else it,
          ];
        });
      }
      return;
    }
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + live count badge (#7.10): reflects the current list
            // length so it updates immediately after every toggle.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_people.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<GraphPerson>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      _people.isEmpty) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  // Prefer the cached list when the future is still loading
                  // so the user doesn't see a spinner flash after a toggle.
                  final people = snap.data ?? _people;
                  if (people.isEmpty) {
                    return const Center(
                        child: Text('No one here yet',
                            style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (_, i) {
                      final p = people[i];
                      final allowFan = _graph.canFan(p.role);
                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/role/${p.role}/${p.handle}');
                        },
                        leading: CircleAvatar(
                          backgroundImage: p.avatarUrl != null
                              ? NetworkImage(p.avatarUrl!)
                              : null,
                          child: p.avatarUrl == null
                              ? Text(p.name.isNotEmpty ? p.name[0] : '?')
                              : null,
                        ),
                        title: Text(p.name),
                        subtitle: Text('@${p.handle} · ${p.role}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // #7.9 — Fan button now toggles both ways.
                            if (allowFan)
                              TextButton(
                                onPressed: () => _toggleFan(p),
                                style: TextButton.styleFrom(
                                  foregroundColor: p.youFan
                                      ? const Color(0xFFFFC107)
                                      : Colors.white,
                                ),
                                child: Text(p.youFan ? 'Unfan' : 'Fan'),
                              ),
                            // #7.9 — Follow button now toggles both ways.
                            IconButton(
                              tooltip: p.youFollow
                                  ? 'You follow — tap to unfollow'
                                  : 'Follow',
                              onPressed: () => _toggleFollow(p),
                              icon: Icon(p.youFollow
                                  ? Icons.check
                                  : Icons.person_add_alt_1_rounded),
                            ),
                          ],
                        ),
                      );
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

void showPeopleList(BuildContext context, {required String userId, required String handle, required PeopleListKind kind}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF071422),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => PeopleListSheet(userId: userId, handle: handle, kind: kind),
  );
}
