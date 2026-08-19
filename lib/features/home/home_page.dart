import 'dart:ui';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;

  static const bg = Color(0xFF050B14);
  static const card = Color(0xFF0D1726);
  static const blue = Color(0xFF1683FF);
  static const brightBlue = Color(0xFF35A7FF);
  static const white = Color(0xFFF7FAFF);
  static const muted = Color(0xFF8B98AA);

  final tabs = const [
    'Spotlights',
    'Trending',
    'Community',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _tabs()),
            SliverToBoxAdapter(child: _featuredPost()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => _postCard(index),
                  childCount: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          const Text(
            'SPORTSPHERE',
            style: TextStyle(
              color: white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          _circleButton(Icons.search_rounded),
          const SizedBox(width: 8),
          _circleButton(Icons.notifications_none_rounded),
          const SizedBox(width: 8),
          _circleButton(Icons.mail_outline_rounded),
        ],
      ),
    );
  }

  Widget _tabs() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: tabs.length,
        itemBuilder: (_, index) {
          final active = index == _selectedTab;

          return GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: active
                    ? blue.withValues(alpha: .16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active
                      ? blue.withValues(alpha: .45)
                      : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: active ? white : muted,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _featuredPost() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      height: 285,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            blue.withValues(alpha: .30),
            const Color(0xFF101D30),
            card,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: .08),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brightBlue.withValues(alpha: .12),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: .10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _badge('SPORTSPHERE SPOTLIGHT'),
                const SizedBox(height: 12),
                const Text(
                  'The game is bigger\nthan 90 minutes.',
                  style: TextStyle(
                    color: white,
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Discover stories, moments and conversations shaping football.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _avatar('M'),
                    const SizedBox(width: 8),
                    const Text(
                      'Mbazza Codes',
                      style: TextStyle(
                        color: white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: white,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(int index) {
    final posts = [
      (
        'Football Central',
        'Big match energy is back. Who takes the three points?',
        '2.4K',
        '184',
      ),
      (
        'SportSphere News',
        'Transfer talks are heating up as clubs prepare for another big move.',
        '1.8K',
        '126',
      ),
      (
        'Tanzania Football',
        'The fans have spoken. Here is today’s biggest football debate.',
        '3.1K',
        '249',
      ),
      (
        'Matchday',
        'One stadium. Two teams. Ninety minutes. Everything can happen.',
        '987',
        '72',
      ),
      (
        'Football Community',
        'What is the greatest football moment you have ever witnessed?',
        '4.6K',
        '401',
      ),
    ];

    final post = posts[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: .065),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(post.$1.substring(0, 1)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.$1,
                      style: const TextStyle(
                        color: white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '2h ago',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.more_horiz_rounded,
                color: muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.$2,
            style: const TextStyle(
              color: white,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _action(Icons.favorite_border_rounded, post.$3),
              const SizedBox(width: 22),
              _action(Icons.chat_bubble_outline_rounded, post.$4),
              const SizedBox(width: 22),
              _action(Icons.repeat_rounded, ''),
              const Spacer(),
              const Icon(
                Icons.bookmark_border_rounded,
                color: muted,
                size: 21,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String count) {
    return Row(
      children: [
        Icon(
          icon,
          color: muted,
          size: 20,
        ),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 5),
          Text(
            count,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: blue.withValues(alpha: .30),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: brightBlue,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }

  Widget _avatar(String letter) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            blue,
            brightBlue,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: .12),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: card.withValues(alpha: .75),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Icon(
            icon,
            color: white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
