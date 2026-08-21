import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import 'profile_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PERSON PROFILE  —  reusable for all individual professional roles:
//   Coach · Scout · Agent · Analyst · Commentator · Journalist
//   Creator · Support Staff · Official · Moderator
// ══════════════════════════════════════════════════════════════════════════════

class PersonProfileModel {
  const PersonProfileModel({
    required this.name,
    required this.handle,
    required this.roleName,
    required this.roleColor,
    required this.accentColor,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.aboutFields,
    this.bio = '',
    this.location = '',
    this.joinedDate,
    this.avatarAsset,
    this.coverAsset,
    this.isVerified = false,
    this.isOwnProfile = false,
    this.hasFanOption = false,
  });

  final String name;
  final String handle;

  /// e.g. 'Coach', 'Journalist', 'Scout'
  final String roleName;

  /// Badge colour for the role pill
  final Color roleColor;

  /// Dominant accent colour (drives cover gradient + highlights)
  final Color accentColor;

  final int postCount;
  final int followerCount;
  final int followingCount;

  /// Key/value rows shown in the About tab — role-specific fields
  final List<PersonAboutField> aboutFields;

  final String bio;
  final String location;
  final DateTime? joinedDate;
  final String? avatarAsset;
  final String? coverAsset;
  final bool isVerified;
  final bool isOwnProfile;

  /// true for coach, scout, agent — shows Become Fan + Follow
  /// false for journalist, analyst, etc. — shows Follow only
  final bool hasFanOption;

  String get atHandle => '@$handle';
}

class PersonAboutField {
  const PersonAboutField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
}


// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class PersonProfileView extends StatefulWidget {
  final PersonProfileModel profile;
  const PersonProfileView({super.key, required this.profile});

  @override
  State<PersonProfileView> createState() => _PersonProfileViewState();
}

class _PersonProfileViewState extends State<PersonProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;
  bool _isFan = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  PersonProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileTabBarDelegate(
              tabBar: _buildTabBar(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SportlightsTab(profile: p),
            _AboutTab(profile: p),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    const coverH = 190.0;
    const avatarR = 44.0;
    final top = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: coverH,
              width: double.infinity,
              child: p.coverAsset != null
                  ? Image.asset(p.coverAsset!, fit: BoxFit.cover)
                  : ProfileCoverGradient(
                      accent: p.accentColor,
                      icon: Icons.person_rounded,
                    ),
            ),
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
            Positioned(
              top: top + 8, left: 12,
              child: ProfileNavButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).maybePop(),
                semanticsLabel: 'Go back',
              ),
            ),
            Positioned(
              top: top + 8, right: 12,
              child: Row(
                children: [
                  ProfileNavButton(
                    icon: Icons.ios_share_rounded,
                    onTap: () {},
                    semanticsLabel: 'Share profile',
                  ),
                  const SizedBox(width: 8),
                  ProfileNavButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: () => _showMore(context),
                    semanticsLabel: 'More options',
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -(avatarR * 0.45), left: 16,
              child: ProfileAvatar(
                asset: p.avatarAsset,
                radius: avatarR,
                accentColor: p.accentColor,
              ),
            ),
          ],
        ),

        SizedBox(height: avatarR * 0.45 + 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              color: SportSphereColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFFFFD700), size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(p.atHandle,
                        style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 14,
                        )),
                    const SizedBox(height: 8),
                    RoleBadge(label: p.roleName, color: p.roleColor),
                  ],
                ),
              ),
              Semantics(
                label: 'About',
                button: true,
                child: GestureDetector(
                  onTap: () => _tabCtrl.animateTo(1),
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

        const SizedBox(height: 14),

        // Stats strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ProfileStat(value: formatCount(p.postCount), label: 'Posts'),
                const ProfileStatDivider(),
                ProfileStat(value: formatCount(p.followerCount), label: 'Followers'),
                const ProfileStatDivider(),
                ProfileStat(value: '${p.followingCount}', label: 'Following'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Action buttons
        if (!p.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: p.hasFanOption
                ? _FanFollowRow(
                    following: _following,
                    isFan: _isFan,
                    accent: p.accentColor,
                    onFollow: () {
                      HapticFeedback.lightImpact();
                      setState(() => _following = !_following);
                    },
                    onBecomeFan: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _isFan = !_isFan);
                    },
                  )
                : _FollowOnlyRow(
                    following: _following,
                    accent: p.accentColor,
                    onFollow: () {
                      HapticFeedback.lightImpact();
                      setState(() => _following = !_following);
                    },
                  ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: SportSphereColors.background,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: SportSphereColors.white,
        unselectedLabelColor: SportSphereColors.muted,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.accentColor, width: 2.5),
          borderRadius: BorderRadius.circular(4),
          insets: const EdgeInsets.symmetric(horizontal: 20),
        ),
        tabs: const [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_rounded, size: 14),
              SizedBox(width: 5),
              Text('Spotlights'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.info_outline_rounded, size: 14),
              SizedBox(width: 5),
              Text('About'),
            ]),
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileMoreSheet(
        isOwnProfile: p.isOwnProfile,
        options: [
          ProfileMoreOption(
            icon: Icons.share_outlined,
            label: 'Share Profile',
            onTap: () => Navigator.pop(context),
          ),
          if (!p.isOwnProfile)
            ProfileMoreOption(
              icon: Icons.flag_outlined,
              label: 'Report',
              onTap: () => Navigator.pop(context),
              destructive: true,
            ),
        ],
      ),
    );
  }
}

