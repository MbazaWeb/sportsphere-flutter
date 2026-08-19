part of '../app_shell.dart';

class _FullScreenSearch extends StatefulWidget {
  const _FullScreenSearch();

  @override
  State<_FullScreenSearch> createState() => _FullScreenSearchState();
}

class _FullScreenSearchState extends State<_FullScreenSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _history = [
    'Simba SC',
    'Young Africans',
    'Premier League',
  ];

  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _controller.addListener(() {
      setState(() {
        _query = _controller.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: SportSphereColors.white,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: SportSphereColors.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: SportSphereColors.electricBlue
                              .withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SportSphereColors.electricBlue
                                .withValues(alpha: 0.08),
                            blurRadius: 20,
                          ),
                        ],
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
                          hintText: 'Search SportSphere',
                          hintStyle: TextStyle(
                            color: SportSphereColors.muted
                                .withValues(alpha: 0.8),
                          ),
                          suffixIcon: hasQuery
                              ? IconButton(
                                  onPressed: _controller.clear,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: SportSphereColors.muted,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  if (!hasQuery) ...[
                    const _SearchSectionTitle(
                      icon: Icons.history_rounded,
                      title: 'Recent searches',
                    ),
                    const SizedBox(height: 10),

                    ..._history.map(
                      (item) => _SearchHistoryItem(
                        text: item,
                        onTap: () {
                          _controller.text = item;
                          _controller.selection = TextSelection.collapsed(
                            offset: item.length,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    const _SearchSectionTitle(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Explore',
                    ),
                    const SizedBox(height: 12),

                    const _SearchSuggestion(
                      icon: Icons.person_rounded,
                      title: 'Players',
                      subtitle: 'Footballers, athletes and profiles',
                    ),
                    const _SearchSuggestion(
                      icon: Icons.groups_rounded,
                      title: 'Teams',
                      subtitle: 'Clubs, national teams and squads',
                    ),
                    const _SearchSuggestion(
                      icon: Icons.article_rounded,
                      title: 'Posts',
                      subtitle: 'Community posts and discussions',
                    ),
                    const _SearchSuggestion(
                      icon: Icons.play_circle_fill_rounded,
                      title: 'Videos',
                      subtitle: 'Football and sports videos',
                    ),
                    const _SearchSuggestion(
                      icon: Icons.image_rounded,
                      title: 'Images',
                      subtitle: 'Photos and visual content',
                    ),
                  ] else ...[
                    const _SearchSectionTitle(
                      icon: Icons.bolt_rounded,
                      title: 'Results',
                    ),
                    const SizedBox(height: 12),

                    _SearchResult(
                      icon: Icons.person_rounded,
                      title: _query,
                      subtitle: 'Player / Fan / Coach / Athlete',
                    ),

                    _SearchResult(
                      icon: Icons.groups_rounded,
                      title: '$_query Team',
                      subtitle: 'Team or club',
                    ),

                    _SearchResult(
                      icon: Icons.article_rounded,
                      title: 'Posts about $_query',
                      subtitle: 'Community posts',
                    ),

                    _SearchResult(
                      icon: Icons.play_circle_fill_rounded,
                      title: 'Videos about $_query',
                      subtitle: 'Highlighted videos',
                    ),

                    _SearchResult(
                      icon: Icons.image_rounded,
                      title: 'Images about $_query',
                      subtitle: 'Photos and media',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SearchSectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: SportSphereColors.electricBlue,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: SportSphereColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SearchHistoryItem extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SearchHistoryItem({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: const Icon(
        Icons.history_rounded,
        color: SportSphereColors.muted,
      ),
      title: Text(
        text,
        style: const TextStyle(
          color: SportSphereColors.white,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        Icons.north_west_rounded,
        color: SportSphereColors.muted,
        size: 18,
      ),
    );
  }
}

class _SearchSuggestion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SearchSuggestion({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SportSphereColors.electricBlue.withValues(alpha: 0.10),
          ),
          child: Icon(
            icon,
            color: SportSphereColors.electricBlue,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: SportSphereColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: SportSphereColors.muted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SearchResult({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.circular(18),
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
              color: SportSphereColors.electricBlue.withValues(alpha: 0.10),
            ),
            child: Icon(
              icon,
              color: SportSphereColors.electricBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SportSphereColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
          ),
        ],
      ),
    );
  }
}
