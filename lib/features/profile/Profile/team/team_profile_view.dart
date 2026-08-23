import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/admin/app_admin.dart';
import '../../../../core/data/social_graph.dart';
import '../../../../core/theme/colors.dart';
import '../../shared/profile_widgets.dart';
import '../../../shop/models/shop_models.dart';
import '../../../shop/presentation/shop_tab.dart';
import '../../presentation/edit_profile_sheet.dart'
    show showEntityEditSheet, EntityType;

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum SquadRole { player, coach, staff }

class SquadMember {
  const SquadMember({
    required this.name,
    required this.handle,
    required this.role,
    required this.subrole,   // e.g. 'Forward', 'Head Coach', 'Physiotherapist'
    this.squadNumber,
    this.nationality,
    this.avatarAsset,
    this.profileRoute,       // '/player/clatouschama' or '/profile/mbaza'
  });

  final String name;
  final String handle;
  final SquadRole role;
  final String subrole;
  final int? squadNumber;
  final String? nationality;
  final String? avatarAsset;
  final String? profileRoute;  // null = no navigable profile yet
}

class TeamSeasonStats {
  const TeamSeasonStats({
    required this.season,
    required this.competition,
    required this.matches,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.cleanSheets,
    required this.leaguePosition,
  });

  final String season;
  final String competition;
  final int matches;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int cleanSheets;
  final int leaguePosition;

  int get goalDifference => goalsFor - goalsAgainst;
  int get points => wins * 3 + draws;
}

class TeamProfileModel {
  const TeamProfileModel({
    required this.name,
    required this.handle,
    required this.sport,
    required this.competition,
    required this.country,
    required this.city,
    required this.stadium,
    required this.founded,
    required this.coach,
    required this.description,
    required this.accentColor,
    required this.postCount,
    required this.fanCount,
    required this.followingCount,
    required this.squad,
    required this.seasonStats,
    this.id,
    this.accountUserId,
    this.shortName,
    this.primaryColorHex,
    this.leagueId,
    this.logoAsset,
    this.coverAsset,
    this.isVerified = true,
    this.isOwnProfile = false,
    this.joinedDate,
  });

  /// SportSphere Team row id (e.g. "team-123"). Null when the lookup did not
  /// resolve the underlying DB record (admin-only edit relies on this).
  final String? id;
  /// Linked auth User.id for the team's account (used by SocialGraph).
  final String? accountUserId;
  final String? shortName;
  final String? primaryColorHex;
  final String? leagueId;

  final String name;
  final String handle;
  final String sport;
  final String competition;
  final String country;
  final String city;
  final String stadium;
  final int founded;
  final String coach;
  final String description;
  final Color accentColor;

  final int postCount;
  final int fanCount;
  final int followingCount;

  final List<SquadMember> squad;
  final List<TeamSeasonStats> seasonStats;

  final String? logoAsset;
  final String? coverAsset;
  final bool isVerified;
  final bool isOwnProfile;
  final DateTime? joinedDate;

  String get atHandle => '@$handle';

