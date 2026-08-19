import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class FanProfileModel {
  const FanProfileModel({
    required this.firstName,
    required this.lastName,
    required this.handle,
    required this.fanOf,
    required this.fanOfAccent,
    required this.bio,
    required this.sport,
    required this.location,
    required this.joinedDate,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    this.avatarAsset,
    this.coverAsset,
    this.isVerified = false,
    this.isOwnProfile = false,
  });

  final String firstName;
  final String lastName;
  final String handle;

  // "Fan of" team name + accent colour
  final String fanOf;
  final Color fanOfAccent;

  final String bio;
  final String sport;
  final String location;
  final DateTime joinedDate;

  final int postCount;
  final int followerCount;
  final int followingCount;

  final String? avatarAsset;
  final String? coverAsset;
  final bool isVerified;
  final bool isOwnProfile;

  String get displayName => '$firstName $lastName';
  String get atHandle => '@$handle';

  String get followerLabel {
    if (followerCount >= 1000) {
      return '${(followerCount / 1000).toStringAsFixed(1)}K';
    }
    return '$followerCount';
  }
}

// ── Mock data for own profile ──────────────────────────────────────────────────
final mockOwnFanProfile = FanProfileModel(
  firstName: 'Mbaza',
  lastName: '',
  handle: 'mbaza',
  fanOf: 'Simba SC',
  fanOfAccent: const Color(0xFFE31B23),
  bio: 'Mshabiki wa kweli wa Simba SC 🦁🔴. Football is life.',
  sport: 'Football',
  location: 'Dar es Salaam, Tanzania',
  joinedDate: DateTime(2024, 3, 1),
  postCount: 48,
  followerCount: 1200,
  followingCount: 180,
  avatarAsset: 'assets/images/sport_sphere_icon.png',
  isVerified: true,
  isOwnProfile: true,
);

// ── Mock posts ─────────────────────────────────────────────────────────────────
final _mockPosts = <_ProfilePost>[
  _ProfilePost(
    text: 'Simba iko tayari kwa mchezo mkubwa! 🔥🦁',
    hashtags: ['#NguVuMoja'],
    timeAgo: '2h',
    likes: 124,
    comments: 18,
    shares: 32,
    hasImage: true,
    imageCount: 1,
  ),
  _ProfilePost(
    text:
        'Vibe ya Msimbazi juzi ilikuwa ya kipekee! Asante mashabiki wetu wa nguvu! ❤️',
    hashtags: ['#WekunduWaMsimbazi'],
    timeAgo: '1d',
    likes: 96,
    comments: 12,
    shares: 21,
    hasImage: true,
    imageCount: 2,
    hasVideo: true,
  ),
  _ProfilePost(
    text: 'Next game, next mission. Tunasonga mbele! 💪⚽',
    hashtags: ['#SimbaSC'],
    timeAgo: '3d',
    likes: 58,
    comments: 7,
    shares: 11,
    hasImage: false,
  ),
  _ProfilePost(
    text: 'Derby ya Kariakoo kesho — moyo wangu uko tayari. Simba daima! 🏆',
    hashtags: ['#KarikarooDerby', '#SimbaSC'],
    timeAgo: '5d',
    likes: 201,
    comments: 34,
    shares: 44,
    hasImage: true,
    imageCount: 1,
  ),
];

class _ProfilePost {
  final String text;
  final List<String> hashtags;
  final String timeAgo;
  final int likes;
  final int comments;
  final int shares;
  final bool hasImage;
  final int imageCount;
  final bool hasVideo;

  const _ProfilePost({
    required this.text,
    required this.hashtags,
    required this.timeAgo,
    required this.likes,
    required this.comments,
    required this.shares,
    this.hasImage = false,
    this.imageCount = 1,
    this.hasVideo = false,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class FanProfileView extends StatefulWidget {
  final FanProfileModel profile;

  const FanProfileView({
    super.key,
    required this.profile,
  });

  @override
  State<FanProfileView> createState() => _FanProfileViewState();
}

class _FanProfileViewState extends State<FanProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  FanProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          // ── Cover + header ────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: p,
              following: _following,
              onFollow: () {
                HapticFeedback.lightImpact();
                setState(() => _following = !_following);
              },
              onBack: () => Navigator.of(context).maybePop(),
              onMore: () => _showMoreSheet(context),
              onInfo: () => _tabCtrl.animateTo(1),
            ),
          ),

