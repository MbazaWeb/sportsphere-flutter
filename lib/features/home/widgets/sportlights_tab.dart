import 'package:flutter/material.dart';
import '../../../core/data/nbc_club_badges.dart';

// ============================================================
// ROLE CONFIGURATION
// ============================================================
//
// Controls which action buttons appear on a post card.
//
// hasFanOption   → shows "Become Fan" (secondary) + "Follow" (primary)
// followOnly     → shows only "Follow" (full-width)
// community      → shows "Join Community" (full-width)
// commerce       → shows commerce-specific buttons (Buy Now, Watch, etc.)
// poll/prediction/video → their own fixed buttons
//
// To add a new role: add it to the appropriate set below.
// ============================================================

enum _SpotlightType {
  team,
  player,
  coach,
  scout,
  agent,
  academy,
  // "follow only" roles — no fan option
  journalist,
  analyst,
  commentator,
  creator,
  moderator,
  official,
  organization,
  league,
  competition,
  // community origin
  community,
  fan,
  // commerce
  business,
  sponsor,
  commercialPartner,
  venue,
  // content types
  match,
  video,
  poll,
  prediction,
}

/// Roles where "Become Fan" appears alongside "Follow".
const _fanRoles = {
  _SpotlightType.team,
  _SpotlightType.player,
  _SpotlightType.coach,
  _SpotlightType.scout,
  _SpotlightType.agent,
  _SpotlightType.academy,
};

/// Roles that only show "Follow" — no fan option.
const _followOnlyRoles = {
  _SpotlightType.journalist,
  _SpotlightType.analyst,
  _SpotlightType.commentator,
  _SpotlightType.creator,
  _SpotlightType.moderator,
  _SpotlightType.official,
  _SpotlightType.organization,
  _SpotlightType.league,
  _SpotlightType.competition,
  _SpotlightType.fan,
};

/// Community-origin posts — show "Join Community".
const _communityRoles = {
  _SpotlightType.community,
};

/// Commerce roles — show "Buy Now" / "Shop" buttons.
const _commerceRoles = {
  _SpotlightType.business,
  _SpotlightType.sponsor,
  _SpotlightType.commercialPartner,
  _SpotlightType.venue,
};

// ============================================================
// MODEL
// ============================================================

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
  });
}

// ============================================================
// MOCK FEED DATA
// ============================================================


const _welcomeFeed = <_SpotlightItem>[
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.simba, likes: 0, comments: 0, shares: 0, accent: Color(0xFFE31B23)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.yanga, likes: 0, comments: 0, shares: 0, accent: Color(0xFFFFC400)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.azam, likes: 0, comments: 0, shares: 0, accent: Color(0xFF00A8FF)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.singidaBlackStars, likes: 0, comments: 0, shares: 0, accent: Color(0xFF168CFF)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.mbeyaCity, likes: 0, comments: 0, shares: 0, accent: Color(0xFF4D8F24)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.geitaGold, likes: 0, comments: 0, shares: 0, accent: Color(0xFFFFB900)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.mashujaa, likes: 0, comments: 0, shares: 0, accent: Color(0xFFE31B23)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.namungo, likes: 0, comments: 0, shares: 0, accent: Color(0xFF168CFF)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.fountainGate, likes: 0, comments: 0, shares: 0, accent: Color(0xFF00A8FF)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.polisi, likes: 0, comments: 0, shares: 0, accent: Color(0xFF4D8F24)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.jkt, likes: 0, comments: 0, shares: 0, accent: Color(0xFFE31B23)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.traUnited, likes: 0, comments: 0, shares: 0, accent: Color(0xFF168CFF)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.pamba, likes: 0, comments: 0, shares: 0, accent: Color(0xFF00A8FF)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.kageraSugar, likes: 0, comments: 0, shares: 0, accent: Color(0xFF4D8F24)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.dodomaJiji, likes: 0, comments: 0, shares: 0, accent: Color(0xFFFFB900)),
  _SpotlightItem(type: _SpotlightType.team, author: 'SportSphere Official', role: 'Official', age: 'Just now', asset: NbcClubBadges.coastalUnion, likes: 0, comments: 0, shares: 0, accent: Color(0xFFE31B23)),
];

