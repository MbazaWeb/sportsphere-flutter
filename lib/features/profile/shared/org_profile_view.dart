import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import 'profile_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ORG PROFILE  — reusable for structured entity roles:
//   Academy · League · Competition · Organization
//   Community · Media/Broadcast · Venue
// ══════════════════════════════════════════════════════════════════════════════

class OrgMember {
  const OrgMember({
    required this.name,
    required this.role,
    this.handle,
    this.profileRoute,
  });
  final String name;
  final String role;
  final String? handle;
  final String? profileRoute;
}

class OrgProfileModel {
  const OrgProfileModel({
    required this.name,
    required this.handle,
    required this.roleName,
    required this.roleColor,
    required this.accentColor,
    required this.postCount,
    required this.fanCount,
    required this.followingCount,
    required this.aboutFields,
    this.members = const [],
    this.membersLabel = 'Members',
    this.bio = '',
    this.location = '',
    this.joinedDate,
    this.logoAsset,
    this.coverAsset,
    this.isVerified = false,
    this.isOwnProfile = false,
  });

  final String name;
  final String handle;
  final String roleName;
  final Color roleColor;
  final Color accentColor;
  final int postCount;
  final int fanCount;
  final int followingCount;
  final List<PersonAboutField> aboutFields;
  final List<OrgMember> members;
  final String membersLabel;
  final String bio;
  final String location;
  final DateTime? joinedDate;
  final String? logoAsset;
  final String? coverAsset;
  final bool isVerified;
  final bool isOwnProfile;

  String get atHandle => '@$handle';
}

// ── Mock posts ─────────────────────────────────────────────────────────────────

final _orgPosts = <ProfilePost>[
  const ProfilePost(
    text: 'Welcome to the official SportSphere page! Follow for updates, news and community content.',
    hashtags: [],
    timeAgo: '1h',
    likes: 3420,
    comments: 184,
    shares: 96,
    hasImage: true,
    imageCount: 1,
  ),
  const ProfilePost(
    text: 'Exciting announcements coming this season. Stay connected and be part of the journey.',
    hashtags: ['#StayConnected'],
    timeAgo: '2d',
    likes: 1880,
    comments: 72,
    shares: 44,
  ),
  const ProfilePost(
    text: 'Thank you to all our members and supporters for the incredible response. More to come! 🙏',
    hashtags: [],
    timeAgo: '5d',
    likes: 2540,
    comments: 118,
    shares: 65,
    hasImage: true,
    imageCount: 2,
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class OrgProfileView extends StatefulWidget {
  final OrgProfileModel profile;
  const OrgProfileView({super.key, required this.profile});

  @override
  State<OrgProfileView> createState() => _OrgProfileViewState();
}

class _OrgProfileViewState extends State<OrgProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.profile.members.isNotEmpty ? 3 : 2;
    _tabCtrl = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  OrgProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    final hasMembers = p.members.isNotEmpty;

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileTabBarDelegate(tabBar: _buildTabBar(hasMembers)),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _OrgSportlightsTab(profile: p),
            _OrgAboutTab(profile: p),
            if (hasMembers) _OrgMembersTab(profile: p),
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
                      icon: Icons.corporate_fare_rounded,
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
                    semanticsLabel: 'Share',
                  ),
                  const SizedBox(width: 8),
                  ProfileNavButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: () {},
                    semanticsLabel: 'More options',
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -(avatarR * 0.45), left: 16,
              child: ProfileAvatar(
                asset: p.logoAsset,
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
                            color: SportSphereColors.muted, fontSize: 14)),
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
                ProfileStat(value: formatCount(p.fanCount), label: 'Followers'),
                const ProfileStatDivider(),
                ProfileStat(value: '${p.followingCount}', label: 'Following'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        if (!p.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: _following ? 'Following' : 'Follow',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _following = !_following);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          gradient: _following
                              ? null
                              : const LinearGradient(colors: [
                                  SportSphereColors.electricBlue,
                                  Color(0xFF0066DD),
                                ]),
                          color: _following
                              ? Colors.white.withValues(alpha: 0.06)
                              : null,
                          border: _following
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.18))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _following ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: _following
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
                Container(
                  height: 42, width: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: SportSphereColors.muted, size: 20),
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTabBar(bool hasMembers) {
    return Container(
      color: SportSphereColors.background,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: SportSphereColors.white,
        unselectedLabelColor: SportSphereColors.muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.accentColor, width: 2.5),
          borderRadius: BorderRadius.circular(4),
          insets: const EdgeInsets.symmetric(horizontal: 20),
        ),
        tabs: [
          const Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_rounded, size: 14),
              SizedBox(width: 5),
              Text('Spotlights'),
            ]),
          ),
          const Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.info_outline_rounded, size: 14),
              SizedBox(width: 5),
              Text('About'),
            ]),
          ),
          if (hasMembers)
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_rounded, size: 14),
                const SizedBox(width: 5),
                Text(p.membersLabel),
              ]),
            ),
        ],
      ),
    );
  }
}

class _OrgSportlightsTab extends StatelessWidget {
  final OrgProfileModel profile;
  const _OrgSportlightsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: _orgPosts.length,
      itemBuilder: (_, i) => ProfilePostCard(
        post: _orgPosts[i],
        authorName: profile.name,
        authorHandle: profile.atHandle,
        authorAvatarAsset: profile.logoAsset,
        isVerified: profile.isVerified,
        accentColor: profile.accentColor,
      ),
    );
  }
}

class _OrgAboutTab extends StatelessWidget {
  final OrgProfileModel profile;
  const _OrgAboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (profile.bio.isNotEmpty) ...[
          AboutSection(
            title: 'About',
            child: Text(profile.bio,
                style: const TextStyle(
                    color: SportSphereColors.white, fontSize: 15, height: 1.5)),
          ),
          const SizedBox(height: 14),
        ],
        AboutSection(
          title: 'Details',
          child: Column(
            children: profile.aboutFields.asMap().entries.map((e) {
              return AboutRow(
                icon: e.value.icon,
                iconColor: e.value.iconColor,
                label: e.value.label,
                value: e.value.value,
                isLast: e.key == profile.aboutFields.length - 1,
              );
            }).toList(),
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

class _OrgMembersTab extends StatelessWidget {
  final OrgProfileModel profile;
  const _OrgMembersTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: profile.members.length,
      itemBuilder: (_, i) {
        final m = profile.members[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xD0071422),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: profile.accentColor.withValues(alpha: 0.12),
                border: Border.all(
                    color: profile.accentColor.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.person_rounded,
                  color: profile.accentColor.withValues(alpha: 0.7), size: 20),
            ),
            title: Text(m.name,
                style: const TextStyle(
                    color: SportSphereColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            subtitle: Text(m.role,
                style: const TextStyle(
                    color: SportSphereColors.muted, fontSize: 12)),
            trailing: m.profileRoute != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: SportSphereColors.muted, size: 20)
                : null,
            onTap: m.profileRoute != null ? () {} : null,
          ),
        );
      },
    );
  }
}