  List<SquadMember> get players =>
      squad.where((m) => m.role == SquadRole.player).toList();
  List<SquadMember> get coaches =>
      squad.where((m) => m.role == SquadRole.coach).toList();
  List<SquadMember> get staff =>
      squad.where((m) => m.role == SquadRole.staff).toList();
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class TeamProfileView extends StatefulWidget {
  final TeamProfileModel profile;
  const TeamProfileView({super.key, required this.profile});

  @override
  State<TeamProfileView> createState() => _TeamProfileViewState();
}

class _TeamProfileViewState extends State<TeamProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;
  bool _isFan = false;
  bool _busyFollow = false;
  bool _busyFan = false;
  final _graph = SocialGraph();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadSocial();
  }

  /// #7.2 / #7.3 — resolve the team's social target (accountUserId if known,
  /// otherwise resolve handle via SocialGraph) and pull the current viewer's
  /// follow + fan status.
  Future<void> _loadSocial() async {
    final me = _graph.currentUid;
    if (me == null) return;
    try {
      final id = p.accountUserId ?? await _graph.resolveId(p.handle);
      if (id == null) return;
      final f = await _graph.isFollowing(me, id);
      final n = await _graph.isFan(me, id);
      if (mounted) setState(() { _following = f; _isFan = n; });
    } catch (e) {
      debugPrint('team _loadSocial: $e');
    }
  }

  /// Resolve the social target id (accountUserId preferred, else handle lookup).
  /// Returns null if the target cannot be resolved.
  Future<String?> _resolveTarget() async {
    if (p.accountUserId != null && p.accountUserId!.isNotEmpty) {
      return p.accountUserId;
    }
    return _graph.resolveId(p.handle);
  }

  Future<void> _toggleFollow() async {
    if (_busyFollow) return;
    HapticFeedback.lightImpact();
    final next = !_following;
    setState(() { _following = next; _busyFollow = true; });
    try {
      final id = await _resolveTarget();
      if (id == null) throw StateError('team profile not found');
      await _graph.follow(id, on: next);
    } catch (e) {
      debugPrint('team follow: $e');
      if (mounted) {
        setState(() => _following = !next);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${next ? 'follow' : 'unfollow'}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Future<void> _toggleFan() async {
    if (_busyFan) return;
    HapticFeedback.mediumImpact();
    final next = !_isFan;
    setState(() { _isFan = next; _busyFan = true; });
    try {
      final id = await _resolveTarget();
      if (id == null) throw StateError('team profile not found');
      await _graph.fan(id, on: next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next
              ? 'You are now a ${p.name} fan'
              : 'Removed fan status'),
        ));
      }
    } catch (e) {
      debugPrint('team fan: $e');
      if (mounted) {
        setState(() => _isFan = !next);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${next ? 'become a fan' : 'unfan'}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyFan = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  TeamProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _TeamHeader(
              profile: p,
              following: _following,
              isFan: _isFan,
              busyFollow: _busyFollow,
              busyFan: _busyFan,
              onFollow: _toggleFollow,
              onBecomeFan: _toggleFan,
              onBack: () => Navigator.of(context).maybePop(),
              onShare: () {},
              onMore: () => _showMore(context),
              onInfo: () => _tabCtrl.animateTo(1),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: ProfileTabBarDelegate(
              tabBar: _TeamTabBar(controller: _tabCtrl),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SportlightsTab(profile: p),
            _AboutTab(profile: p),
            _SquadTab(profile: p),
            _StatsTab(profile: p),
            ShopTab(
              catalog: p.handle == 'simbasc'
                  ? simbaShopCatalog()
                  : teamShopCatalog(
                      name: p.name,
                      handle: p.handle,
                      accent: p.accentColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// #5.3 — Admin-only "Edit Profile" entry. Hidden for non-admin viewers.
  /// Falls back to looking up the Team row by handle when [TeamProfileModel.id]
  /// is missing (lookup functions in data/* are owned by another agent).
  Future<void> _openAdminEdit(BuildContext context) async {
    Navigator.pop(context); // dismiss the more-sheet
    String? teamId = p.id;
    Map<String, dynamic> initial = <String, dynamic>{
      'name': p.name,
      'shortName': p.shortName ?? '',
      'primaryColor': p.primaryColorHex ?? '',
      'country': p.country,
      'venue': p.stadium,
      'leagueId': p.leagueId ?? '',
      'logoUrl': p.logoAsset ?? '',
    };
    if (teamId == null || teamId.isEmpty) {
      // Resolve by handle/slug.
      try {
        final sb = Supabase.instance.client;
        final key = p.handle.replaceAll('@', '').trim();
        final row = await sb
            .from('Team')
            .select()
            .or('id.eq.$key,id.eq.tm-$key,slug.eq.${key.replaceAll('_', '-')}')
            .maybeSingle();
        if (row != null) {
          teamId = row['id']?.toString();
          // Merge in any extra fields from the DB row.
          initial = Map<String, dynamic>.from(row);
        }
      } catch (e) {
        debugPrint('team admin edit lookup: $e');
      }
    }
    if (teamId == null || teamId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not resolve team record — edit via Admin Dashboard instead.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    await showEntityEditSheet(
      context,
      entityType: EntityType.team,
      entityId: teamId,
      initialData: initial,
    );
  }

  void _showMore(BuildContext context) {
    final isAdmin = AppAdmin.isSessionAdmin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileMoreSheet(
        isOwnProfile: p.isOwnProfile,
        options: [
          // #5.3 — "Edit Profile" entry only for admins (replaces the dead
          // Navigator.pop(context) that previously closed the sheet).
          if (isAdmin)
            ProfileMoreOption(
              icon: Icons.edit_outlined,
              label: 'Edit Profile',
              onTap: () => _openAdminEdit(context),
            ),
          ProfileMoreOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
          if (p.isOwnProfile)
            ProfileMoreOption(icon: Icons.qr_code_rounded, label: 'QR Code', onTap: () => Navigator.pop(context)),
          if (!p.isOwnProfile)
            ProfileMoreOption(icon: Icons.flag_outlined, label: 'Report', onTap: () => Navigator.pop(context), destructive: true),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _TeamHeader extends StatelessWidget {
  final TeamProfileModel profile;
  final bool following;
  final bool isFan;
  final bool busyFollow;
  final bool busyFan;
  final VoidCallback onFollow;
  final VoidCallback onBecomeFan;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onInfo;

  const _TeamHeader({
    required this.profile,
    required this.following,
    required this.isFan,
    required this.busyFollow,
    required this.busyFan,
    required this.onFollow,
    required this.onBecomeFan,
    required this.onBack,
    required this.onShare,
    required this.onMore,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    const coverH = 210.0;
    const logoR  = 46.0;
    final accent = profile.accentColor;
    final top    = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cover ────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover
            SizedBox(
              height: coverH,
              width: double.infinity,
              child: profile.coverAsset != null
                  ? Image.asset(profile.coverAsset!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          ProfileCoverGradient(accent: accent, icon: Icons.groups_rounded))
                  : ProfileCoverGradient(accent: accent, icon: Icons.groups_rounded),
            ),

            // Bottom fade
            Positioned(
              bottom: 0, left: 0, right: 0, height: 110,
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

            // Share + More
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

            // Team logo overlapping cover
            Positioned(
              bottom: -(logoR * 0.45),
              left: 16,
              child: ProfileAvatar(
                asset: profile.logoAsset,
                radius: logoR,
                accentColor: accent,
              ),
            ),
          ],
        ),

        SizedBox(height: logoR * 0.45 + 12),

        // ── Identity ─────────────────────────────────────────
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
                            profile.name,
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
                    Text(profile.atHandle,
                        style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 14,
                        )),

                    const SizedBox(height: 6),

                    // Sport · Competition
                    Text(
                      '${profile.sport} · ${profile.competition}',
                      style: TextStyle(
                        color: SportSphereColors.muted.withValues(alpha: 0.80),
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Location
                    Row(
                      children: [
                        Icon(Icons.place_rounded,
                            color: SportSphereColors.muted.withValues(alpha: 0.65),
                            size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.city}, ${profile.country}',
                          style: TextStyle(
                            color: SportSphereColors.muted.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ⓘ info shortcut
              const SizedBox(width: 10),
              Semantics(
                label: 'About this team',
                button: true,
                child: GestureDetector(
                  onTap: onInfo,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
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

        // ── Stats strip ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ProfileStat(value: formatCount(profile.postCount), label: 'Posts'),
                const ProfileStatDivider(),
                ProfileStat(value: formatCount(profile.fanCount), label: 'Fans'),
                const ProfileStatDivider(),
                ProfileStat(value: '${profile.followingCount}', label: 'Following'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Follow + Become a Fan buttons (#7.2 / #7.3) ───────
        if (!profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _FollowRow(
              following: following,
              isFan: isFan,
              busyFollow: busyFollow,
              busyFan: busyFan,
              accent: accent,
              onFollow: onFollow,
              onBecomeFan: onBecomeFan,
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Follow + Fan row ───────────────────────────────────────────────────────────

class _FollowRow extends StatelessWidget {
  final bool following;
  final bool isFan;
  final bool busyFollow;
  final bool busyFan;
  final Color accent;
  final VoidCallback onFollow;
  final VoidCallback onBecomeFan;

  const _FollowRow({
    required this.following,
    required this.isFan,
    required this.busyFollow,
    required this.busyFan,
    required this.accent,
    required this.onFollow,
    required this.onBecomeFan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Follow / Following
        Expanded(
          child: Semantics(
            label: following ? 'Following this team' : 'Follow this team',
            button: true,
            child: GestureDetector(
              onTap: busyFollow ? null : onFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
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
                          color: Colors.white.withValues(alpha: 0.18))
                      : null,
                  boxShadow: following
                      ? null
                      : [
                          BoxShadow(
                            color: SportSphereColors.electricBlue
                                .withValues(alpha: 0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: busyFollow
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
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

        // Become a Fan / Unfan (#7.3)
        Expanded(
          child: Semantics(
            label: isFan ? 'Already a fan — tap to unfan' : 'Become a fan',
            button: true,
            child: GestureDetector(
              onTap: busyFan ? null : onBecomeFan,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  color: isFan
                      ? accent.withValues(alpha: 0.18)
                      : accent,
                  border: isFan
                      ? Border.all(color: accent.withValues(alpha: 0.6))
                      : null,
                  boxShadow: isFan
                      ? null
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: busyFan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFan ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFan ? 'Fan' : 'Become a Fan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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

        // Notification bell
        Semantics(
          label: 'Set team notifications',
          button: true,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: 42, width: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: SportSphereColors.muted, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB BAR — 4 tabs
// ══════════════════════════════════════════════════════════════════════════════

class _TeamTabBar extends StatelessWidget {
  final TabController controller;
  const _TeamTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SportSphereColors.background,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: SportSphereColors.white,
        unselectedLabelColor: SportSphereColors.muted,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
              color: Color(0xFFE31B23), width: 2.5),
          borderRadius: BorderRadius.circular(4),
          insets: const EdgeInsets.symmetric(horizontal: 12),
        ),
        tabs: const [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_rounded, size: 14),
              SizedBox(width: 5),
              Text('Sportlights'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.info_outline_rounded, size: 14),
              SizedBox(width: 5),
              Text('About'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_rounded, size: 14),
              SizedBox(width: 5),
              Text('Squad'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_rounded, size: 14),
              SizedBox(width: 5),
              Text('Stats'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shopping_bag_rounded, size: 14),
              SizedBox(width: 5),
              Text('Shop'),
            ]),
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
  final TeamProfileModel profile;
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
            Text('Posts from \${profile.name} will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SportSphereColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABOUT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _AboutTab extends StatelessWidget {
  final TeamProfileModel profile;
  const _AboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Club description
        if (profile.description.isNotEmpty) ...[
          AboutSection(
            title: 'About',
            child: Text(profile.description,
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 15,
                  height: 1.55,
                )),
          ),
          const SizedBox(height: 14),
        ],

        // Club information
        AboutSection(
          title: 'Club Information',
          child: Column(
            children: [
              AboutRow(
                icon: Icons.shield_rounded,
                iconColor: profile.accentColor,
                label: 'Club',
                value: profile.name,
                valueColor: profile.accentColor,
              ),
              AboutRow(
                icon: Icons.flag_rounded,
                iconColor: SportSphereColors.sportOrange,
                label: 'Country',
                value: profile.country,
              ),
              AboutRow(
                icon: Icons.place_rounded,
                iconColor: SportSphereColors.electricBlue,
                label: 'City',
                value: profile.city,
              ),
              AboutRow(
                icon: Icons.stadium_rounded,
                iconColor: SportSphereColors.sportGreen,
                label: 'Stadium',
                value: profile.stadium,
              ),
              AboutRow(
                icon: Icons.calendar_today_rounded,
                iconColor: SportSphereColors.brightBlue,
                label: 'Founded',
                value: '${profile.founded}',
              ),
              AboutRow(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFFFD700),
                label: 'Competition',
                value: profile.competition,
              ),
              AboutRow(
                icon: Icons.sports_rounded,
                iconColor: const Color(0xFF9B6DFF),
                label: 'Head Coach',
                value: profile.coach,
                isLast: true,
              ),
            ],
          ),
        ),

        if (profile.joinedDate != null) ...[
          const SizedBox(height: 14),
          AboutSection(
            title: 'Playify',
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
// SQUAD TAB
// ══════════════════════════════════════════════════════════════════════════════

class _SquadTab extends StatelessWidget {
  final TeamProfileModel profile;
  const _SquadTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        if (profile.players.isNotEmpty) ...[
          _SquadSection(
            title: 'Players',
            members: profile.players,
            accent: profile.accentColor,
          ),
          const SizedBox(height: 14),
        ],
        if (profile.coaches.isNotEmpty) ...[
          _SquadSection(
            title: 'Coaching Staff',
            members: profile.coaches,
            accent: profile.accentColor,
          ),
          const SizedBox(height: 14),
        ],
        if (profile.staff.isNotEmpty)
          _SquadSection(
            title: 'Support Staff',
            members: profile.staff,
            accent: profile.accentColor,
          ),
      ],
    );
  }
}

class _SquadSection extends StatelessWidget {
  final String title;
  final List<SquadMember> members;
  final Color accent;

  const _SquadSection({
    required this.title,
    required this.members,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xD0071422),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: List.generate(members.length, (i) {
              final member = members[i];
              final isLast = i == members.length - 1;
              return _SquadRow(
                member: member,
                accent: accent,
                isLast: isLast,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SquadRow extends StatelessWidget {
  final SquadMember member;
  final Color accent;
  final bool isLast;

  const _SquadRow({
    required this.member,
    required this.accent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isNavigable = member.profileRoute != null;

    return Column(
      children: [
        Semantics(
          label: '${member.name}, ${member.subrole}',
          button: isNavigable,
          child: GestureDetector(
            onTap: isNavigable
                ? () => context.push(member.profileRoute!)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar / number badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.10),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.22)),
                        ),
                        child: member.avatarAsset != null
                            ? ClipOval(
                                child: Image.asset(member.avatarAsset!,
                                    fit: BoxFit.cover))
                            : Icon(
                                _roleIcon(member.role),
                                color: accent.withValues(alpha: 0.7),
                                size: 22,
                              ),
                      ),
                      // Squad number badge
                      if (member.squadNumber != null)
                        Positioned(
                          bottom: -2,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: SportSphereColors.background,
                                  width: 1.5),
                            ),
                            child: Text(
                              '#${member.squadNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name + subrole
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name,
                            style: const TextStyle(
                              color: SportSphereColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(member.subrole,
                                style: const TextStyle(
                                  color: SportSphereColors.muted,
                                  fontSize: 12,
                                )),
                            if (member.nationality != null) ...[
                              Text(
                                '  ·  ${member.nationality}',
                                style: TextStyle(
                                  color: SportSphereColors.muted
                                      .withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron if navigable
                  if (isNavigable)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: SportSphereColors.muted.withValues(alpha: 0.5),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 76,
            color: Colors.white.withValues(alpha: 0.05),
          ),
      ],
    );
  }

  IconData _roleIcon(SquadRole role) {
    switch (role) {
      case SquadRole.player:
        return Icons.sports_soccer_rounded;
      case SquadRole.coach:
        return Icons.sports_rounded;
      case SquadRole.staff:
        return Icons.medical_services_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatefulWidget {
  final TeamProfileModel profile;
  const _StatsTab({required this.profile});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late String _season;

  @override
  void initState() {
    super.initState();
    _season = widget.profile.seasonStats.first.season;
  }

  TeamSeasonStats get _stats {
    return widget.profile.seasonStats.firstWhere(
      (s) => s.season == _season,
      orElse: () => widget.profile.seasonStats.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats  = _stats;
    final accent = widget.profile.accentColor;
    final seasons = widget.profile.seasonStats.map((s) => s.season).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // ── Season filter ────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _SeasonDropdown(
                value: _season,
                options: seasons,
                onChanged: (v) => setState(() => _season = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: SportSphereColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  stats.competition,
                  style: const TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── League position banner ───────────────────────────
        _PositionBanner(stats: stats, accent: accent),

        const SizedBox(height: 18),

        // ── Result distribution ──────────────────────────────
        _SectionLabel('Results'),
        const SizedBox(height: 10),
        _ResultBar(stats: stats),
        const SizedBox(height: 18),

        // ── Stats grid ───────────────────────────────────────
        _SectionLabel('Season Statistics'),
        const SizedBox(height: 10),
        _TeamStatsGrid(stats: stats),
      ],
    );
  }
}

// ── Season dropdown ────────────────────────────────────────────────────────────

class _SeasonDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _SeasonDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

// ── League position banner ─────────────────────────────────────────────────────

class _PositionBanner extends StatelessWidget {
  final TeamSeasonStats stats;
  final Color accent;
  const _PositionBanner({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Position
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ordinal(stats.leaguePosition),
                style: TextStyle(
                  color: accent,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text('League Position',
                  style: TextStyle(
                    color: SportSphereColors.muted.withValues(alpha: 0.8),
                    fontSize: 12,
                  )),
            ],
          ),
          const Spacer(),
          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.points}',
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Text('Points',
                  style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                  )),
            ],
          ),
          const SizedBox(width: 24),
          // Matches played
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.matches}',
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Text('Played',
                  style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    switch (n) {
      case 1:  return '1st';
      case 2:  return '2nd';
      case 3:  return '3rd';
      default: return '${n}th';
    }
  }
}

// ── W/D/L result bar ───────────────────────────────────────────────────────────

class _ResultBar extends StatelessWidget {
  final TeamSeasonStats stats;
  const _ResultBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.matches;
    final wFrac = stats.wins / total;
    final dFrac = stats.draws / total;
    final lFrac = stats.losses / total;

    return Column(
      children: [
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Flexible(
                  flex: (wFrac * 100).round(),
                  child: Container(color: SportSphereColors.sportGreen),
                ),
                Flexible(
                  flex: (dFrac * 100).round(),
                  child: Container(color: SportSphereColors.muted.withValues(alpha: 0.5)),
                ),
                Flexible(
                  flex: (lFrac * 100).round(),
                  child: Container(color: SportSphereColors.danger),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Labels
        Row(
          children: [
            _ResultLabel(color: SportSphereColors.sportGreen, label: 'W', value: stats.wins),
            const Spacer(),
            _ResultLabel(color: SportSphereColors.muted, label: 'D', value: stats.draws),
            const Spacer(),
            _ResultLabel(color: SportSphereColors.danger, label: 'L', value: stats.losses),
          ],
        ),
      ],
    );
  }
}

class _ResultLabel extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _ResultLabel({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text('$label $value',
            style: TextStyle(
              color: SportSphereColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}

// ── Team stats grid card ───────────────────────────────────────────────────────

class _TeamStatsGrid extends StatelessWidget {
  final TeamSeasonStats stats;
  const _TeamStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = [
      _Entry(Icons.calendar_today_rounded, SportSphereColors.electricBlue, 'Matches', '${stats.matches}'),
      _Entry(Icons.check_circle_outline_rounded, SportSphereColors.sportGreen, 'Wins', '${stats.wins}'),
      _Entry(Icons.remove_circle_outline_rounded, SportSphereColors.muted, 'Draws', '${stats.draws}'),
      _Entry(Icons.cancel_outlined, SportSphereColors.danger, 'Losses', '${stats.losses}'),
      _Entry(Icons.sports_soccer_rounded, const Color(0xFFE31B23), 'Goals For', '${stats.goalsFor}'),
      _Entry(Icons.shield_outlined, SportSphereColors.sportOrange, 'Goals Against', '${stats.goalsAgainst}'),
      _Entry(Icons.trending_up_rounded, SportSphereColors.brightBlue, 'Goal Difference',
          stats.goalDifference >= 0 ? '+${stats.goalDifference}' : '${stats.goalDifference}'),
      _Entry(Icons.lock_outline_rounded, SportSphereColors.sportGreen, 'Clean Sheets', '${stats.cleanSheets}'),
    ];

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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e.color.withValues(alpha: 0.12),
                      ),
                      child: Icon(e.icon, color: e.color, size: 16),
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
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _Entry {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _Entry(this.icon, this.color, this.label, this.value);
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bar_chart_rounded,
            color: SportSphereColors.muted, size: 15),
        const SizedBox(width: 7),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: SportSphereColors.muted.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
