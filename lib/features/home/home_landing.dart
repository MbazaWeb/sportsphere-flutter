import 'dart:ui';

import 'package:flutter/material.dart';

class HomeLanding extends StatefulWidget {
  const HomeLanding({super.key});

  @override
  State<HomeLanding> createState() => _HomeLandingState();
}

class _HomeLandingState extends State<HomeLanding>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;

  final PageController _feedController = PageController();

  final List<String> _tabs = const [
    'Spotlights',
    'Trending',
    'Community',
  ];

  @override
  void dispose() {
    _feedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000818),
      body: Stack(
        children: [
          const _AmbientBackground(),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopHeader(
                  selectedTab: _selectedTab,
                  tabs: _tabs,
                  onTabChanged: (index) {
                    setState(() {
                      _selectedTab = index;
                    });
                  },
                  onSearch: () {},
                  onNotification: () {},
                  onInbox: () {},
                ),

                Expanded(
                  child: _HomeFeed(
                    tabIndex: _selectedTab,
                    controller: _feedController,
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

class _TopHeader extends StatelessWidget {
  final int selectedTab;
  final List<String> tabs;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final VoidCallback onInbox;

  const _TopHeader({
    required this.selectedTab,
    required this.tabs,
    required this.onTabChanged,
    required this.onSearch,
    required this.onNotification,
    required this.onInbox,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 22,
          sigmaY: 22,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            0,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF000818)
                .withValues(alpha: 0.68),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _BrandMark(),

                  const Spacer(),

                  _HeaderButton(
                    icon: Icons.search_rounded,
                    onTap: onSearch,
                  ),

                  const SizedBox(width: 8),

                  _HeaderButton(
                    icon: Icons.notifications_none_rounded,
                    badge: '3',
                    onTap: onNotification,
                  ),

                  const SizedBox(width: 8),

                  _HeaderButton(
                    icon: Icons.mail_outline_rounded,
                    badge: '5',
                    onTap: onInbox,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 46,
                child: Row(
                  children: List.generate(
                    tabs.length,
                    (index) {
                      final selected =
                          selectedTab == index;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTabChanged(index),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              Text(
                                tabs[index],
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white
                                          .withValues(
                                          alpha: 0.46,
                                        ),
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              AnimatedContainer(
                                duration: const Duration(
                                  milliseconds: 220,
                                ),
                                height: 2.5,
                                width: selected ? 58 : 0,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  gradient:
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFF00A8FF),
                                      Color(0xFF20D9FF),
                                      Color(0xFF69D719),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00A8FF,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF001838),
            border: Border.all(
              color: const Color(0xFF00A8FF)
                  .withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A8FF)
                    .withValues(alpha: 0.18),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/sport_sphere_ball.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'SPORT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'SPHERE',
          style: TextStyle(
            color: Color(0xFF69D719),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
              ),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),

          if (badge != null)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 17,
                  minHeight: 17,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF000818),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeFeed extends StatelessWidget {
  final int tabIndex;
  final PageController controller;

  const _HomeFeed({
    required this.tabIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final items = switch (tabIndex) {
      0 => _spotlights,
      1 => _trending,
      _ => _community,
    };

    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _FeedCard(
          item: items[index],
          tabIndex: tabIndex,
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  final _FeedItem item;
  final int tabIndex;

  const _FeedCard({
    required this.item,
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF001838),
                const Color(0xFF000818),
                const Color(0xFF00030C),
              ],
            ),
          ),
        ),

        Positioned(
          top: 32,
          left: 18,
          right: 18,
          child: _GlassContentPreview(item: item),
        ),

        Positioned(
          left: 18,
          right: 82,
          bottom: 118,
          child: _FeedText(item: item),
        ),

        Positioned(
          right: 14,
          bottom: 112,
          child: _ActionRail(item: item),
        ),

        Positioned(
          left: 18,
          bottom: 88,
          child: _ContentTypeBadge(tabIndex: tabIndex),
        ),
      ],
    );
  }
}

class _GlassContentPreview extends StatelessWidget {
  final _FeedItem item;

  const _GlassContentPreview({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
        ),
        child: Container(
          height: 360,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.15),
                blurRadius: 35,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SportPatternPainter(
                    color: item.color,
                  ),
                ),
              ),

              Center(
                child: Icon(
                  item.icon,
                  size: 82,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),

              Positioned(
                top: 16,
                left: 16,
                child: _LivePill(
                  label: item.live ? 'LIVE' : 'SPORTS',
                  color: item.live
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFF00A8FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final String label;
  final Color color;

  const _LivePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedText extends StatelessWidget {
  final _FeedItem item;

  const _FeedText({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white70,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              item.author,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.verified_rounded,
              size: 14,
              color: Color(0xFF00A8FF),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          children: item.tags
              .map(
                (tag) => Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xFF20D9FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ActionRail extends StatelessWidget {
  final _FeedItem item;

  const _ActionRail({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.favorite_border_rounded,
          label: item.likes,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: item.comments,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.repeat_rounded,
          label: item.reposts,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.send_outlined,
          label: 'Share',
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.bookmark_border_rounded,
          label: 'Save',
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 12,
              sigmaY: 12,
            ),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.065),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ContentTypeBadge extends StatelessWidget {
  final int tabIndex;

  const _ContentTypeBadge({
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (tabIndex) {
      0 => 'SPOTLIGHT',
      1 => 'TRENDING',
      _ => 'COMMUNITY',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF00A8FF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00A8FF).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF20D9FF),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -80,
          child: _Glow(
            color: const Color(0xFF00A8FF),
            size: 260,
          ),
        ),
        Positioned(
          top: 260,
          right: -120,
          child: _Glow(
            color: const Color(0xFF69D719),
            size: 260,
          ),
        ),
        Positioned(
          bottom: -100,
          left: 100,
          child: _Glow(
            color: const Color(0xFFFF7A00),
            size: 200,
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.025),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _SportPatternPainter extends CustomPainter {
  final Color color;

  _SportPatternPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.12);

    for (int i = -4; i < 12; i++) {
      final path = Path();

      path.moveTo(
        0,
        size.height * 0.55 + i * 24,
      );

      path.cubicTo(
        size.width * 0.25,
        size.height * 0.35 + i * 18,
        size.width * 0.65,
        size.height * 0.75 + i * 18,
        size.width,
        size.height * 0.48 + i * 20,
      );

      canvas.drawPath(path, paint);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width / 2,
            size.height / 2,
          ),
          radius: size.width * 0.5,
        ),
      );

    canvas.drawCircle(
      Offset(
        size.width / 2,
        size.height / 2,
      ),
      size.width * 0.45,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SportPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FeedItem {
  final String author;
  final String title;
  final String description;
  final List<String> tags;
  final String likes;
  final String comments;
  final String reposts;
  final IconData icon;
  final Color color;
  final bool live;

  const _FeedItem({
    required this.author,
    required this.title,
    required this.description,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.reposts,
    required this.icon,
    required this.color,
    required this.live,
  });
}

const _spotlights = [
  _FeedItem(
    author: 'SportSphere',
    title: 'The moment the stadium exploded.',
    description:
        'Relive the biggest moments from today’s football action.',
    tags: ['#Football', '#Highlights'],
    likes: '24.8K',
    comments: '1.2K',
    reposts: '482',
    icon: Icons.sports_soccer_rounded,
    color: Color(0xFF00A8FF),
    live: true,
  ),
  _FeedItem(
    author: 'Sports Daily',
    title: 'Pure football energy.',
    description:
        'Skills, reactions and moments that deserve another look.',
    tags: ['#Spotlight', '#Sports'],
    likes: '18.4K',
    comments: '742',
    reposts: '310',
    icon: Icons.flash_on_rounded,
    color: Color(0xFF69D719),
    live: false,
  ),
];

const _trending = [
  _FeedItem(
    author: 'Football Central',
    title: 'The transfer story everyone is talking about.',
    description:
        'Here is what is trending across the football community right now.',
    tags: ['#Trending', '#TransferNews'],
    likes: '31.7K',
    comments: '2.4K',
    reposts: '1.1K',
    icon: Icons.trending_up_rounded,
    color: Color(0xFFFF7A00),
    live: true,
  ),
  _FeedItem(
    author: 'SportSphere News',
    title: 'Tonight’s biggest sports conversations.',
    description:
        'Join the conversation and share your take with the community.',
    tags: ['#TrendingNow', '#Sports'],
    likes: '12.9K',
    comments: '886',
    reposts: '205',
    icon: Icons.forum_rounded,
    color: Color(0xFF20D9FF),
    live: false,
  ),
];

const _community = [
  _FeedItem(
    author: 'Young Fans Community',
    title: 'Who takes the trophy?',
    description:
        'Thousands of fans are discussing tonight’s biggest match.',
    tags: ['#Community', '#MatchDay'],
    likes: '9.2K',
    comments: '3.1K',
    reposts: '640',
    icon: Icons.groups_rounded,
    color: Color(0xFF69D719),
    live: true,
  ),
  _FeedItem(
    author: 'Football Tanzania',
    title: 'Your prediction matters.',
    description:
        'Vote, debate and connect with fans who share your passion.',
    tags: ['#Fans', '#Tanzania'],
    likes: '7.6K',
    comments: '1.8K',
    reposts: '422',
    icon: Icons.poll_rounded,
    color: Color(0xFF00A8FF),
    live: false,
  ),
];