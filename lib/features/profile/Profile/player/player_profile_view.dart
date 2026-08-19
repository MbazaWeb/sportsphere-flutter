import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../shared/profile_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class PlayerCareerEntry {
  const PlayerCareerEntry({
    required this.clubName,
    required this.country,
    required this.startYear,
    this.endYear,
    this.leagueName,
    this.appearances,
    this.goals,
  });

  final String clubName;
  final String country;
  final int startYear;
  final int? endYear;           // null = "Present"
  final String? leagueName;
  final int? appearances;
  final int? goals;

  String get periodLabel =>
      endYear == null ? '$startYear–Present' : '$startYear–$endYear';
}

class PlayerSeasonStats {
  const PlayerSeasonStats({
    required this.season,
    required this.competition,
    required this.appearances,
    required this.starts,
    required this.goals,
    required this.assists,
    required this.minutes,
    required this.yellowCards,
    required this.redCards,
    this.cleanSheets,
  });

  final String season;
  final String competition;
  final int appearances;
  final int starts;
  final int goals;
  final int assists;
  final int minutes;
  final int yellowCards;
  final int redCards;
  final int? cleanSheets;
}

class PlayerProfileModel {
  const PlayerProfileModel({
    required this.firstName,
    required this.lastName,
    required this.handle,
    required this.fullName,
    required this.position,
    required this.nationality,
    required this.dob,
    required this.heightCm,
    required this.preferredFoot,
    required this.currentClub,
    required this.currentLeague,
    required this.squadNumber,
    required this.contractStatus,
    required this.accentColor,
    required this.postCount,
    required this.fanCount,
    required this.followerCount,
    required this.followingCount,
    required this.career,
    required this.seasonStats,
    required this.allTimeGoals,
    required this.allTimeAssists,
    required this.allTimeAppearances,
    required this.allTimeMinutes,
    required this.allTimeYellowCards,
    required this.allTimeRedCards,
    this.bio = '',
    this.location = '',
    this.joinedDate,
    this.avatarAsset,
    this.coverAsset,
    this.isVerified = true,
    this.isOwnProfile = false,
  });

  // Identity
  final String firstName;
  final String lastName;
  final String handle;

  // Player info
  final String fullName;
  final String position;
  final String nationality;
  final DateTime dob;
  final int heightCm;
  final String preferredFoot;

  // Club
  final String currentClub;
  final String currentLeague;
  final int squadNumber;
  final String contractStatus;

  // Social stats
  final int postCount;
  final int fanCount;
  final int followerCount;
  final int followingCount;

  // Career & stats
  final List<PlayerCareerEntry> career;
  final List<PlayerSeasonStats> seasonStats;

  // All-time totals
  final int allTimeGoals;
  final int allTimeAssists;
  final int allTimeAppearances;
  final int allTimeMinutes;
  final int allTimeYellowCards;
  final int allTimeRedCards;

  // Optional
  final String bio;
  final String location;
  final DateTime? joinedDate;
  final String? avatarAsset;
  final String? coverAsset;
  final Color accentColor;
  final bool isVerified;
  final bool isOwnProfile;

  String get displayName => '$firstName $lastName';
  String get atHandle => '@$handle';
  int get age {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }
}

// ── Mock: Clatous Chama ────────────────────────────────────────────────────────

