import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/social_graph.dart';

enum PeopleListKind { fans, followers, following }

class PeopleListSheet extends StatefulWidget {
  final String userId;
  final String handle;
  final PeopleListKind kind;
  const PeopleListSheet({super.key, required this.userId, required this.handle, required this.kind});

  @override
  State<PeopleListSheet> createState() => _PeopleListSheetState();
}

class _PeopleListSheetState extends State<PeopleListSheet> {
  final _graph = SocialGraph();
  late Future<List<GraphPerson>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GraphPerson>> _load() {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<GraphPerson>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final people = snap.data ?? [];
                  if (people.isEmpty) {
                    return const Center(child: Text('No one here yet', style: TextStyle(color: Colors.white54)));
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
                          backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                          child: p.avatarUrl == null ? Text(p.name.isNotEmpty ? p.name[0] : '?') : null,
                        ),
                        title: Text(p.name),
                        subtitle: Text('@${p.handle} · ${p.role}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (allowFan)
                              TextButton(
                                onPressed: p.youFan
                                    ? null
                                    : () async {
                                        await _graph.fan(p.id, on: true);
                                        setState(() => _future = _load());
                                      },
                                child: Text(p.youFan ? "You're a fan" : 'Fan'),
                              ),
                            IconButton(
                              tooltip: p.youFollow ? 'You follow' : 'Follow',
                              onPressed: p.youFollow
                                  ? null
                                  : () async {
                                      await _graph.follow(p.id, on: true);
                                      setState(() => _future = _load());
                                    },
                              icon: Icon(p.youFollow ? Icons.check : Icons.add),
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
