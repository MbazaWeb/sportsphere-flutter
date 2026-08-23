import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
import '../auth/presentation/auth_controller.dart';
import '../profile/presentation/edit_profile_sheet.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN PROFILE VIEW
// Full dedicated profile for the official admin account.
// Shows identity header, quick-action tiles, and live platform stats.
// ══════════════════════════════════════════════════════════════════════════════

class AdminProfileView extends ConsumerStatefulWidget {
  const AdminProfileView({super.key});
  @override
  ConsumerState<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends ConsumerState<AdminProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  int _users = 0, _posts = 0, _matches = 0, _teams = 0, _news = 0;
  bool _statsLoading = true;

  static SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _statsLoading = true);
    try {
      final c = await Future.wait([
        _sb.from('User').select('id').then((r) => (r as List).length),
        _sb.from('Post').select('id').then((r) => (r as List).length),
        _sb.from('Match').select('id').then((r) => (r as List).length),
        _sb.from('Team').select('id').then((r) => (r as List).length),
        _sb.from('NewsItem').select('id').then((r) => (r as List).length),
      ]);
      if (mounted) {
        setState(() {
          _users = c[0]; _posts = c[1]; _matches = c[2]; _teams = c[3]; _news = c[4];
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
        body: Center(child: CircularProgressIndicator(color: SportSphereColors.electricBlue, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _Header(user: user, onRefresh: _loadStats)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(TabBar(
              controller: _tab,
              labelColor: SportSphereColors.white,
              unselectedLabelColor: SportSphereColors.muted,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFFFFD700), width: 2.5),
              ),
              tabs: const [Tab(text: '⚡ Quick Actions'), Tab(text: '📊 Stats')],
            )),
          ),
        ],
        body: TabBarView(controller: _tab, children: [
          _QuickActionsTab(onRefresh: _loadStats),
          _StatsTab(
            loading: _statsLoading,
            users: _users, posts: _posts, matches: _matches,
            teams: _teams, news: _news, onRefresh: _loadStats,
          ),
        ]),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final dynamic user;
  final VoidCallback onRefresh;
  const _Header({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAvatar = (user.avatarUrl as String?)?.isNotEmpty == true;
    final hasCover  = (user.coverUrl as String?)?.isNotEmpty == true;

    return Container(
      decoration: BoxDecoration(
        image: hasCover ? DecorationImage(
          image: NetworkImage(user.coverUrl as String),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
        ) : null,
        gradient: !hasCover ? const LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF020A14)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ) : null,
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top bar
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFD700), size: 14),
                SizedBox(width: 5),
                Text('ADMIN', style: TextStyle(
                    color: Color(0xFFFFD700), fontSize: 11,
                    fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ]),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: SportSphereColors.muted, size: 20),
              tooltip: 'Edit Profile',
              onPressed: () => showEditProfileSheet(context, user),
            ),
            IconButton(
              icon: const Icon(Icons.dashboard_rounded, color: Color(0xFFFFD700), size: 20),
              tooltip: 'Admin Dashboard',
              onPressed: () => context.push('/admin'),
            ),
          ]),

          const SizedBox(height: 20),

          // Avatar + Name
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF0F1F35),
                backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl as String) : null,
                child: !hasAvatar ? Text(
                  (user.firstName as String).isNotEmpty ? (user.firstName as String)[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.w900),
                ) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(
                  (user.firstName as String).isNotEmpty
                      ? '${user.firstName} ${user.lastName}'.trim()
                      : 'Admin',
                  style: const TextStyle(color: SportSphereColors.white,
                      fontSize: 22, fontWeight: FontWeight.w900, height: 1.1),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 18),
              ]),
              const SizedBox(height: 2),
              Text('@${user.handle}',
                  style: const TextStyle(color: SportSphereColors.muted, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SportSphereColors.electricBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SportSphereColors.electricBlue.withValues(alpha: 0.3)),
                ),
                child: const Text('SportSphere Official',
                    style: TextStyle(color: SportSphereColors.electricBlue,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ])),
          ]),

          const SizedBox(height: 16),

          if ((user.bio as String).isNotEmpty) ...[
            Text(user.bio as String,
                style: const TextStyle(color: SportSphereColors.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
          ],

          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD700),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () { HapticFeedback.lightImpact(); context.push('/admin'); },
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
              label: const Text('Open Admin Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      )),
    );
  }
}

