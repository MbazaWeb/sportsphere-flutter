import 'package:flutter/material.dart';

/// SportSphere Home > Spotlights
///
/// Mixed social feed:
/// - Image posts
/// - Video posts
/// - Polls
/// - Predictions
/// - Business
/// - Match/ticket
/// - Player
/// - Analysis
///
/// This widget intentionally contains no navigation shell.
/// The parent Home screen owns the fixed header/navigation.
class SportlightsTab extends StatefulWidget {
  const SportlightsTab({super.key});

  @override
  State<SportlightsTab> createState() => _SportlightsTabState();
}

class _SportlightsTabState extends State<SportlightsTab> {
  final ScrollController _scrollController = ScrollController();

  final List<_SpotlightItem> _items = const [
    _SpotlightItem(
      type: _SpotlightType.team,
      author: 'Young Africans',
      role: 'Official',
      age: '4d ago',
      asset: 'assets/images/reference_posts/spotlight_yanga.jpeg',
      likes: 0,
      comments: 56,
      shares: 78,
      accent: Color(0xFFFFC400),
      primaryAction: 'Follow',
      secondaryAction: 'Become Fan',
    ),

    _SpotlightItem(
      type: _SpotlightType.match,
      author: 'Tanzania Football Federation',
      role: 'Official',
      age: '4d ago',
      asset: 'assets/images/reference_posts/spotlight_tff.jpeg',
      likes: 34,
      comments: 12,
      shares: 8,
      accent: Color(0xFFFFC400),
      primaryAction: 'Buy Now',
      secondaryAction: 'Buy Ticket',
    ),

    _SpotlightItem(
      type: _SpotlightType.business,
      author: 'AzamSport',
      role: 'Verified',
      age: '4d ago',
      asset: 'assets/images/reference_posts/spotlight_azamsport.jpeg',
      likes: 128,
      comments: 32,
      shares: 16,
      accent: Color(0xFFFFB900),
      primaryAction: 'Buy Now',
      secondaryAction: 'Watch Online',
    ),

    _SpotlightItem(
      type: _SpotlightType.player,
      author: 'Clatous Chama',
      role: 'Player',
      age: '4d ago',
      asset: 'assets/images/reference_posts/spotlight_chama.jpeg',
      likes: 0,
      comments: 72,
      shares: 93,
      accent: Color(0xFFE31B23),
      primaryAction: 'Follow',
      secondaryAction: 'Become Fan',
    ),

    _SpotlightItem(
      type: _SpotlightType.analysis,
      author: 'Ali Kingu',
      role: 'Football Analyst',
      age: '4d ago',
      asset: 'assets/images/reference_posts/spotlight_analyst.jpeg',
      likes: 232,
      comments: 45,
      shares: 67,
      accent: Color(0xFF4D8F24),
      primaryAction: 'Follow',
      secondaryAction: 'View Analysis',
    ),

    _SpotlightItem(
      type: _SpotlightType.video,
      author: 'SportSphere Creator',
      role: 'Creator',
      age: 'Today',
      likes: 421,
      comments: 84,
      shares: 51,
      accent: Color(0xFF168CFF),
      primaryAction: 'Watch',
      secondaryAction: 'Follow',
    ),

    _SpotlightItem(
      type: _SpotlightType.poll,
      author: 'SportSphere Community',
      role: 'Community',
      age: 'Today',
      likes: 182,
      comments: 64,
      shares: 22,
      accent: Color(0xFF00A8FF),
      primaryAction: 'Vote',
      secondaryAction: 'Discuss',
    ),

    _SpotlightItem(
      type: _SpotlightType.prediction,
      author: 'SportSphere Predictions',
      role: 'Prediction',
      age: 'Today',
      likes: 205,
      comments: 37,
      shares: 29,
      accent: Color(0xFF7FD820),
      primaryAction: 'Predict',
      secondaryAction: 'View Match',
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF168CFF),
      backgroundColor: const Color(0xFF091522),
      onRefresh: () async {
        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );
        if (mounted) {
          setState(() {});
        }
      },
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          scrollbars: false,
        ),
        child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
        // Endless Spotlights feed.
        //
        // The existing reference posts are intentionally reused as the
        // current local feed dataset. Newest content starts at index 0,
        // and older content continues through the dataset cyclically.
        itemCount: null,
        itemBuilder: (context, index) {
          final item = _items[index % _items.length];

          return _SpotlightCard(
            item: item,
          );
        },
          ),
        ),
      );
  }
}