final mockClatousChama = PlayerProfileModel(
  firstName: 'Clatous',
  lastName: 'Chama',
  handle: 'clatouschama',
  fullName: 'Clatous Musonda Chama',
  position: 'Forward',
  nationality: 'Zambian',
  dob: DateTime(1992, 12, 25),
  heightCm: 173,
  preferredFoot: 'Right',
  currentClub: 'Simba SC',
  currentLeague: 'Tanzania Premier League',
  squadNumber: 11,
  contractStatus: 'Active',
  accentColor: const Color(0xFFE31B23),
  postCount: 582,
  fanCount: 24600,
  followerCount: 128000,
  followingCount: 98,
  bio: 'Professional footballer. Simba SC 🦁. Playing for the love of the game. 🇿🇲⚽',
  location: 'Dar es Salaam, Tanzania',
  joinedDate: DateTime(2023, 1, 15),
  avatarAsset: 'assets/images/sport_sphere_icon.png',
  isVerified: true,
  allTimeGoals: 87,
  allTimeAssists: 65,
  allTimeAppearances: 142,
  allTimeMinutes: 10842,
  allTimeYellowCards: 18,
  allTimeRedCards: 1,
  career: const [
    PlayerCareerEntry(
      clubName: 'Simba SC',
      country: 'Tanzania',
      startYear: 2024,
      leagueName: 'Tanzania Premier League',
      appearances: 28,
      goals: 14,
    ),
    PlayerCareerEntry(
      clubName: 'Azam FC',
      country: 'Tanzania',
      startYear: 2022,
      endYear: 2024,
      leagueName: 'Tanzania Premier League',
      appearances: 52,
      goals: 31,
    ),
    PlayerCareerEntry(
      clubName: 'Nkana FC',
      country: 'Zambia',
      startYear: 2019,
      endYear: 2022,
      leagueName: 'Zambia Super League',
      appearances: 62,
      goals: 42,
    ),
  ],
  seasonStats: [
    PlayerSeasonStats(
      season: '2026/27',
      competition: 'All',
      appearances: 18,
      starts: 16,
      goals: 11,
      assists: 7,
      minutes: 1380,
      yellowCards: 2,
      redCards: 0,
    ),
    PlayerSeasonStats(
      season: '2025/26',
      competition: 'All',
      appearances: 34,
      starts: 32,
      goals: 22,
      assists: 14,
      minutes: 2760,
      yellowCards: 5,
      redCards: 0,
    ),
  ],
);

// ── Mock posts ─────────────────────────────────────────────────────────────────