// ── Sportlights tab ────────────────────────────────────────────────────────────

class _SportlightsTab extends StatelessWidget {
  final PersonProfileModel profile;
  const _SportlightsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, size: 48,
                color: profile.accentColor.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            const Text('No posts yet',
                style: TextStyle(color: SportSphereColors.white,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Posts from ${profile.name} will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: SportSphereColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── About tab ──────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final PersonProfileModel profile;
  const _AboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
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
        AboutSection(
          title: 'Details',
          child: Column(
            children: [
              ...profile.aboutFields.asMap().entries.map((e) {
                final isLast = e.key == profile.aboutFields.length - 1;
                final field = e.value;
                return AboutRow(
                  icon: field.icon,
                  iconColor: field.iconColor,
                  label: field.label,
                  value: field.value,
                  isLast: isLast,
                );
              }),
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

// ── Action button variants ─────────────────────────────────────────────────────

class _FollowOnlyRow extends StatelessWidget {
  final bool following;
  final Color accent;
  final VoidCallback onFollow;
  const _FollowOnlyRow({
    required this.following,
    required this.accent,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: following ? 'Following' : 'Follow',
      button: true,
      child: GestureDetector(
        onTap: onFollow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: following
                ? null
                : LinearGradient(colors: [
                    SportSphereColors.electricBlue,
                    const Color(0xFF0066DD),
                  ]),
            color: following ? Colors.white.withValues(alpha: 0.06) : null,
            border: following
                ? Border.all(color: Colors.white.withValues(alpha: 0.18))
                : null,
            boxShadow: following
                ? null
                : [
                    BoxShadow(
                      color: SportSphereColors.electricBlue.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              following ? 'Following' : 'Follow',
              style: TextStyle(
                color: following ? SportSphereColors.muted : Colors.white,
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

class _FanFollowRow extends StatelessWidget {
  final bool following;
  final bool isFan;
  final Color accent;
  final VoidCallback onFollow;
  final VoidCallback onBecomeFan;
  const _FanFollowRow({
    required this.following,
    required this.isFan,
    required this.accent,
    required this.onFollow,
    required this.onBecomeFan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: isFan ? 'You are a fan' : 'Become a fan',
            button: true,
            child: GestureDetector(
              onTap: onBecomeFan,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
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
                  child: Text(
                    isFan ? 'Fan ✓' : 'Become Fan',
                    style: TextStyle(
                      color: isFan ? accent : SportSphereColors.muted,
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
        Expanded(
          child: _FollowOnlyRow(
            following: following,
            accent: accent,
            onFollow: onFollow,
          ),
        ),
      ],
    );
  }
}