final _feedItems = <_SpotlightItem>[
  ..._welcomeFeed,
  _SpotlightItem(
    type: _SpotlightType.team,
    author: 'Young Africans SC',
    role: 'Team',
    age: '4d ago',
    likes: 0,
    comments: 56,
    shares: 78,
    accent: Color(0xFFFFC400),
  ),
  _SpotlightItem(
    type: _SpotlightType.match,
    author: 'Tanzania Football Federation',
    role: 'Official',
    age: '4d ago',
    likes: 34,
    comments: 12,
    shares: 8,
    accent: Color(0xFFFFC400),
  ),
  _SpotlightItem(
    type: _SpotlightType.business,
    author: 'AzamSport',
    role: 'Business',
    age: '4d ago',
    likes: 128,
    comments: 32,
    shares: 16,
    accent: Color(0xFFFFB900),
  ),
  _SpotlightItem(
    type: _SpotlightType.player,
    author: 'Clatous Chama',
    role: 'Player',
    age: '4d ago',
    likes: 0,
    comments: 72,
    shares: 93,
    accent: Color(0xFFE31B23),
  ),
  _SpotlightItem(
    type: _SpotlightType.analyst,
    author: 'Ali Kingu',
    role: 'Football Analyst',
    age: '4d ago',
    likes: 232,
    comments: 45,
    shares: 67,
    accent: Color(0xFF4D8F24),
  ),
  _SpotlightItem(
    type: _SpotlightType.community,
    author: 'Kariakoo Derby Community',
    role: 'Community',
    age: 'Today',
    likes: 182,
    comments: 64,
    shares: 22,
    accent: Color(0xFF00A8FF),
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
  ),
  _SpotlightItem(
    type: _SpotlightType.journalist,
    author: 'Didas Msemwa',
    role: 'Journalist',
    age: '1d ago',
    likes: 318,
    comments: 91,
    shares: 44,
    accent: Color(0xFFFF8A00),
  ),
  _SpotlightItem(
    type: _SpotlightType.coach,
    author: 'Mohammed Lazaro',
    role: 'Coach',
    age: '2d ago',
    likes: 154,
    comments: 29,
    shares: 18,
    accent: Color(0xFF00C896),
  ),
  _SpotlightItem(
    type: _SpotlightType.sponsor,
    author: 'Azam FC Sponsor',
    role: 'Sponsor',
    age: '3d ago',
    likes: 88,
    comments: 14,
    shares: 9,
    accent: Color(0xFFFFD700),
  ),
];

// ============================================================
// MAIN WIDGET
// ============================================================

class SportlightsTab extends StatefulWidget {
  const SportlightsTab({super.key});

  @override
  State<SportlightsTab> createState() => _SportlightsTabState();
}

class _SportlightsTabState extends State<SportlightsTab> {
  final ScrollController _scrollController = ScrollController();

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
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
          itemCount: null, // endless
          itemBuilder: (context, index) {
            final item = _feedItems[index % _feedItems.length];
            return _SpotlightCard(item: item);
          },
        ),
      ),
    );
  }
}

// ============================================================
// CARD
// ============================================================

class _SpotlightCard extends StatelessWidget {
  final _SpotlightItem item;
  const _SpotlightCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xD8071422),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
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
// AUTHOR HEADER
// ============================================================

class _AuthorHeader extends StatelessWidget {
  final _SpotlightItem item;
  const _AuthorHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/sport_sphere_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF102033),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white70,
                size: 24,
              ),
            ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF168CFF),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: _RoleBadge(label: item.role),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '·  ${item.age}',
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

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// MEDIA AREA
// ============================================================

class _MediaArea extends StatelessWidget {
  final _SpotlightItem item;
  const _MediaArea({required this.item});

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
  const _ImageContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final asset = item.asset;
    if (asset == null) return _GeneratedContent(item: item);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1.02,
        child: asset.startsWith('http')
            ? Image.network(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _GeneratedContent(item: item),
              )
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _GeneratedContent(item: item),
              ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  final _SpotlightItem item;
  const _VideoContent({required this.item});

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
              child: _ContentLabel(text: 'VIDEO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollContent extends StatefulWidget {
  const _PollContent();

  @override
  State<_PollContent> createState() => _PollContentState();
}

class _PollContentState extends State<_PollContent> {
  int? _voted; // index of voted option, null if not voted