// ============================================================
// POST CARD
// ============================================================

class _SpotlightCard extends StatelessWidget {
  final _SpotlightItem item;

  const _SpotlightCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xD8071422),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.075),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x42000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthorHeader(item: item),

            const SizedBox(height: 12),

            _MediaArea(item: item),

            const SizedBox(height: 10),

            _EngagementRow(item: item),

            const SizedBox(height: 11),

            _ActionRow(item: item),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUTHOR
// ============================================================

class _AuthorHeader extends StatelessWidget {
  final _SpotlightItem item;

  const _AuthorHeader({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/sport_sphere_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                color: const Color(0xFF102033),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.author,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF168CFF),
                    size: 17,
                  ),

                  const SizedBox(width: 6),

                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.065),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        item.role,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              Text(
                '•  ${item.age}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () {},
          splashRadius: 22,
          icon: Icon(
            Icons.bookmark_border_rounded,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MEDIA / CONTENT
// ============================================================

class _MediaArea extends StatelessWidget {
  final _SpotlightItem item;

  const _MediaArea({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case _SpotlightType.poll:
        return const _PollContent();

      case _SpotlightType.prediction:
        return const _PredictionContent();

      case _SpotlightType.video:
        return _VideoContent(item: item);

      default:
        return _ImageContent(item: item);
    }
  }
}

class _ImageContent extends StatelessWidget {
  final _SpotlightItem item;

  const _ImageContent({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final asset = item.asset;

    if (asset == null) {
      return _GeneratedContent(
        item: item,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1.02,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _GeneratedContent(
              item: item,
            );
          },
        ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  final _SpotlightItem item;

  const _VideoContent({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 0.86,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GeneratedContent(item: item),

            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            const Positioned(
              left: 16,
              bottom: 16,
              child: _ContentLabel(
                text: 'VIDEO',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollContent extends StatelessWidget {
  const _PollContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF092B4A),
            Color(0xFF071421),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(0xFF168CFF),
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ContentLabel(text: 'POLL'),

          const SizedBox(height: 16),

          const Text(
            'Who will win the next Kariakoo Derby?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 18),

          _PollOption(
            label: 'Simba SC',
            percentage: 46,
          ),

          const SizedBox(height: 10),

          _PollOption(
            label: 'Young Africans',
            percentage: 42,
          ),

          const SizedBox(height: 10),

          _PollOption(
            label: 'Draw',
            percentage: 12,
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final String label;
  final int percentage;

  const _PollOption({
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF168CFF).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

class _PredictionContent extends StatelessWidget {
  const _PredictionContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF182E0E),
            Color(0xFF071421),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7FD820).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _ContentLabel(text: 'PREDICTION'),
              Spacer(),
              Icon(
                Icons.analytics_outlined,
                color: Color(0xFF7FD820),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PredictionTeam(
                name: 'SIMBA',
              ),
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _PredictionTeam(
                name: 'YANGA',
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '1  -  1',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionTeam extends StatelessWidget {
  final String name;

  const _PredictionTeam({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.shield_rounded,
          color: Colors.white70,
          size: 38,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// GENERATED FALLBACK CONTENT
// ============================================================

class _GeneratedContent extends StatelessWidget {
  final _SpotlightItem item;

  const _GeneratedContent({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF061321),
            Color.lerp(
              const Color(0xFF061321),
              item.accent,
              0.32,
            )!,
            const Color(0xFF02060D),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.type.icon,
              color: Colors.white,
              size: 58,
            ),

            const SizedBox(height: 12),

            Text(
              item.type.label.toUpperCase(),
              style: TextStyle(
                color: item.accent,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ENGAGEMENT
// ============================================================

class _EngagementRow extends StatelessWidget {
  final _SpotlightItem item;

  const _EngagementRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Engagement(
          icon: Icons.favorite_border_rounded,
          value: item.likes,
        ),

        const SizedBox(width: 22),

        _Engagement(
          icon: Icons.chat_bubble_outline_rounded,
          value: item.comments,
        ),

        const SizedBox(width: 22),

        _Engagement(
          icon: Icons.ios_share_rounded,
          value: item.shares,
        ),

        const Spacer(),

        const Icon(
          Icons.bookmark_border_rounded,
          color: Colors.white,
          size: 23,
        ),
      ],
    );
  }
}

class _Engagement extends StatelessWidget {
  final IconData icon;
  final int value;

  const _Engagement({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),

        if (value > 0) ...[
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// ACTIONS
// ============================================================

class _ActionRow extends StatelessWidget {
  final _SpotlightItem item;

  const _ActionRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: item.secondaryAction,
            icon: _secondaryIcon(item),
            color: item.accent,
            outlined: true,
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: _ActionButton(
            label: item.primaryAction,
            icon: _primaryIcon(item),
            color: item.accent,
          ),
        ),
      ],
    );
  }

  IconData _primaryIcon(_SpotlightItem item) {
    switch (item.type) {
      case _SpotlightType.match:
      case _SpotlightType.business:
        return Icons.shopping_cart_outlined;

      case _SpotlightType.video:
        return Icons.play_arrow_rounded;

      case _SpotlightType.poll:
        return Icons.how_to_vote_outlined;

      case _SpotlightType.prediction:
        return Icons.analytics_outlined;

      default:
        return Icons.person_add_alt_1_rounded;
    }
  }

  IconData _secondaryIcon(_SpotlightItem item) {
    switch (item.type) {
      case _SpotlightType.analysis:
        return Icons.analytics_outlined;

      case _SpotlightType.match:
        return Icons.confirmation_number_outlined;

      case _SpotlightType.business:
        return Icons.play_circle_outline_rounded;

      case _SpotlightType.video:
        return Icons.group_add_outlined;

      case _SpotlightType.poll:
        return Icons.forum_outlined;

      default:
        return Icons.group_add_outlined;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: outlined
              ? color.withValues(alpha: 0.75)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: outlined ? color : Colors.white,
            size: 19,
          ),

          const SizedBox(width: 7),

          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: outlined ? color : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMALL COMPONENTS
// ============================================================

class _ContentLabel extends StatelessWidget {
  final String text;

  const _ContentLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}


// ============================================================
// MODEL
// ============================================================

enum _SpotlightType {
  team,
  match,
  business,
  player,
  analysis,
  video,
  poll,
  prediction,
}

extension on _SpotlightType {
  String get label {
    switch (this) {
      case _SpotlightType.team:
        return 'Team';

      case _SpotlightType.match:
        return 'Match';

      case _SpotlightType.business:
        return 'Business';

      case _SpotlightType.player:
        return 'Player';

      case _SpotlightType.analysis:
        return 'Analysis';

      case _SpotlightType.video:
        return 'Video';

      case _SpotlightType.poll:
        return 'Poll';

      case _SpotlightType.prediction:
        return 'Prediction';
    }
  }

  IconData get icon {
    switch (this) {
      case _SpotlightType.team:
        return Icons.groups_rounded;

      case _SpotlightType.match:
        return Icons.stadium_rounded;

      case _SpotlightType.business:
        return Icons.storefront_rounded;

      case _SpotlightType.player:
        return Icons.person_rounded;

      case _SpotlightType.analysis:
        return Icons.analytics_rounded;

      case _SpotlightType.video:
        return Icons.play_circle_fill_rounded;

      case _SpotlightType.poll:
        return Icons.poll_rounded;

      case _SpotlightType.prediction:
        return Icons.insights_rounded;
    }
  }
}

class _SpotlightItem {
  final _SpotlightType type;
  final String author;
  final String role;
  final String age;
  final String? asset;
  final int likes;
  final int comments;
  final int shares;
  final Color accent;
  final String primaryAction;
  final String secondaryAction;

  const _SpotlightItem({
    required this.type,
    required this.author,
    required this.role,
    required this.age,
    this.asset,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.accent,
    required this.primaryAction,
    required this.secondaryAction,
  });
}


