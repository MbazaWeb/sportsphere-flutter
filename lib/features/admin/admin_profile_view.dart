import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/profile/presentation/edit_profile_sheet.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN PROFILE VIEW
// Full-page profile for the admin/official account.
// Shows: avatar, name, badge, stats, quick-action tiles, then the admin dashboard.
// ══════════════════════════════════════════════════════════════════════════════

class AdminProfileView extends ConsumerStatefulWidget {
  const AdminProfileView({super.key});

  @override
  ConsumerState<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends ConsumerState<AdminProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Live platform stats
  int _users = 0;
  int _posts = 0;
  int _matches = 0;
  int _teams = 0;
  int _news = 0;
  bool _statsLoading = true;

  static SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final counts = await Future.wait([
        _sb.from('User').select('id').then((r) => (r as List).length),
        _sb.from('Post').select('id').then((r) => (r as List).length),
        _sb.from('Match').select('id').then((r) => (r as List).length),
        _sb.from('Team').select('id').then((r) => (r as List).length),
        _sb.from('NewsItem').select('id').then((r) => (r as List).length),
      ]);
      if (mounted) {
        setState(() {
          _users = counts[0];
          _posts = counts[1];
          _matches = counts[2];
          _teams = counts[3];
          _news = counts[4];
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: SportSphereColors.background,
        body: Center(
          child: CircularProgressIndicator(
              color: SportSphereColors.electricBlue, strokeWidth: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _AdminHeader(user: user)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(
              TabBar(
                controller: _tabCtrl,
                labelColor: SportSphereColors.white,
                unselectedLabelColor: SportSphereColors.muted,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                indicator: UnderlineTabIndicator(
                  borderSide: const BorderSide(
                      color: Color(0xFFFFD700), width: 2.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                tabs: const [
                  Tab(text: '⚡ Quick Actions'),
                  Tab(text: '📊 Platform Stats'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _QuickActionsTab(onRefresh: _loadStats),
            _StatsTab(
              loading: _statsLoading,
              users: _users,
              posts: _posts,
              matches: _matches,
              teams: _teams,
              news: _news,
              onRefresh: _loadStats,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Header ──────────────────────────────────────────────────────────────

class _AdminHeader extends ConsumerWidget {
  final dynamic user; // UserProfile
  const _AdminHeader({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAvatar = user.avatarUrl != null && (user.avatarUrl as String).isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF020A14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────
              Row(
                children: [
                  // Gold admin badge chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings_rounded,
                            color: Color(0xFFFFD700), size: 14),
                        SizedBox(width: 5),
                        Text('ADMIN',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            )),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Edit profile
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: SportSphereColors.muted, size: 20),
                    tooltip: 'Edit Profile',
                    onPressed: () => showEditProfileSheet(context, ref),
                  ),
                  // Go to full dashboard
                  IconButton(
                    icon: const Icon(Icons.dashboard_rounded,
                        color: Color(0xFFFFD700), size: 20),
                    tooltip: 'Admin Dashboard',
                    onPressed: () => context.push('/admin'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Avatar + Name ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatar with gold ring
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF0F1F35),
                      backgroundImage:
                          hasAvatar ? NetworkImage(user.avatarUrl as String) : null,
                      child: !hasAvatar
                          ? Text(
                              '${user.firstName.isNotEmpty ? user.firstName[0] : 'A'}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName
                                    : 'Admin',
                                style: const TextStyle(
                                  color: SportSphereColors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFFFFD700), size: 18),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.handle}',
                          style: const TextStyle(
                              color: SportSphereColors.muted, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        // Role tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SportSphereColors.electricBlue
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: SportSphereColors.electricBlue
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'SportSphere Official',
                            style: TextStyle(
                                color: SportSphereColors.electricBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Bio if set ───────────────────────────────────
              if ((user.bio as String).isNotEmpty) ...[
                Text(
                  user.bio as String,
                  style: const TextStyle(
                      color: SportSphereColors.muted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
              ],

              // ── Open Admin Dashboard full button ─────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700),
                    side: const BorderSide(
                        color: Color(0xFFFFD700), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/admin');
                  },
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                  label: const Text('Open Admin Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick Actions Tab ─────────────────────────────────────────────────────────

class _QuickActionsTab extends StatelessWidget {
  final VoidCallback onRefresh;
  const _QuickActionsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _SectionLabel('CONTENT MANAGEMENT'),
        const SizedBox(height: 10),
        _QuickTile(
          icon: Icons.sensors_rounded,
          color: const Color(0xFFE31B23),
          title: 'Live Match Control',
          subtitle: 'Update scores & match status in real time',
          onTap: () => context.push('/admin'),
        ),
        _QuickTile(
          icon: Icons.newspaper_rounded,
          color: SportSphereColors.sportOrange,
          title: 'Publish News Article',
          subtitle: 'Breaking news, rumours and match updates',
          onTap: () => context.push('/admin'),
        ),
        _QuickTile(
          icon: Icons.add_circle_rounded,
          color: SportSphereColors.sportGreen,
          title: 'Schedule Match',
          subtitle: 'Add a new fixture to the calendar',
          onTap: () => context.push('/admin'),
        ),

        const SizedBox(height: 20),
        _SectionLabel('USER MANAGEMENT'),
        const SizedBox(height: 10),
        _QuickTile(
          icon: Icons.people_rounded,
          color: SportSphereColors.electricBlue,
          title: 'Manage Users',
          subtitle: 'Search, verify or moderate accounts',
          onTap: () => context.push('/admin'),
        ),
        _QuickTile(
          icon: Icons.verified_rounded,
          color: const Color(0xFFFFD700),
          title: 'PRO Verification Queue',
          subtitle: 'Review pending PRO role applications',
          onTap: () => context.push('/admin'),
        ),

        const SizedBox(height: 20),
        _SectionLabel('SYSTEM'),
        const SizedBox(height: 10),
        _QuickTile(
          icon: Icons.dashboard_rounded,
          color: const Color(0xFF9B6DFF),
          title: 'Full Admin Dashboard',
          subtitle: 'All controls in one place',
          onTap: () => context.push('/admin'),
        ),
        _QuickTile(
          icon: Icons.refresh_rounded,
          color: SportSphereColors.muted,
          title: 'Refresh Platform Stats',
          subtitle: 'Reload user, post and match counts',
          onTap: () {
            HapticFeedback.mediumImpact();
            onRefresh();
          },
        ),
      ],
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final bool loading;
  final int users, posts, matches, teams, news;
  final VoidCallback onRefresh;

  const _StatsTab({
    required this.loading,
    required this.users,
    required this.posts,
    required this.matches,
    required this.teams,
    required this.news,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: SportSphereColors.electricBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _SectionLabel('LIVE PLATFORM METRICS'),
          const SizedBox(height: 12),

          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: CircularProgressIndicator(
                    color: SportSphereColors.electricBlue, strokeWidth: 2),
              ),
            )
          else ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  label: 'Total Users',
                  value: _fmt(users),
                  icon: Icons.people_rounded,
                  color: SportSphereColors.electricBlue,
                ),
                _StatCard(
                  label: 'Total Posts',
                  value: _fmt(posts),
                  icon: Icons.article_rounded,
                  color: SportSphereColors.sportGreen,
                ),
                _StatCard(
                  label: 'Matches',
                  value: _fmt(matches),
                  icon: Icons.sports_soccer_rounded,
                  color: const Color(0xFFE31B23),
                ),
                _StatCard(
                  label: 'Teams',
                  value: _fmt(teams),
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF9B6DFF),
                ),
                _StatCard(
                  label: 'News Articles',
                  value: _fmt(news),
                  icon: Icons.newspaper_rounded,
                  color: SportSphereColors.sportOrange,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel('ACTIONS NEEDED'),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.warning_amber_rounded,
              color: SportSphereColors.sportOrange,
              label: 'M-Pesa Daraja secrets required for live payments',
            ),
            _InfoTile(
              icon: Icons.notifications_off_rounded,
              color: SportSphereColors.muted,
              label: 'FCM push notifications not yet wired',
            ),
            _InfoTile(
              icon: Icons.person_search_rounded,
              color: SportSphereColors.electricBlue,
              label: 'Review PRO verification queue',
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: SportSphereColors.muted.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      );
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF071422),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: SportSphereColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: SportSphereColors.muted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              Text(label,
                  style: const TextStyle(
                      color: SportSphereColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: SportSphereColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── PersistentHeader delegate ─────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext _, double shrink, bool overlap) {
    return Container(
      color: SportSphereColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabDelegate old) => old.tabBar != tabBar;
}
