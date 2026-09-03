import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/branding.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../shop/presentation/shop_tab.dart';
import '../shared/profile_widgets.dart';
import '../presentation/people_list_sheet.dart';
import '../presentation/edit_profile_sheet.dart';
import '../../claims/presentation/claim_profile_sheet.dart';
import 'role_profile_model.dart';
import '../../../core/data/social_graph.dart';

class RoleProfileShell extends ConsumerStatefulWidget {
  const RoleProfileShell({super.key, required this.profile});
  final RoleProfileModel profile;

  @override
  ConsumerState<RoleProfileShell> createState() => _RoleProfileShellState();
}

class _RoleProfileShellState extends ConsumerState<RoleProfileShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;
  bool _isFan = false;
  final _graph = const SocialGraph();
  RoleProfileModel get p => widget.profile;

  /// #6.2 — Officials (admin/Playify) should NOT show a "Become a Fan" button.
  /// _allowsFan is true only for roles that represent a person/org you can
  /// be a fan OF (player, coach, scout, agent, academy, team) or any other
  /// person role EXCEPT `official`. The admin/Playify handle is also
  /// explicitly excluded so the platform account never shows the CTA.
  bool get _allowsFan {
    final r = p.roleLabel.toLowerCase();
    if (r.contains('official')) return false;
    if (isOfficialHandle(p.handle)) return false;
    return r.contains('coach') ||
        r.contains('player') ||
        r.contains('scout') ||
        r.contains('agent') ||
        r.contains('academy') ||
        r.contains('team') ||
        p.shape == RoleShape.person;
  }

  List<_TabSpec> get _tabs {
    final tabs = <_TabSpec>[
      _TabSpec('Sportlights', Icons.bolt_rounded, _Sportlights(p: p)),
      _TabSpec('About', Icons.info_outline_rounded, _About(p: p)),
    ];
    if (p.shape != RoleShape.person && p.members.isNotEmpty) {
      tabs.add(_TabSpec(p.membersTitle, Icons.people_rounded, _Members(p: p)));
    }
    if (p.statsRows.isNotEmpty) {
      tabs.add(_TabSpec('Stats', Icons.bar_chart_rounded, _Stats(p: p)));
    }
    if (p.shop != null) {
      tabs.add(_TabSpec('Shop', Icons.storefront_rounded, ShopTab(catalog: p.shop!)));
    }
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadSocial();
  }

  /// #6.4 — For org roles the profile handle is the entity slug, not a User
  /// handle. `SocialGraph.resolveId` only queries the User table by handle,
  /// so prefer `model.entityId` when it is populated (i.e. when we have an
  /// entity-table row with its own id that maps to a User via accountUserId).
  Future<void> _loadSocial() async {
    final me = _graph.currentUid;
    if (me == null) return;
    try {
      // resolveId now returns String? (returns null when no match found),
      // so prefer the captured entityId and only fall back to the graph
      // lookup when we don't already have an entity id.
      final String? id = p.entityId ?? await _graph.resolveId(p.handle);
      if (id == null || id.isEmpty) return;
      final f = await _graph.isFollowing(me, id);
      final n = _allowsFan ? await _graph.isFan(me, id) : false;
      if (mounted) {
        setState(() {
          _following = f;
          _isFan = n;
        });
      }
    } catch (e) {
      debugPrint('_loadSocial: $e');
    }
  }

  /// #6.4 — Resolves a profile target id, preferring the captured
  /// `entityId` when available (org roles) so follow/fan state maps to the
  /// entity's underlying account user. Returns null if the id cannot be
  /// resolved (in which case follow/fan are skipped).
  Future<String?> _resolveTargetId() async {
    if (p.entityId != null && p.entityId!.isNotEmpty) return p.entityId;
    return _graph.resolveId(p.handle);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _shareProfile() {
    final role = (p.profileType ?? p.roleLabel.toLowerCase())
        .replaceAll('_', '-')
        .replaceAll(' ', '-');
    final url = 'https://playify.app/role/$role/${p.handle}';
    final text = 'Check out ${p.displayName} (${p.atHandle}) on Playify: $url';
    Share.share(text, subject: '${p.displayName} on Playify');
  }

  void _showMoreSheet() {
    final options = <ProfileMoreOption>[
      if (p.isOwnProfile)
        ProfileMoreOption(
          icon: Icons.edit_rounded,
          label: 'Edit profile',
          onTap: () {
            Navigator.pop(context);
            _showEditProfile();
          },
        ),
      ProfileMoreOption(
        icon: Icons.ios_share_rounded,
        label: 'Share profile',
        onTap: () {
          Navigator.pop(context);
          _shareProfile();
        },
      ),
      ProfileMoreOption(
        icon: Icons.link_rounded,
        label: 'Copy link',
        onTap: () {
          Navigator.pop(context);
          final role = (p.profileType ?? p.roleLabel.toLowerCase())
              .replaceAll('_', '-')
              .replaceAll(' ', '-');
          final url = 'https://playify.app/role/$role/${p.handle}';
          Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile link copied')),
            );
          }
        },
      ),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => ProfileMoreSheet(
        isOwnProfile: p.isOwnProfile,
        options: options,
      ),
    );
  }

  /// #6.10 — Edit-profile entry point. Pulls the live UserProfile from the
  /// auth controller so the edit sheet pre-fills with the stored values.
  void _showEditProfile() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to edit your profile')),
      );
      return;
    }
    showEditProfileSheet(context, user);
  }

  /// #6.5 — When the "Members"/"Clubs"/"Squad"/"Staff" stat is tapped we
  /// open a sheet listing the entity's preloaded members.
  void _showMembersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _MembersSheet(p: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      backgroundColor: PlayifyColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _Header(
              p: p,
              following: _following,
              isFan: _isFan,
              showFan: _allowsFan,
              onFollow: () async {
                HapticFeedback.lightImpact();
                final next = !_following;
                setState(() => _following = next);
                try {
                  final id = await _resolveTargetId();
                  if (id == null || id.isEmpty) {
                    if (mounted) setState(() => _following = !next);
                    return;
                  }
                  await _graph.follow(id, on: next);
                } catch (e) {
                  debugPrint('onFollow: $e');
                  if (mounted) setState(() => _following = !next);
                }
              },
              onBecomeFan: () async {
                HapticFeedback.mediumImpact();
                final next = !_isFan;
                setState(() => _isFan = next);
                try {
                  final id = await _resolveTargetId();
                  if (id == null || id.isEmpty) {
                    if (mounted) setState(() => _isFan = !next);
                    return;
                  }
                  await _graph.fan(id, on: next);
                  final me = _graph.currentUid;
                  if (me != null) await _graph.refreshCounts(me);
                } catch (e) {
                  debugPrint('onBecomeFan: $e');
                  if (mounted) setState(() => _isFan = !next);
                }
              },
              onBack: () => Navigator.of(context).maybePop(),
              onShare: _shareProfile,
              onMore: _showMoreSheet,
              onMembers: _showMembersSheet,
              onShop: p.shop == null ? null : () => _tabCtrl.animateTo(tabs.length - 1),
              onEditProfile: _showEditProfile,
              onClaim: (!p.isOwnProfile && p.isClaimable)
                  ? () => showClaimProfileSheet(
                        context,
                        profileType: p.profileType ?? p.roleLabel.toLowerCase(),
                        profileId: p.entityId ?? p.handle,
                        profileName: p.displayName,
                        teamId: p.profileType == 'team' ? p.entityId : null,
                        playerId: p.profileType == 'player' ? p.entityId : null,
                        coachId: p.profileType == 'coach' ? p.entityId : null,
                      )
                  : null,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileTabBarDelegate(
              tabBar: Container(
                color: PlayifyColors.background,
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: PlayifyColors.white,
                  unselectedLabelColor: PlayifyColors.muted,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(color: p.accent, width: 2.5),
                    borderRadius: BorderRadius.circular(4),
                    insets: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  tabs: [
                    for (final t in tabs)
                      Tab(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t.icon, size: 14),
                          const SizedBox(width: 5),
                          Text(t.label),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [for (final t in tabs) t.child],
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.child);
  final String label;
  final IconData icon;
  final Widget child;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.p,
    required this.following,
    required this.isFan,
    required this.showFan,
    required this.onFollow,
    required this.onBecomeFan,
    this.onClaim,
    required this.onBack,
    required this.onShare,
    required this.onMore,
    required this.onMembers,
    this.onShop,
    this.onEditProfile,
  });
  final RoleProfileModel p;
  final bool following;
  final bool isFan;
  final bool showFan;
  final VoidCallback onFollow;
  final VoidCallback onBecomeFan;
  final VoidCallback? onClaim;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onMembers;
  final VoidCallback? onShop;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    // #6.3 — Resolve avatar: official Playify handle → official avatar asset;
    // else use the loaded avatarUrl (User.avatarUrl or profiles.avatar_url);
    // else fall back to the generic person icon inside ProfileAvatar.
    final String? avatarAsset = isOfficialHandle(p.handle)
        ? (kOfficialAvatarUrl.isNotEmpty ? kOfficialAvatarUrl : kOfficialAvatarAsset)
        : p.avatarUrl;

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: Stack(
            children: [
              Positioned.fill(child: ProfileCoverGradient(accent: p.accent, icon: p.coverIcon)),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                child: ProfileNavButton(icon: Icons.arrow_back_rounded, onTap: onBack, semanticsLabel: 'Back'),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProfileNavButton(
                      icon: Icons.ios_share_rounded,
                      onTap: onShare,
                      semanticsLabel: 'Share profile',
                    ),
                    const SizedBox(width: 8),
                    ProfileNavButton(
                      icon: Icons.more_vert_rounded,
                      onTap: onMore,
                      semanticsLabel: 'More options',
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: ProfileAvatar(
                  asset: avatarAsset,
                  radius: 42,
                  accentColor: p.accent,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(p.displayName,
                      style: const TextStyle(color: PlayifyColors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                if (p.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 20),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(p.atHandle, style: const TextStyle(color: PlayifyColors.muted, fontSize: 13)),
                const SizedBox(width: 8),
                RoleBadge(label: p.roleLabel, color: p.accent),
              ]),
              const SizedBox(height: 6),
              Text(p.subtitle, style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              if (p.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.bio, style: const TextStyle(color: PlayifyColors.white, fontSize: 14, height: 1.4)),
              ],
              if (p.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: PlayifyColors.muted),
                  const SizedBox(width: 4),
                  Text(p.location, style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
                ]),
              ],
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 0; i < p.headerStats.length; i++) ...[
                  if (i > 0) const ProfileStatDivider(),
                  ProfileStat(
                    value: p.headerStats[i].value,
                    label: p.headerStats[i].label,
                    onTap: () => _onStatTap(context, p.headerStats[i].label),
                  ),
                ],
              ]),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // #6.10 — Hide Follow / Become a fan / Claim buttons when the
                  // viewer is the profile owner. Showing these on the user's own
                  // profile is confusing (tapping Follow surfaces "You can't
                  // follow yourself"). Instead, on own profile, show a single
                  // "Edit profile" CTA so the Row is never empty.
                  if (p.isOwnProfile) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onEditProfile?.call(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            color: p.accent,
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Edit profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (showFan) ...[
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: onBecomeFan,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isFan ? p.accent.withValues(alpha: 0.18) : p.accent,
                            border: isFan ? Border.all(color: p.accent.withValues(alpha: 0.7)) : null,
                          ),
                          child: Center(
                            child: Text(
                              isFan ? 'You are a fan' : 'Become a fan',
                              style: TextStyle(
                                color: isFan ? p.accent : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: onFollow,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: following ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
                            border: Border.all(
                              color: following
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : PlayifyColors.electricBlue.withValues(alpha: 0.75),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              following ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: following ? PlayifyColors.muted : PlayifyColors.electricBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: GestureDetector(
                        onTap: onFollow,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            color: following ? Colors.white.withValues(alpha: 0.06) : p.accent,
                            border: following ? Border.all(color: Colors.white.withValues(alpha: 0.18)) : null,
                          ),
                          child: Center(
                            child: Text(following ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: following ? PlayifyColors.muted : Colors.white,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                      ),
                    ),
                  // #6.9 — ClaimProfileButton was wrapped in Padding(top: 10)
                  // which misaligned it inside the Row. Removed the wrapper so
                  // all action buttons share the same vertical center.
                  if (onClaim != null) ...[
                    const SizedBox(width: 10),
                    ClaimProfileButton(onTap: onClaim!),
                  ],
                  if (onShop != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onShop,
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.storefront_rounded, size: 16, color: PlayifyColors.white),
                          SizedBox(width: 6),
                          Text('Shop', style: TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// #6.5 — Stats whose label maps to "Members"/"Clubs"/"Squad"/"Staff" open
  /// a sheet listing the entity's members rather than the standard
  /// PeopleListSheet (which only handles fans/followers/following).
  void _onStatTap(BuildContext context, String label) {
    final l = label.toLowerCase();
    if (l.contains('fan')) {
      showPeopleList(
        context,
        userId: p.entityId ?? p.handle,
        handle: p.handle,
        kind: PeopleListKind.fans,
      );
      return;
    }
    if (l.contains('following')) {
      showPeopleList(
        context,
        userId: p.entityId ?? p.handle,
        handle: p.handle,
        kind: PeopleListKind.following,
      );
      return;
    }
    if (l.contains('follower')) {
      showPeopleList(
        context,
        userId: p.entityId ?? p.handle,
        handle: p.handle,
        kind: PeopleListKind.followers,
      );
      return;
    }
    // Members / Clubs / Squad / Staff → entity members sheet.
    if (l.contains('member') ||
        l.contains('club') ||
        l.contains('squad') ||
        l.contains('staff')) {
      onMembers();
    }
  }
}

class _Sportlights extends StatelessWidget {
  const _Sportlights({required this.p});
  final RoleProfileModel p;

  @override
  Widget build(BuildContext context) {
    if (p.posts.isEmpty) {
      return const Center(child: Text('No Sportlights yet', style: TextStyle(color: PlayifyColors.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      itemCount: p.posts.length,
      itemBuilder: (_, i) => ProfilePostCard(
        post: p.posts[i],
        authorName: p.displayName,
        authorHandle: p.atHandle,
        accentColor: p.accent,
        isVerified: p.isVerified,
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.p});
  final RoleProfileModel p;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (p.bio.isNotEmpty) ...[
          const Text('Bio', style: TextStyle(color: PlayifyColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(p.bio, style: const TextStyle(color: PlayifyColors.white, height: 1.45)),
          const SizedBox(height: 20),
        ],
        for (final f in p.aboutFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 118, child: Text(f.label, style: const TextStyle(color: PlayifyColors.muted, fontSize: 13))),
                Expanded(
                  child: Text(f.value,
                      style: const TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Members extends StatelessWidget {
  const _Members({required this.p});
  final RoleProfileModel p;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: p.members.length,
      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
      itemBuilder: (_, i) {
        final m = p.members[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: p.accent.withValues(alpha: 0.18),
            child: Text(m.name.isNotEmpty ? m.name[0] : '?',
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
          ),
          title: Text(m.name, style: const TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w700)),
          subtitle: Text('${m.subtitle}  ·  @${m.handle}',
              style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
          onTap: m.route == null ? null : () => context.push(m.route!),
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.p});
  final RoleProfileModel p;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        for (final r in p.statsRows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xD8071422),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(children: [
              Expanded(child: Text(r.label, style: const TextStyle(color: PlayifyColors.muted))),
              Text(r.value, style: const TextStyle(color: PlayifyColors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
      ],
    );
  }
}

/// #6.5 — Bottom sheet that lists an entity's preloaded members
/// (teams for a league, players for a coach/academy, etc.).
class _MembersSheet extends StatelessWidget {
  const _MembersSheet({required this.p});
  final RoleProfileModel p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.membersTitle,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: PlayifyColors.white)),
            const SizedBox(height: 12),
            Expanded(
              child: p.members.isEmpty
                  ? const Center(
                      child: Text('No members yet',
                          style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.separated(
                      itemCount: p.members.length,
                      separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withValues(alpha: 0.06), height: 1),
                      itemBuilder: (_, i) {
                        final m = p.members[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: p.accent.withValues(alpha: 0.18),
                            child: Text(
                              m.name.isNotEmpty ? m.name[0] : '?',
                              style: TextStyle(
                                  color: p.accent, fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(m.name,
                              style: const TextStyle(
                                  color: PlayifyColors.white,
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text('${m.subtitle}  ·  @${m.handle}',
                              style: const TextStyle(
                                  color: PlayifyColors.muted, fontSize: 12)),
                          onTap: m.route == null
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  context.push(m.route!);
                                },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