  final _options = const ['Simba SC', 'Young Africans', 'Draw'];
  final _percentages = [46, 42, 12];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092B4A), Color(0xFF071421)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF168CFF), width: 0.7),
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
          for (var i = 0; i < _options.length; i++) ...[
            _PollOption(
              label: _options[i],
              percentage: _percentages[i],
              voted: _voted == i,
              revealed: _voted != null,
              onTap: _voted == null
                  ? () => setState(() => _voted = i)
                  : null,
            ),
            if (i < _options.length - 1) const SizedBox(height: 10),
          ],
          if (_voted != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '${_percentages.fold(0, (a, b) => a + b) * 42} votes · 18 hours left',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final String label;
  final int percentage;
  final bool voted;
  final bool revealed;
  final VoidCallback? onTap;

  const _PollOption({
    required this.label,
    required this.percentage,
    required this.voted,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        decoration: BoxDecoration(
          color: voted
              ? const Color(0xFF168CFF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: voted
                ? const Color(0xFF168CFF).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Stack(
          children: [
            if (revealed)
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
                  if (voted)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF168CFF),
                        size: 16,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            voted ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (revealed)
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
          colors: [Color(0xFF182E0E), Color(0xFF071421)],
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
              Icon(Icons.analytics_outlined, color: Color(0xFF7FD820)),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PredictionTeam(name: 'SIMBA'),
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _PredictionTeam(name: 'YANGA'),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
  const _PredictionTeam({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.shield_rounded, color: Colors.white70, size: 38),
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

class _GeneratedContent extends StatelessWidget {
  final _SpotlightItem item;
  const _GeneratedContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.02,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF061321),
              Color.lerp(const Color(0xFF061321), item.accent, 0.32)!,
              const Color(0xFF02060D),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _typeIcon(item.type),
                color: Colors.white,
                size: 58,
              ),
              const SizedBox(height: 12),
              Text(
                _typeLabel(item.type).toUpperCase(),
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
      ),
    );
  }
}

IconData _typeIcon(_SpotlightType type) {
  switch (type) {
    case _SpotlightType.team:
      return Icons.groups_rounded;
    case _SpotlightType.player:
      return Icons.person_rounded;
    case _SpotlightType.coach:
      return Icons.sports_rounded;
    case _SpotlightType.scout:
      return Icons.search_rounded;
    case _SpotlightType.agent:
      return Icons.handshake_rounded;
    case _SpotlightType.academy:
      return Icons.school_rounded;
    case _SpotlightType.journalist:
      return Icons.newspaper_rounded;
    case _SpotlightType.analyst:
      return Icons.analytics_rounded;
    case _SpotlightType.commentator:
      return Icons.mic_rounded;
    case _SpotlightType.creator:
      return Icons.play_circle_fill_rounded;
    case _SpotlightType.moderator:
      return Icons.shield_moon_rounded;
    case _SpotlightType.official:
      return Icons.gavel_rounded;
    case _SpotlightType.organization:
      return Icons.corporate_fare_rounded;
    case _SpotlightType.league:
      return Icons.emoji_events_rounded;
    case _SpotlightType.competition:
      return Icons.sports_score_rounded;
    case _SpotlightType.community:
      return Icons.groups_rounded;
    case _SpotlightType.fan:
      return Icons.favorite_rounded;
    case _SpotlightType.business:
      return Icons.storefront_rounded;
    case _SpotlightType.sponsor:
      return Icons.local_offer_rounded;
    case _SpotlightType.commercialPartner:
      return Icons.handshake_rounded;
    case _SpotlightType.venue:
      return Icons.stadium_rounded;
    case _SpotlightType.match:
      return Icons.stadium_rounded;
    case _SpotlightType.video:
      return Icons.play_circle_fill_rounded;
    case _SpotlightType.poll:
      return Icons.poll_rounded;
    case _SpotlightType.prediction:
      return Icons.insights_rounded;
  }
}

String _typeLabel(_SpotlightType type) {
  switch (type) {
    case _SpotlightType.team:
      return 'Team';
    case _SpotlightType.player:
      return 'Player';
    case _SpotlightType.coach:
      return 'Coach';
    case _SpotlightType.scout:
      return 'Scout';
    case _SpotlightType.agent:
      return 'Agent';
    case _SpotlightType.academy:
      return 'Academy';
    case _SpotlightType.journalist:
      return 'Journalist';
    case _SpotlightType.analyst:
      return 'Analyst';
    case _SpotlightType.commentator:
      return 'Commentator';
    case _SpotlightType.creator:
      return 'Creator';
    case _SpotlightType.moderator:
      return 'Moderator';
    case _SpotlightType.official:
      return 'Official';
    case _SpotlightType.organization:
      return 'Organization';
    case _SpotlightType.league:
      return 'League';
    case _SpotlightType.competition:
      return 'Competition';
    case _SpotlightType.community:
      return 'Community';
    case _SpotlightType.fan:
      return 'Fan';
    case _SpotlightType.business:
      return 'Business';
    case _SpotlightType.sponsor:
      return 'Sponsor';
    case _SpotlightType.commercialPartner:
      return 'Partner';
    case _SpotlightType.venue:
      return 'Venue';
    case _SpotlightType.match:
      return 'Match';
    case _SpotlightType.video:
      return 'Video';
    case _SpotlightType.poll:
      return 'Poll';
    case _SpotlightType.prediction:
      return 'Prediction';
  }
}

// ============================================================
// ENGAGEMENT ROW
// ============================================================

class _EngagementRow extends StatefulWidget {
  final _SpotlightItem item;
  const _EngagementRow({required this.item});

  @override
  State<_EngagementRow> createState() => _EngagementRowState();
}

class _EngagementRowState extends State<_EngagementRow> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final likes = widget.item.likes + (_liked ? 1 : 0);

    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _liked = !_liked),
          child: Row(
            children: [
              Icon(
                _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _liked
                    ? const Color(0xFFFF3B61)
                    : Colors.white,
                size: 22,
              ),
              if (likes > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$likes',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 22),
        _EngagementBtn(
          icon: Icons.chat_bubble_outline_rounded,
          value: widget.item.comments,
        ),
        const SizedBox(width: 22),
        _EngagementBtn(
          icon: Icons.ios_share_rounded,
          value: widget.item.shares,
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

class _EngagementBtn extends StatelessWidget {
  final IconData icon;
  final int value;
  const _EngagementBtn({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
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
// ACTION ROW  — role-aware button logic
// ============================================================

class _ActionRow extends StatefulWidget {
  final _SpotlightItem item;
  const _ActionRow({required this.item});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _following = false;
  bool _isFan = false;
  bool _joinedCommunity = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.item.type;
    final accent = widget.item.accent;

    // ── Commerce: match tickets & business ──────────────────
    if (type == _SpotlightType.match) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Buy Ticket',
          icon: Icons.confirmation_number_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'View Match',
          icon: Icons.stadium_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    if (_commerceRoles.contains(type)) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Buy Now',
          icon: Icons.shopping_cart_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'Visit Shop',
          icon: Icons.storefront_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    // ── Video ────────────────────────────────────────────────
    if (type == _SpotlightType.video) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Watch',
          icon: Icons.play_arrow_rounded,
          color: accent,
          onTap: () {},
        ),
        secondary: _following
            ? _Btn(
                label: 'Following',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => setState(() => _following = false),
              )
            : _Btn(
                label: 'Follow',
                icon: Icons.person_add_alt_1_rounded,
                color: accent,
                outlined: true,
                onTap: () => setState(() => _following = true),
              ),
      );
    }

    // ── Poll ─────────────────────────────────────────────────
    if (type == _SpotlightType.poll) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Vote',
          icon: Icons.how_to_vote_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'Discuss',
          icon: Icons.forum_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    // ── Prediction ───────────────────────────────────────────
    if (type == _SpotlightType.prediction) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Predict',
          icon: Icons.analytics_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'View Match',
          icon: Icons.sports_soccer_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    // ── Community ────────────────────────────────────────────
    if (_communityRoles.contains(type)) {
      return _joinedCommunity
          ? _OneButton(
              child: _Btn(
                label: 'Joined Community',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => setState(() => _joinedCommunity = false),
              ),
            )
          : _OneButton(
              child: _Btn(
                label: 'Join Community',
                icon: Icons.group_add_outlined,
                color: accent,
                onTap: () => setState(() => _joinedCommunity = true),
              ),
            );
    }

    // ── Fan roles: Follow + Become Fan ───────────────────────
    if (_fanRoles.contains(type)) {
      return _TwoButtons(
        primary: _isFan
            ? _Btn(
                label: 'Fan ✓',
                icon: Icons.favorite_rounded,
                color: accent,
                onTap: () => setState(() => _isFan = false),
              )
            : _Btn(
                label: 'Become Fan',
                icon: Icons.favorite_border_rounded,
                color: accent,
                onTap: () => setState(() => _isFan = true),
              ),
        secondary: _following
            ? _Btn(
                label: 'Following',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => setState(() => _following = false),
              )
            : _Btn(
                label: 'Follow',
                icon: Icons.person_add_alt_1_rounded,
                color: accent,
                outlined: true,
                onTap: () => setState(() => _following = true),
              ),
      );
    }

    // ── Follow-only roles ────────────────────────────────────
    if (_followOnlyRoles.contains(type)) {
      return _OneButton(
        child: _following
            ? _Btn(
                label: 'Following',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => setState(() => _following = false),
              )
            : _Btn(
                label: 'Follow',
                icon: Icons.person_add_alt_1_rounded,
                color: accent,
                onTap: () => setState(() => _following = true),
              ),
      );
    }

    // ── Fallback ─────────────────────────────────────────────
    return const SizedBox.shrink();
  }
}

// ── Layout helpers ─────────────────────────────────────────

class _OneButton extends StatelessWidget {
  final Widget child;
  const _OneButton({required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: child,
      );
}

class _TwoButtons extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  const _TwoButtons({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: secondary),
          const SizedBox(width: 9),
          Expanded(child: primary),
        ],
      );
}

// ── Individual button ──────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
              size: 18,
            ),
            const SizedBox(width: 6),
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
      ),
    );
  }
}

// ============================================================
// SMALL SHARED COMPONENTS
// ============================================================

class _ContentLabel extends StatelessWidget {
  final String text;
  const _ContentLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