// ── Quick Actions Tab ─────────────────────────────────────────────────────────

class _QuickActionsTab extends StatelessWidget {
  final VoidCallback onRefresh;
  const _QuickActionsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _Section('CONTENT'),
      _Tile(Icons.sensors_rounded,         const Color(0xFFE31B23),      'Live Match Control',       'Update scores in real time',           () => context.push('/admin')),
      _Tile(Icons.newspaper_rounded,        SportSphereColors.sportOrange, 'Publish News',             'Breaking news and match updates',       () => context.push('/admin')),
      _Tile(Icons.add_circle_rounded,       SportSphereColors.sportGreen,  'Schedule Match',           'Add a new fixture',                     () => context.push('/admin')),
      const SizedBox(height: 20),
      _Section('USERS'),
      _Tile(Icons.people_rounded,           SportSphereColors.electricBlue,'Manage Users',             'Search, verify or moderate accounts',   () => context.push('/admin')),
      _Tile(Icons.verified_rounded,         const Color(0xFFFFD700),       'PRO Queue',                'Review pending PRO applications',        () => context.push('/admin')),
      const SizedBox(height: 20),
      _Section('SYSTEM'),
      _Tile(Icons.dashboard_rounded,        const Color(0xFF9B6DFF),       'Full Dashboard',           'All admin controls in one place',        () => context.push('/admin')),
      _Tile(Icons.refresh_rounded,          SportSphereColors.muted,       'Refresh Stats',            'Reload platform counters',               () { HapticFeedback.mediumImpact(); onRefresh(); }),
    ]);
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  final bool loading;
  final int users, posts, matches, teams, news;
  final VoidCallback onRefresh;
  const _StatsTab({
    required this.loading, required this.users, required this.posts,
    required this.matches, required this.teams, required this.news,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: SportSphereColors.electricBlue,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        _Section('PLATFORM METRICS'),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: CircularProgressIndicator(color: SportSphereColors.electricBlue, strokeWidth: 2),
          ))
        else GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
          children: [
            _StatCard('Users',   _fmt(users),   Icons.people_rounded,         SportSphereColors.electricBlue),
            _StatCard('Posts',   _fmt(posts),   Icons.article_rounded,         SportSphereColors.sportGreen),
            _StatCard('Matches', _fmt(matches), Icons.sports_soccer_rounded,   const Color(0xFFE31B23)),
            _StatCard('Teams',   _fmt(teams),   Icons.groups_rounded,          const Color(0xFF9B6DFF)),
            _StatCard('News',    _fmt(news),    Icons.newspaper_rounded,       SportSphereColors.sportOrange),
          ],
        ),
        const SizedBox(height: 24),
        _Section('PENDING'),
        const SizedBox(height: 10),
        _InfoRow(Icons.warning_amber_rounded, SportSphereColors.sportOrange, 'M-Pesa Daraja secrets needed for live payments'),
        _InfoRow(Icons.notifications_off_rounded, SportSphereColors.muted,   'FCM push not yet wired'),
        _InfoRow(Icons.person_search_rounded, SportSphereColors.electricBlue,'PRO verification queue — check ⭐ PRO Queue tab'),
      ]),
    );
  }

  String _fmt(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String t;
  const _Section(this.t);
  @override
  Widget build(BuildContext ctx) => Text(t,
      style: TextStyle(color: SportSphereColors.muted.withValues(alpha: 0.7),
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2));
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final VoidCallback onTap;
  const _Tile(this.icon, this.color, this.title, this.sub, this.onTap);

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF071422),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(sub,   style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
        ])),
        Icon(Icons.chevron_right_rounded, color: SportSphereColors.muted.withValues(alpha: 0.5)),
      ]),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: color, size: 20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
        Text(label, style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
      ]),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final Color color; final String label;
  const _InfoRow(this.icon, this.color, this.label);
  @override
  Widget build(BuildContext ctx) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12))),
    ]),
  );
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height + 1;
  @override double get maxExtent => tabBar.preferredSize.height + 1;
  @override Widget build(BuildContext _, double __, bool ___) =>
      Container(color: SportSphereColors.background, child: tabBar);
  @override bool shouldRebuild(_TabDelegate o) => o.tabBar != tabBar;
}