final _playerPosts = <ProfilePost>[
  const ProfilePost(
    text: 'Great team performance! 💪🔴⚽\nHongera mashabiki wetu! Maneno ni matatu tu... KAZI IENDELEE! 🔥',
    hashtags: ['#SimbaSC'],
    timeAgo: '2h',
    likes: 5200,
    comments: 368,
    shares: 284,
    hasImage: true,
    imageCount: 2,
  ),
  const ProfilePost(
    text: 'Focused on the next game. One step at a time. 👊',
    hashtags: ['#NguVuMoja'],
    timeAgo: '1d',
    likes: 3100,
    comments: 220,
    shares: 145,
    hasImage: false,
  ),
  const ProfilePost(
    text: 'Training hard every single day. The work never stops. 💥',
    hashtags: ['#Grind', '#SimbaSC'],
    timeAgo: '3d',
    likes: 4800,
    comments: 312,
    shares: 201,
    hasImage: true,
    imageCount: 1,
    hasVideo: true,
  ),
  const ProfilePost(
    text: 'What a night at the stadium! Thank you fans — you gave us wings! 🦁🔴',
    hashtags: ['#WekunduWaMsimbazi'],
    timeAgo: '5d',
    likes: 9100,
    comments: 541,
    shares: 390,
    hasImage: true,
    imageCount: 1,
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class PlayerProfileView extends StatefulWidget {
  final PlayerProfileModel profile;

  const PlayerProfileView({
    super.key,
    required this.profile,
  });

  @override
  State<PlayerProfileView> createState() => _PlayerProfileViewState();
}

class _PlayerProfileViewState extends State<PlayerProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;
  bool _isFan = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  PlayerProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _PlayerHeader(
              profile: p,
              following: _following,
              isFan: _isFan,
              onFollow: () {
                HapticFeedback.lightImpact();
                setState(() => _following = !_following);
              },
              onBecomeFan: () {
                HapticFeedback.mediumImpact();
                setState(() => _isFan = !_isFan);
              },
              onBack: () => Navigator.of(context).maybePop(),
              onShare: () {},
              onMore: () => _showMore(context),
              onInfo: () => _tabCtrl.animateTo(1),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileTabBarDelegate(
              tabBar: _PlayerTabBar(controller: _tabCtrl),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SportlightsTab(profile: p),
            _AboutTab(profile: p),
            _StatsTab(profile: p),
          ],
        ),
      ),
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileMoreSheet(
        isOwnProfile: p.isOwnProfile,
        options: p.isOwnProfile
            ? [
                ProfileMoreOption(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () => Navigator.pop(context)),
                ProfileMoreOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
                ProfileMoreOption(icon: Icons.qr_code_rounded, label: 'QR Code', onTap: () => Navigator.pop(context)),
              ]
            : [
                ProfileMoreOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
                ProfileMoreOption(icon: Icons.block_rounded, label: 'Block', onTap: () => Navigator.pop(context)),
                ProfileMoreOption(icon: Icons.flag_outlined, label: 'Report', onTap: () => Navigator.pop(context), destructive: true),
              ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _PlayerHeader extends StatelessWidget {
  final PlayerProfileModel profile;
  final bool following;
  final bool isFan;
  final VoidCallback onFollow;
  final VoidCallback onBecomeFan;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onInfo;

  const _PlayerHeader({
    required this.profile,
    required this.following,
    required this.isFan,
    required this.onFollow,
    required this.onBecomeFan,
    required this.onBack,
    required this.onShare,
    required this.onMore,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    const coverH = 200.0;
    const avatarR = 46.0;
    final accent = profile.accentColor;
    final top = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cover ─────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover image / gradient
            SizedBox(
              height: coverH,
              width: double.infinity,
              child: profile.coverAsset != null
                  ? Image.asset(profile.coverAsset!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          ProfileCoverGradient(accent: accent, icon: Icons.sports_soccer_rounded))
                  : ProfileCoverGradient(accent: accent, icon: Icons.sports_soccer_rounded),
            ),

            // Bottom fade
            Positioned(
              bottom: 0, left: 0, right: 0, height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      SportSphereColors.background.withValues(alpha: 0.97),
                    ],
                  ),
                ),
              ),
            ),

            // Back
            Positioned(
              top: top + 8, left: 12,
              child: ProfileNavButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
                semanticsLabel: 'Go back',
              ),
            ),

            // Share + More (top right)
            Positioned(
              top: top + 8, right: 12,
              child: Row(
                children: [
                  ProfileNavButton(
                    icon: Icons.ios_share_rounded,
                    onTap: onShare,
                    semanticsLabel: 'Share profile',
                  ),
                  const SizedBox(width: 8),
                  ProfileNavButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: onMore,
                    semanticsLabel: 'More options',
                  ),
                ],
              ),
            ),

            // Avatar overlapping cover bottom
            Positioned(
              bottom: -(avatarR * 0.45),
              left: 16,
              child: ProfileAvatar(
                asset: profile.avatarAsset,
                radius: avatarR,
                accentColor: accent,
              ),
            ),
          ],
        ),

        SizedBox(height: avatarR * 0.45 + 10),

        // ── Identity ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + verified
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            style: const TextStyle(
                              color: SportSphereColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFFFFD700), size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),

                    // @handle
                    Text(
                      profile.atHandle,
                      style: const TextStyle(
                        color: SportSphereColors.muted, fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Role + Club row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Player badge — purple, text only
                        RoleBadge(
                          label: 'Player',
                          color: const Color(0xFF9B6DFF),
                        ),
                        // Club pill
                        _ClubPill(
                          club: profile.currentClub,
                          accent: accent,
                          number: profile.squadNumber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ⓘ About shortcut
              const SizedBox(width: 10),
              Semantics(
                label: 'About this player',
                button: true,
                child: GestureDetector(
                  onTap: onInfo,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: SportSphereColors.muted, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Stats row ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ProfileStat(value: formatCount(profile.postCount), label: 'Posts'),
                const ProfileStatDivider(),
                ProfileStat(value: formatCount(profile.fanCount), label: 'Fans'),
                const ProfileStatDivider(),
                ProfileStat(value: formatCount(profile.followerCount), label: 'Followers'),
                const ProfileStatDivider(),
                ProfileStat(value: '${profile.followingCount}', label: 'Following'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Action buttons ────────────────────────────────────
        if (!profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                // Become Fan
                Expanded(
                  child: Semantics(
                    label: isFan ? 'You are a fan' : 'Become a fan',
                    button: true,
                    child: GestureDetector(
                      onTap: onBecomeFan,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isFan
                              ? accent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: isFan
                                ? accent.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFan ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFan ? accent : SportSphereColors.muted,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isFan ? 'Fan ✓' : 'Become Fan',
                                style: TextStyle(
                                  color: isFan ? accent : SportSphereColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Follow
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
                              ? Border.all(color: Colors.white.withValues(alpha: 0.18))
                              : null,
                          boxShadow: following
                              ? null
                              : [
                                  BoxShadow(
                                    color: SportSphereColors.electricBlue.withValues(alpha: 0.30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            following ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: following ? SportSphereColors.muted : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // DM
                Semantics(
                  label: 'Send message',
                  button: true,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      height: 40, width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: const Icon(Icons.mail_outline_rounded,
                          color: SportSphereColors.muted, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Club pill ──────────────────────────────────────────────────────────────────

class _ClubPill extends StatelessWidget {
  final String club;
  final Color accent;
  final int number;
  const _ClubPill({required this.club, required this.accent, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: accent, size: 12),
          const SizedBox(width: 5),
          Text(
            '$club  ·  #$number',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB BAR  — 3 tabs
// ══════════════════════════════════════════════════════════════════════════════

class _PlayerTabBar extends StatelessWidget {
  final TabController controller;
  const _PlayerTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SportSphereColors.background,
      child: TabBar(
        controller: controller,
        labelColor: SportSphereColors.white,
        unselectedLabelColor: SportSphereColors.muted,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: Color(0xFFE31B23), width: 2.5),
          borderRadius: BorderRadius.circular(4),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 15),
                SizedBox(width: 5),
                Text('Sportlights'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, size: 15),
                SizedBox(width: 5),
                Text('About'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_rounded, size: 15),
                SizedBox(width: 5),
                Text('Stats'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SPORTLIGHTS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _SportlightsTab extends StatelessWidget {
  final PlayerProfileModel profile;
  const _SportlightsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: _playerPosts.length,
      itemBuilder: (_, i) => ProfilePostCard(
        post: _playerPosts[i],
        authorName: profile.displayName,
        authorHandle: profile.atHandle,
        authorAvatarAsset: profile.avatarAsset,
        isVerified: profile.isVerified,
        accentColor: profile.accentColor,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABOUT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _AboutTab extends StatelessWidget {
  final PlayerProfileModel profile;
  const _AboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Bio
        if (profile.bio.isNotEmpty) ...[
          AboutSection(
            title: 'Bio',
            child: Text(profile.bio,
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 15,
                  height: 1.5,
                )),
          ),
          const SizedBox(height: 14),
        ],

        // Player info
        AboutSection(
          title: 'Player Information',
          child: Column(
            children: [
              AboutRow(
                icon: Icons.person_rounded,
                iconColor: SportSphereColors.electricBlue,
                label: 'Full name',
                value: profile.fullName,
              ),
              AboutRow(
                icon: Icons.sports_soccer_rounded,
                iconColor: const Color(0xFF9B6DFF),
                label: 'Position',
                value: profile.position,
              ),
              AboutRow(
                icon: Icons.flag_rounded,
                iconColor: SportSphereColors.sportOrange,
                label: 'Nationality',
                value: profile.nationality,
              ),
              AboutRow(
                icon: Icons.cake_outlined,
                iconColor: SportSphereColors.sportGreen,
                label: 'Date of birth',
                value: '${DateFormat('dd MMM yyyy').format(profile.dob)} (age ${profile.age})',
              ),
              AboutRow(
                icon: Icons.straighten_rounded,
                iconColor: SportSphereColors.brightBlue,
                label: 'Height',
                value: '${profile.heightCm} cm',
              ),
              AboutRow(
                icon: Icons.back_hand_rounded,
                iconColor: SportSphereColors.sportOrange,
                label: 'Preferred foot',
                value: profile.preferredFoot,
                isLast: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Current club
        AboutSection(
          title: 'Current Club',
          child: Column(
            children: [
              AboutRow(
                icon: Icons.shield_rounded,
                iconColor: profile.accentColor,
                label: 'Club',
                value: profile.currentClub,
                valueColor: profile.accentColor,
              ),
              AboutRow(
                icon: Icons.emoji_events_rounded,
                iconColor: SportSphereColors.sportGreen,
                label: 'League',
                value: profile.currentLeague,
              ),
              AboutRow(
                icon: Icons.tag_rounded,
                iconColor: SportSphereColors.electricBlue,
                label: 'Squad number',
                value: '#${profile.squadNumber}',
              ),
              AboutRow(
                icon: Icons.handshake_rounded,
                iconColor: SportSphereColors.muted,
                label: 'Contract',
                value: profile.contractStatus,
                isLast: true,
              ),
            ],
          ),
        ),

        if (profile.joinedDate != null) ...[
          const SizedBox(height: 14),
          AboutSection(
            title: 'SportSphere',
            child: AboutRow(
              icon: Icons.calendar_today_rounded,
              iconColor: SportSphereColors.electricBlue,
              label: 'Joined',
              value: DateFormat('MMMM yyyy').format(profile.joinedDate!),
              isLast: true,
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatefulWidget {
  final PlayerProfileModel profile;
  const _StatsTab({required this.profile});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late String _season;
  late String _competition;

  @override
  void initState() {
    super.initState();
    _season = widget.profile.seasonStats.first.season;
    _competition = 'All';
  }

  PlayerSeasonStats get _currentStats {
    return widget.profile.seasonStats.firstWhere(
      (s) => s.season == _season,
      orElse: () => widget.profile.seasonStats.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final stats = _currentStats;
    final seasons = p.seasonStats.map((s) => s.season).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Season + Competition filters ─────────────────────
        Row(
          children: [
            Expanded(
              child: _FilterPill(
                label: 'Season',
                value: _season,
                options: seasons,
                onChanged: (v) => setState(() => _season = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FilterPill(
                label: 'Competition',
                value: _competition,
                options: const ['All', 'League', 'Cup'],
                onChanged: (v) => setState(() => _competition = v),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Season stats grid ─────────────────────────────────
        _SectionHeader(title: 'Season Stats', season: _season),
        const SizedBox(height: 12),
        _StatsGrid(stats: stats),

        const SizedBox(height: 20),

        // ── All-time career totals ─────────────────────────────
        _SectionHeader(title: 'Career Totals', season: 'All Time'),
        const SizedBox(height: 12),
        _CareerTotalsGrid(profile: p),

        const SizedBox(height: 20),

        // ── Career timeline ───────────────────────────────────
        _SectionHeader(title: 'Career', season: ''),
        const SizedBox(height: 12),
        _CareerTimeline(career: p.career, accent: p.accentColor),
      ],
    );
  }
}

// ── Filter pill ────────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterPill({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SportSphereColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: SportSphereColors.surface2,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              icon: const Icon(Icons.expand_more_rounded,
                  color: SportSphereColors.muted, size: 18),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => v != null ? onChanged(v) : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String season;
  const _SectionHeader({required this.title, required this.season});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bar_chart_rounded,
            color: SportSphereColors.muted, size: 16),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            )),
        if (season.isNotEmpty) ...[
          const Spacer(),
          Text(season,
              style: TextStyle(
                color: SportSphereColors.muted.withValues(alpha: 0.55),
                fontSize: 11,
              )),
        ],
      ],
    );
  }
}

// ── Season stats grid ──────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final PlayerSeasonStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _StatEntry(icon: Icons.calendar_today_rounded, iconColor: SportSphereColors.electricBlue, label: 'Appearances', value: '${stats.appearances}'),
      _StatEntry(icon: Icons.play_arrow_rounded, iconColor: SportSphereColors.sportGreen, label: 'Starts', value: '${stats.starts}'),
      _StatEntry(icon: Icons.sports_soccer_rounded, iconColor: const Color(0xFFE31B23), label: 'Goals', value: '${stats.goals}'),
      _StatEntry(icon: Icons.assistant_rounded, iconColor: SportSphereColors.sportOrange, label: 'Assists', value: '${stats.assists}'),
      _StatEntry(icon: Icons.timer_outlined, iconColor: SportSphereColors.brightBlue, label: 'Minutes', value: _fmtMin(stats.minutes)),
      _StatEntry(icon: Icons.square_rounded, iconColor: const Color(0xFFFFD700), label: 'Yellow Cards', value: '${stats.yellowCards}'),
      _StatEntry(icon: Icons.square_rounded, iconColor: const Color(0xFFE31B23), label: 'Red Cards', value: '${stats.redCards}'),
    ];

    return _StatCard(entries: rows);
  }

  String _fmtMin(int m) {
    if (m >= 1000) return "${(m / 1000).toStringAsFixed(1)}K'";
    return "$m'";
  }
}

// ── Career totals grid ─────────────────────────────────────────────────────────

class _CareerTotalsGrid extends StatelessWidget {
  final PlayerProfileModel profile;
  const _CareerTotalsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _StatEntry(icon: Icons.sports_soccer_rounded, iconColor: const Color(0xFFE31B23), label: 'Goals', value: '${profile.allTimeGoals}'),
      _StatEntry(icon: Icons.assistant_rounded, iconColor: SportSphereColors.sportOrange, label: 'Assists', value: '${profile.allTimeAssists}'),
      _StatEntry(icon: Icons.calendar_today_rounded, iconColor: SportSphereColors.electricBlue, label: 'Appearances', value: '${profile.allTimeAppearances}'),
      _StatEntry(icon: Icons.timer_outlined, iconColor: SportSphereColors.brightBlue, label: 'Minutes', value: _fmtMin(profile.allTimeMinutes)),
      _StatEntry(icon: Icons.square_rounded, iconColor: const Color(0xFFFFD700), label: 'Yellow Cards', value: '${profile.allTimeYellowCards}'),
      _StatEntry(icon: Icons.square_rounded, iconColor: const Color(0xFFE31B23), label: 'Red Cards', value: '${profile.allTimeRedCards}'),
    ];
    return _StatCard(entries: rows);
  }

  String _fmtMin(int m) {
    final s = m.toString();
    // format 10842 → 10,842
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _StatEntry {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatEntry({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
}

class _StatCard extends StatelessWidget {
  final List<_StatEntry> entries;
  const _StatCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD0071422),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          final isLast = i == entries.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e.iconColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(e.icon, color: e.iconColor, size: 16),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(e.label,
                          style: const TextStyle(
                            color: SportSphereColors.muted,
                            fontSize: 14,
                          )),
                    ),
                    Text(e.value,
                        style: const TextStyle(
                          color: SportSphereColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Career timeline ────────────────────────────────────────────────────────────

class _CareerTimeline extends StatelessWidget {
  final List<PlayerCareerEntry> career;
  final Color accent;
  const _CareerTimeline({required this.career, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD0071422),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: List.generate(career.length, (i) {
          final entry = career[i];
          final isLast = i == career.length - 1;
          return _CareerRow(
            entry: entry,
            accent: accent,
            isLast: isLast,
            isFirst: i == 0,
          );
        }),
      ),
    );
  }
}

class _CareerRow extends StatelessWidget {
  final PlayerCareerEntry entry;
  final Color accent;
  final bool isLast;
  final bool isFirst;

  const _CareerRow({
    required this.entry,
    required this.accent,
    required this.isLast,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 12, height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? accent : Colors.white.withValues(alpha: 0.25),
                    border: isFirst
                        ? null
                        : Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period
                  Text(
                    entry.periodLabel,
                    style: TextStyle(
                      color: isFirst
                          ? accent
                          : SportSphereColors.muted.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Club name
                  Text(entry.clubName,
                      style: TextStyle(
                        color: isFirst ? SportSphereColors.white : SportSphereColors.muted,
                        fontSize: 15,
                        fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                      )),

                  // League + country
                  if (entry.leagueName != null || entry.country.isNotEmpty)
                    Text(
                      [if (entry.country.isNotEmpty) entry.country,
                        if (entry.leagueName != null) entry.leagueName!].join(' · '),
                      style: TextStyle(
                        color: SportSphereColors.muted.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),

                  // Mini stats
                  if (entry.appearances != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        children: [
                          _MiniStat(label: 'Apps', value: '${entry.appearances}'),
                          if (entry.goals != null) ...[
                            const SizedBox(width: 14),
                            _MiniStat(label: 'Goals', value: '${entry.goals}'),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$value ',
            style: const TextStyle(
              color: SportSphereColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            )),
        Text(label,
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.7),
              fontSize: 12,
            )),
      ],
    );
  }
}