          // ── Sticky tab bar ─────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: _ProfileTabBar(controller: _tabCtrl),
            ),
          ),
        ],

        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SportlightsFeed(profile: p),
            _AboutTab(profile: p),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(isOwnProfile: p.isOwnProfile),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final FanProfileModel profile;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onInfo;

  const _ProfileHeader({
    required this.profile,
    required this.following,
    required this.onFollow,
    required this.onBack,
    required this.onMore,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final coverH = 180.0;
    final avatarR = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cover banner ────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover image / gradient
            SizedBox(
              height: coverH,
              width: double.infinity,
              child: profile.coverAsset != null
                  ? Image.asset(
                      profile.coverAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _CoverGradient(
                        accent: profile.fanOfAccent,
                      ),
                    )
                  : _CoverGradient(accent: profile.fanOfAccent),
            ),

            // Dark overlay bottom fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      SportSphereColors.background.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),

            // Back button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: Semantics(
                label: 'Go back',
                button: true,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),

            // More (⋯) button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Semantics(
                label: 'More options',
                button: true,
                child: GestureDetector(
                  onTap: onMore,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Avatar overlapping the cover bottom edge
            Positioned(
              bottom: -(avatarR * 0.5),
              left: 16,
              child: _Avatar(
                asset: profile.avatarAsset,
                radius: avatarR,
                accentColor: profile.fanOfAccent,
              ),
            ),
          ],
        ),

        // ── Gap for avatar overlap ──────────────────────────────
        SizedBox(height: avatarR * 0.5 + 10),

        // ── Name row ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + verified
                    Row(
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            color: SportSphereColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: SportSphereColors.electricBlue,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // @handle
                    Text(
                      profile.atHandle,
                      style: const TextStyle(
                        color: SportSphereColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Fan of
                    _FanOfBadge(
                      teamName: profile.fanOf,
                      accent: profile.fanOfAccent,
                    ),
                  ],
                ),
              ),

              // ⓘ info / About shortcut
              Semantics(
                label: 'View About section',
                button: true,
                child: GestureDetector(
                  onTap: onInfo,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: SportSphereColors.muted,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Stats row ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StatsRow(profile: profile),
        ),

        const SizedBox(height: 16),

        // ── Action buttons ────────────────────────────────────
        if (!profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _ActionButtons(
              following: following,
              onFollow: onFollow,
              fanOfAccent: profile.fanOfAccent,
            ),
          ),

        if (profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _EditProfileButton(),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Cover gradient (fallback when no image) ────────────────────────────────────

class _CoverGradient extends StatelessWidget {
  final Color accent;
  const _CoverGradient({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF08111E),
            accent.withValues(alpha: 0.40),
            const Color(0xFF030810),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.groups_rounded,
          size: 72,
          color: accent.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? asset;
  final double radius;
  final Color accentColor;
  const _Avatar({required this.asset, required this.radius, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SportSphereColors.background,
        border: Border.all(
          color: SportSphereColors.background,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.30),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: asset != null
            ? Image.asset(
                asset!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarFallback(accent: accentColor),
              )
            : _AvatarFallback(accent: accentColor),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final Color accent;
  const _AvatarFallback({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.15),
      child: Icon(Icons.person_rounded, color: accent.withValues(alpha: 0.6), size: 40),
    );
  }
}

// ── "Fan of" badge ────────────────────────────────────────────────────────────

class _FanOfBadge extends StatelessWidget {
  final String teamName;
  final Color accent;
  const _FanOfBadge({required this.teamName, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Fan of ',
          style: TextStyle(
            color: SportSphereColors.muted,
            fontSize: 13,
          ),
        ),
        Text(
          teamName,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.shield_rounded, color: accent, size: 10),
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final FanProfileModel profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(value: '${profile.postCount}', label: 'Posts'),
        _Divider(),
        _Stat(value: profile.followerLabel, label: 'Followers'),
        _Divider(),
        _Stat(value: '${profile.followingCount}', label: 'Following'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SportSphereColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: SportSphereColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}

// ── Action buttons (other profile) ────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final bool following;
  final VoidCallback onFollow;
  final Color fanOfAccent;
  const _ActionButtons({
    required this.following,
    required this.onFollow,
    required this.fanOfAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: following ? 'Following' : 'Follow',
            button: true,
            child: GestureDetector(
              onTap: onFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: following
                      ? null
                      : const LinearGradient(
                          colors: [
                            SportSphereColors.electricBlue,
                            Color(0xFF0066DD),
                          ],
                        ),
                  color: following
                      ? Colors.white.withValues(alpha: 0.06)
                      : null,
                  border: following
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        )
                      : null,
                  boxShadow: following
                      ? null
                      : [
                          BoxShadow(
                            color: SportSphereColors.electricBlue
                                .withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    following ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: following
                          ? SportSphereColors.muted
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: 'Send message',
          button: true,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: SportSphereColors.muted,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit profile button (own profile) ─────────────────────────────────────────

class _EditProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Edit profile',
      button: true,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: const Center(
            child: Text(
              'Edit Profile',
              style: TextStyle(
                color: SportSphereColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB BAR
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileTabBar extends StatelessWidget {
  final TabController controller;
  const _ProfileTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SportSphereColors.background,
      child: TabBar(
        controller: controller,
        labelColor: SportSphereColors.white,
        unselectedLabelColor: SportSphereColors.muted,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
            color: SportSphereColors.sportGreen,
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(4),
          insets: const EdgeInsets.symmetric(horizontal: 20),
        ),
        tabs: const [
          Tab(text: 'Spotlights'),
          Tab(text: 'About'),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return tabBar;
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// SPOTLIGHTS FEED TAB
// ══════════════════════════════════════════════════════════════════════════════

class _SportlightsFeed extends StatelessWidget {
  final FanProfileModel profile;
  const _SportlightsFeed({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: _mockPosts.length,
      itemBuilder: (_, i) => _ProfilePostCard(
        post: _mockPosts[i],
        profile: profile,
      ),
    );
  }
}

// ── Profile post card ─────────────────────────────────────────────────────────

class _ProfilePostCard extends StatefulWidget {
  final _ProfilePost post;
  final FanProfileModel profile;
  const _ProfilePostCard({required this.post, required this.profile});

  @override
  State<_ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<_ProfilePostCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final p = widget.profile;
    final likes = post.likes + (_liked ? 1 : 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xD8071422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author ──────────────────────────────────────────
            Row(
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: p.fanOfAccent.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: p.avatarAsset != null
                        ? Image.asset(
                            p.avatarAsset!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: p.fanOfAccent.withValues(alpha: 0.15),
                              child: Icon(Icons.person_rounded,
                                  color: p.fanOfAccent, size: 20),
                            ),
                          )
                        : Container(
                            color: p.fanOfAccent.withValues(alpha: 0.15),
                            child: Icon(Icons.person_rounded,
                                color: p.fanOfAccent, size: 20),
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
                          Text(
                            p.displayName,
                            style: const TextStyle(
                              color: SportSphereColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (p.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: SportSphereColors.electricBlue,
                              size: 13,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${p.atHandle} · ${post.timeAgo}',
                        style: TextStyle(
                          color: SportSphereColors.muted.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Post options',
                  button: true,
                  child: GestureDetector(
                    onTap: () {},
                    child: const Icon(
                      Icons.more_vert_rounded,
                      color: SportSphereColors.muted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Text + hashtags ─────────────────────────────────
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: post.text),
                  if (post.hashtags.isNotEmpty) ...[
                    const TextSpan(text: '\n'),
                    ...post.hashtags.map(
                      (h) => TextSpan(
                        text: '$h ',
                        style: TextStyle(
                          color: p.fanOfAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Media ───────────────────────────────────────────
            if (post.hasImage) ...[
              const SizedBox(height: 12),
              _PostMedia(
                imageCount: post.imageCount,
                hasVideo: post.hasVideo,
                accent: p.fanOfAccent,
              ),
            ],

            const SizedBox(height: 14),

            // ── Engagement row ──────────────────────────────────
            Row(
              children: [
                // Like
                Semantics(
                  label: _liked ? 'Unlike post' : 'Like post',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _liked = !_liked);
                    },
                    child: Row(
                      children: [
                        Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _liked
                              ? SportSphereColors.danger
                              : SportSphereColors.muted,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatCount(likes),
                          style: TextStyle(
                            color: _liked
                                ? SportSphereColors.danger
                                : SportSphereColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Comment
                Semantics(
                  label: 'Comment',
                  button: true,
                  child: GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: SportSphereColors.muted,
                          size: 19,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatCount(post.comments),
                          style: const TextStyle(
                            color: SportSphereColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Predict
                Semantics(
                  label: 'Predict',
                  button: true,
                  child: GestureDetector(
                    onTap: () {},
                    child: const Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: SportSphereColors.muted,
                          size: 19,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Predict',
                          style: TextStyle(
                            color: SportSphereColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Share
                Semantics(
                  label: 'Share post',
                  button: true,
                  child: GestureDetector(
                    onTap: () {},
                    child: const Row(
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: SportSphereColors.muted,
                          size: 19,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: SportSphereColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Post media ────────────────────────────────────────────────────────────────

class _PostMedia extends StatelessWidget {
  final int imageCount;
  final bool hasVideo;
  final Color accent;
  const _PostMedia({
    required this.imageCount,
    required this.hasVideo,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (imageCount == 1 && !hasVideo) {
      return _MediaTile(
        accent: accent,
        hasVideo: false,
        aspectRatio: 16 / 9,
      );
    }

    // 2-up grid
    return Row(
      children: [
        Expanded(
          child: _MediaTile(
            accent: accent,
            hasVideo: hasVideo,
            aspectRatio: 1,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _MediaTile(
            accent: accent,
            hasVideo: false,
            aspectRatio: 1,
          ),
        ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Color accent;
  final bool hasVideo;
  final double aspectRatio;
  const _MediaTile({
    required this.accent,
    required this.hasVideo,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF08111E),
                accent.withValues(alpha: 0.28),
                const Color(0xFF020810),
              ],
            ),
          ),
          child: hasVideo
              ? Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                )
              : Icon(
                  Icons.image_rounded,
                  color: accent.withValues(alpha: 0.25),
                  size: 40,
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABOUT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _AboutTab extends StatelessWidget {
  final FanProfileModel profile;
  const _AboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Bio
        if (profile.bio.isNotEmpty) ...[
          _AboutSection(
            title: 'Bio',
            child: Text(
              profile.bio,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Details
        _AboutSection(
          title: 'Details',
          child: Column(
            children: [
              _AboutRow(
                icon: Icons.favorite_rounded,
                iconColor: profile.fanOfAccent,
                label: 'Fan of',
                value: profile.fanOf,
                valueColor: profile.fanOfAccent,
              ),
              _AboutRow(
                icon: Icons.sports_soccer_rounded,
                iconColor: SportSphereColors.electricBlue,
                label: 'Favourite sport',
                value: profile.sport,
              ),
              _AboutRow(
                icon: Icons.place_rounded,
                iconColor: SportSphereColors.sportOrange,
                label: 'Location',
                value: profile.location,
              ),
              _AboutRow(
                icon: Icons.calendar_today_rounded,
                iconColor: SportSphereColors.sportGreen,
                label: 'Joined',
                value: DateFormat('MMMM yyyy').format(profile.joinedDate),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _AboutSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD0071422),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _AboutRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? SportSphereColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MORE SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _MoreSheet extends StatelessWidget {
  final bool isOwnProfile;
  const _MoreSheet({required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          if (isOwnProfile) ...[
            _SheetOption(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.qr_code_rounded, label: 'QR Code', onTap: () => Navigator.pop(context)),
          ] else ...[
            _SheetOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.block_rounded, label: 'Block', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.flag_outlined, label: 'Report', onTap: () => Navigator.pop(context), isDestructive: true),
          ],
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? SportSphereColors.danger : SportSphereColors.white;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
