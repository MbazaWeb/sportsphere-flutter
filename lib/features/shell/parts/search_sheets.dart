part of '../app_shell.dart';

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
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
        });
      },
    );
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
    final results = _SearchData.search(_query);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: SportSphereColors.background.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: SportSphereColors.electricBlue
                          .withValues(alpha: 0.20),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 16,
                    ),
                    cursorColor: SportSphereColors.electricBlue,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: SportSphereColors.electricBlue,
                      ),
                      hintText:
                          'Search players, teams, fans, posts...',
                      hintStyle: TextStyle(
                        color: SportSphereColors.muted
                            .withValues(alpha: 0.82),
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _controller.clear,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: SportSphereColors.muted,
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
                    backgroundColor: Colors.transparent,
                    color: SportSphereColors.electricBlue,
                  ),
                ),

              Expanded(
                child: _query.isEmpty
                    ? const _SearchEmptyState()
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
                            for (final group in results)
                              _SearchGroup(group: group),
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

class _SearchGroup extends StatelessWidget {
  final _SearchGroupData group;

  const _SearchGroup({
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    if (group.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              group.title.toUpperCase(),
              style: const TextStyle(
                color: SportSphereColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),

          ...group.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SportSphereColors.surface2,
                        border: Border.all(
                          color: SportSphereColors.electricBlue
                              .withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        item.icon,
                        color: SportSphereColors.electricBlue,
                        size: 21,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SportSphereColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SportSphereColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SportSphereColors.muted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
              color: SportSphereColors.electricBlue
                  .withValues(alpha: 0.72),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search SportSphere',
              style: TextStyle(
                color: SportSphereColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Find players, teams, coaches, fans, analysts and posts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SportSphereColors.muted
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

class _MessageSheet extends StatelessWidget {
  const _MessageSheet();

  @override
  Widget build(BuildContext context) {
    return const _ActivitySheet(
      title: 'Messages',
      icon: Icons.mail_outline_rounded,
      items: [
        _ActivityItem(
          icon: Icons.person_rounded,
          title: 'Fan',
          subtitle: 'You have a new message from a fan.',
          time: '3m',
        ),
        _ActivityItem(
          icon: Icons.sports_soccer_rounded,
          title: 'Player',
          subtitle: 'You have a new message from a player.',
          time: '21m',
        ),
        _ActivityItem(
          icon: Icons.groups_rounded,
          title: 'Team',
          subtitle: 'A team sent you a new message.',
          time: '1h',
        ),
      ],
    );
  }
}

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
            color: SportSphereColors.background.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: SportSphereColors.electricBlue,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: SportSphereColors.white,
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
                          color: Colors.white.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: SportSphereColors.surface2,
                              ),
                              child: Icon(
                                item.icon,
                                color: SportSphereColors.electricBlue,
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
                                      color: SportSphereColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.subtitle,
                                    style: const TextStyle(
                                      color: SportSphereColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item.time,
                              style: const TextStyle(
                                color: SportSphereColors.muted,
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

class _SearchItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SearchGroupData {
  final String title;
  final List<_SearchItem> items;

  const _SearchGroupData({
    required this.title,
    required this.items,
  });
}

class _SearchData {
  static List<_SearchGroupData> search(String query) {
    final q = query.toLowerCase();

    if (q.isEmpty) {
      return const [];
    }

    final people = <_SearchItem>[
      const _SearchItem(
        title: 'Clatous Chama',
        subtitle: 'Player · Football',
        icon: Icons.person_rounded,
      ),
      const _SearchItem(
        title: 'Ali Kingu',
        subtitle: 'Football Analyst',
        icon: Icons.analytics_rounded,
      ),
      const _SearchItem(
        title: 'SportSphere Fan',
        subtitle: 'Fan',
        icon: Icons.person_outline_rounded,
      ),
    ].where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q);
    }).toList();

    final teams = <_SearchItem>[
      const _SearchItem(
        title: 'Simba SC',
        subtitle: 'Football Team',
        icon: Icons.groups_rounded,
      ),
      const _SearchItem(
        title: 'Young Africans SC',
        subtitle: 'Football Team',
        icon: Icons.groups_rounded,
      ),
    ].where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q);
    }).toList();

    final posts = <_SearchItem>[
      const _SearchItem(
        title: 'Football analysis',
        subtitle: 'Post · Match prediction and discussion',
        icon: Icons.article_rounded,
      ),
      const _SearchItem(
        title: 'Latest football action',
        subtitle: 'Post · SportSphere community',
        icon: Icons.feed_rounded,
      ),
    ].where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q);
    }).toList();

    return [
      _SearchGroupData(
        title: 'People',
        items: people,
      ),
      _SearchGroupData(
        title: 'Teams',
        items: teams,
      ),
      _SearchGroupData(
        title: 'Posts',
        items: posts,
      ),
    ];
  }
}
