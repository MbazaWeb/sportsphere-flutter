part of '../app_shell.dart';

// VpsRepository + VpsSupabaseCompat are re-exported via the parent
// app_shell.dart import chain (core/data/* imported there).

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _controller = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;

  bool _loading = false;

  String _query = '';

  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onChanged() {
    final query = _controller.text.trim();

    setState(() {
      _query = query;
    });

    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _results = [];
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        if (!mounted) return;
        _performSearch(query);
      },
    );
  }

  Future<void> _performSearch(String query) async {
    final results = await _SearchData.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: PlayifyColors.background.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: PlayifyColors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: PlayifyColors.black.withValues(alpha: 0.42),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PlayifyColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: PlayifyColors.white.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: PlayifyColors.electricBlue
                          .withValues(alpha: 0.20),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(
                      color: PlayifyColors.white,
                      fontSize: 16,
                    ),
                    cursorColor: PlayifyColors.electricBlue,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: PlayifyColors.electricBlue,
                      ),
                      hintText:
                          'Search players, teams, fans, posts...',
                      hintStyle: TextStyle(
                        color: PlayifyColors.muted
                            .withValues(alpha: 0.82),
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _controller.clear,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: PlayifyColors.muted,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: PlayifyColors.transparent,
                    color: PlayifyColors.electricBlue,
                  ),
                ),

              Expanded(
                child: _query.isEmpty
                    ? const _SearchEmptyState()
                    : _loading && _results.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PlayifyColors.electricBlue,
                            ),
                          )
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  'No results for "$_query"',
                                  style: TextStyle(
                                    color: PlayifyColors.muted
                                        .withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : ScrollConfiguration(
                                behavior: const _InvisibleScrollBehavior(),
                                child: ListView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    24,
                                  ),
                                  children: [
                                    for (final item in _results)
                                      _SearchResultTile(item: item),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SearchResultTile({required this.item});

  IconData get _icon {
    switch (item['type']) {
      case 'user':
        return Icons.person_rounded;
      case 'team':
        return Icons.groups_rounded;
      case 'post':
        return Icons.article_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          final route = item['route'] as String?;
          if (route != null && route.isNotEmpty) {
            context.push(route);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PlayifyColors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PlayifyColors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              if (item['avatar'] != null)
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(item['avatar'] as String),
                  backgroundColor: PlayifyColors.surface2,
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PlayifyColors.surface2,
                    border: Border.all(
                      color: PlayifyColors.electricBlue
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    _icon,
                    color: PlayifyColors.electricBlue,
                    size: 21,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayifyColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['subtitle'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayifyColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PlayifyColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchData {
  static Future<List<Map<String, dynamic>>> search(String q) async {
    if (q.trim().length < 2) return [];
    final query = q.trim().replaceAll('@', '');
    try {
      final raw = await const VpsRepository().searchAll(query, limit: 30);
      return raw.map((r) {
        final kind = r['_kind'] as String? ?? r['role'] as String? ?? 'user';
        final name = (r['first_name'] as String? ?? '') +
            ((r['last_name'] as String?)?.isNotEmpty == true ? ' ${r['last_name']}' : '');
        final handle = (r['handle'] as String?) ?? '';
        return {
          'type': kind,
          'id':   r['id'],
          'title': name.trim().isNotEmpty ? name.trim() : handle,
          'subtitle': kind == 'user' ? '@$handle' : (r['_subtitle'] ?? kind),
          'avatar': r['avatar_url'] ?? r['logoUrl'],
          'role':  r['role'] ?? kind,
          'route': kind == 'user' ? '/profile/$handle'
                 : kind == 'team' ? '/team/${handle.replaceAll('-','_')}'
                 : null,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 54,
              color: PlayifyColors.electricBlue
                  .withValues(alpha: 0.72),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Playify',
              style: TextStyle(
                color: PlayifyColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Find players, teams, coaches, fans, analysts and posts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PlayifyColors.muted
                    .withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageSheet extends StatefulWidget {
  final String? initialPeerId;
  final String? initialPeerName;
  final String? initialPeerHandle;
  const _MessageSheet({
    this.initialPeerId,
    this.initialPeerName,
    this.initialPeerHandle,
  });
  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  final _repo = MessagingRepository();
  final _search = TextEditingController();
  final _compose = TextEditingController();
  final _threadScroll = ScrollController();
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _thread = [];
  List<Map<String, dynamic>> _found = [];
  String? _peerId;
  String? _peerLabel;
  String? _peerHandle;
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    if (widget.initialPeerId != null) {
      // Open directly to the specified peer conversation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPeer(
          widget.initialPeerId!,
          widget.initialPeerName ?? 'Fan',
          handle: widget.initialPeerHandle,
        );
      });
    }
    _loadInbox();
  }

  @override
  void dispose() {
    _unsubscribe();
    _search.dispose();
    _compose.dispose();
    _threadScroll.dispose();
    super.dispose();
  }

  void _unsubscribe() {
    // Realtime is being migrated to a Soketi/VPS-managed channel. The
    // MessagingRepository.subscribeThread stub returns a no-op placeholder
    // (see messaging_repository.dart) so there is nothing to dispose here
    // — we just drop the reference and let GC clean it up.
    _channel = null;
  }

  Future<void> _loadInbox() async {
    setState(() => _loading = true);
    final rows = await _repo.listConversations();
    if (mounted) setState(() { _inbox = rows; _loading = false; });
  }

  Future<void> _openPeer(String peerId, String label, {String? handle}) async {
    _unsubscribe();
    setState(() {
      _peerId = peerId;
      _peerLabel = label;
      _peerHandle = handle;
      _loading = true;
      _found = [];
    });
    final rows = await _repo.threadWith(peerId);
    if (!mounted) return;
    setState(() {
      _thread = rows;
      _loading = false;
    });
    _channel = _repo.subscribeThread(
      peerId: peerId,
      onInsert: (row) {
        if (!mounted) return;
        final id = '${row['id']}';
        if (_thread.any((m) => '${m['id']}' == id)) return;
        setState(() => _thread = [..._thread, row]);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_threadScroll.hasClients) {
            _threadScroll.jumpTo(_threadScroll.position.maxScrollExtent);
          }
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_threadScroll.hasClients) {
        _threadScroll.jumpTo(_threadScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final peer = _peerId;
    final text = _compose.text.trim();
    if (peer == null || text.isEmpty) return;
    try {
      await _repo.send(peer, text);
      _compose.clear();
      // Realtime will append; optimistically if needed after short delay reload
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: BoxDecoration(
            color: PlayifyColors.background.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: PlayifyColors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PlayifyColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    if (_peerId != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: PlayifyColors.white70),
                        onPressed: () {
                          _unsubscribe();
                          setState(() {
                            _peerId = null;
                            _peerLabel = null;
                            _peerHandle = null;
                            _thread = [];
                          });
                          _loadInbox();
                        },
                      ),
                    Expanded(
                      child: Text(
                        _peerId == null
                            ? 'Messages'
                            : (_peerHandle != null && _peerHandle!.isNotEmpty
                                ? '${_peerLabel ?? 'Chat'}  ·  @$_peerHandle'
                                : (_peerLabel ?? 'Chat')),
                        style: const TextStyle(
                          color: PlayifyColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_peerId == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _search,
                    style: const TextStyle(color: PlayifyColors.white),
                    decoration: InputDecoration(
                      hintText: 'Search people to message',
                      hintStyle: const TextStyle(color: PlayifyColors.white38),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          final rows = await _repo.searchUsers(_search.text);
                          setState(() => _found = rows);
                        },
                      ),
                    ),
                    onSubmitted: (_) async {
                      final rows = await _repo.searchUsers(_search.text);
                      setState(() => _found = rows);
                    },
                  ),
                ),
                if (_found.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView(
                      children: [
                        for (final u in _found)
                          ListTile(
                            dense: true,
                            title: Text(
                              '${u['name'] ?? u['handle']}',
                              style: const TextStyle(color: PlayifyColors.white),
                            ),
                            subtitle: Text(
                              '@${u['handle']}',
                              style: const TextStyle(color: PlayifyColors.white54),
                            ),
                            onTap: () => _openPeer(
                              '${u['id']}',
                              '${u['name'] ?? u['handle']}',
                              handle: '${u['handle'] ?? ''}',
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _inbox.isEmpty
                          ? const Center(
                              child: Text(
                                'No conversations yet.\nSearch a user to start a DM.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: PlayifyColors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _inbox.length,
                              itemBuilder: (_, i) {
                                final m = _inbox[i];
                                final peer = '${m['peerId']}';
                                final name = '${m['peerName'] ?? peer}';
                                final handle = '${m['peerHandle'] ?? ''}';
                                final av = m['peerAvatar'] as String?;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF168CFF),
                                    backgroundImage: av != null && av.isNotEmpty
                                        ? NetworkImage(av)
                                        : null,
                                    child: av == null || av.isEmpty
                                        ? Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: const TextStyle(color: PlayifyColors.white),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      color: PlayifyColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    handle.isNotEmpty
                                        ? '@$handle · ${m['content'] ?? ''}'
                                        : '${m['content'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: PlayifyColors.white54),
                                  ),
                                  onTap: () => _openPeer(
                                    peer,
                                    name,
                                    handle: handle.isEmpty ? null : handle,
                                  ),
                                );
                              },
                            ),
                ),
              ] else ...[
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : ListView.builder(
                          controller: _threadScroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _thread.length,
                          itemBuilder: (_, i) {
                            final m = _thread[i];
                            final mine = m['senderId'] ==
                                VpsSupabaseCompat.client.auth.currentUser?.id;
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? PlayifyColors.electricBlue
                                          .withValues(alpha: 0.35)
                                      : PlayifyColors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${m['content']}',
                                  style: const TextStyle(color: PlayifyColors.white),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _compose,
                          style: const TextStyle(color: PlayifyColors.white),
                          decoration: const InputDecoration(
                            hintText: 'Message…',
                            hintStyle: TextStyle(color: PlayifyColors.white38),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded,
                            color: PlayifyColors.electricBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ActivitySheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_ActivityItem> items;

  const _ActivitySheet({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: BoxDecoration(
            color: PlayifyColors.background.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: PlayifyColors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PlayifyColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: PlayifyColors.electricBlue,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ScrollConfiguration(
                  behavior: const _InvisibleScrollBehavior(),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      20,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = items[index];

                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: PlayifyColors.white.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PlayifyColors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: PlayifyColors.surface2,
                              ),
                              child: Icon(
                                item.icon,
                                color: PlayifyColors.electricBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: PlayifyColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.subtitle,
                                    style: const TextStyle(
                                      color: PlayifyColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item.time,
                              style: const TextStyle(
                                color: PlayifyColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
