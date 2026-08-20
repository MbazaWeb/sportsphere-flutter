import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/branding.dart';
import '../../shop/presentation/shop_tab.dart';
import '../shared/profile_widgets.dart';
import '../presentation/people_list_sheet.dart';
import '../../claims/presentation/claim_profile_sheet.dart';
import 'role_profile_model.dart';

class RoleProfileShell extends StatefulWidget {
  final RoleProfileModel profile;
  const RoleProfileShell({super.key, required this.profile});

  @override
  State<RoleProfileShell> createState() => _RoleProfileShellState();
}

class _RoleProfileShellState extends State<RoleProfileShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;
  RoleProfileModel get p => widget.profile;

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
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _Header(
              p: p,
              following: _following,
              onFollow: () {
                HapticFeedback.lightImpact();
                setState(() => _following = !_following);
              },
              onBack: () => Navigator.of(context).maybePop(),
              onShop: p.shop == null ? null : () => _tabCtrl.animateTo(tabs.length - 1),
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
                color: SportSphereColors.background,
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: SportSphereColors.white,
                  unselectedLabelColor: SportSphereColors.muted,
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
  final RoleProfileModel p;
  final bool following;
  final VoidCallback onFollow;
  final VoidCallback? onClaim;
  final VoidCallback onBack;
  final VoidCallback? onShop;
  const _Header({
    required this.p,
    required this.following,
    required this.onFollow,
    this.onClaim,
    required this.onBack,
    this.onShop,
  });

  @override
  Widget build(BuildContext context) {
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
                child: ProfileNavButton(icon: Icons.ios_share_rounded, onTap: () {}, semanticsLabel: 'Share'),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: ProfileAvatar(
                  asset: (p.handle.replaceAll('@','') == kOfficialHandle)
                      ? kOfficialAvatarUrl
                      : null,
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
                      style: const TextStyle(color: SportSphereColors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                if (p.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 20),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(p.atHandle, style: const TextStyle(color: SportSphereColors.muted, fontSize: 13)),
                const SizedBox(width: 8),
                RoleBadge(label: p.roleLabel, color: p.accent),
              ]),
              const SizedBox(height: 6),
              Text(p.subtitle, style: TextStyle(color: p.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              if (p.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.bio, style: const TextStyle(color: SportSphereColors.white, fontSize: 14, height: 1.4)),
              ],
              if (p.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: SportSphereColors.muted),
                  const SizedBox(width: 4),
                  Text(p.location, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
                ]),
              ],
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 0; i < p.headerStats.length; i++) ...[
                  if (i > 0) const ProfileStatDivider(),
                  ProfileStat(
                    value: p.headerStats[i].value,
                    label: p.headerStats[i].label,
                    onTap: () {
                      final label = p.headerStats[i].label.toLowerCase();
                      final kind = label.contains('fan')
                          ? PeopleListKind.fans
                          : label.contains('following')
                              ? PeopleListKind.following
                              : label.contains('follow')
                                  ? PeopleListKind.followers
                                  : null;
                      if (kind == null) return;
                      showPeopleList(context, userId: p.entityId ?? p.handle, handle: p.handle, kind: kind);
                    },
                  ),
                ],
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onFollow,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(21),
                        color: following ? Colors.white.withValues(alpha: 0.06) : p.accent,
                        border: following ? Border.all(color: Colors.white.withValues(alpha: 0.18)) : null,
                      ),
                      child: Center(
                        child: Text(following ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: following ? SportSphereColors.muted : Colors.white,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
                ),
                if (onClaim != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ClaimProfileButton(onTap: onClaim!),
                      ),
                    if (onShop != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onShop,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.storefront_rounded, size: 16, color: SportSphereColors.white),
                        SizedBox(width: 6),
                        Text('Shop', style: TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _Sportlights extends StatelessWidget {
  final RoleProfileModel p;
  const _Sportlights({required this.p});

  @override
  Widget build(BuildContext context) {
    if (p.posts.isEmpty) {
      return const Center(child: Text('No Sportlights yet', style: TextStyle(color: SportSphereColors.muted)));
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
  final RoleProfileModel p;
  const _About({required this.p});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (p.bio.isNotEmpty) ...[
          const Text('Bio', style: TextStyle(color: SportSphereColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(p.bio, style: const TextStyle(color: SportSphereColors.white, height: 1.45)),
          const SizedBox(height: 20),
        ],
        for (final f in p.aboutFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 118, child: Text(f.label, style: const TextStyle(color: SportSphereColors.muted, fontSize: 13))),
                Expanded(
                  child: Text(f.value,
                      style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Members extends StatelessWidget {
  final RoleProfileModel p;
  const _Members({required this.p});

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
            child: Text(m.name[0], style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
          ),
          title: Text(m.name, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700)),
          subtitle: Text('${m.subtitle}  ·  @${m.handle}',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
          onTap: m.route == null ? null : () => context.push(m.route!),
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  final RoleProfileModel p;
  const _Stats({required this.p});

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
              Expanded(child: Text(r.label, style: const TextStyle(color: SportSphereColors.muted))),
              Text(r.value, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
      ],
    );
  }
}
