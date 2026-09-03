// lib/features/admin/admin_profile_view.dart
// Admin/Official profile — full social profile visible to all users.
//
// What it shows:
//   • "Playify Official" gold badge + verified checkmark
//   • Follower / following / post counts (real from VPS)
//   • Posts tab — all posts by this admin (fans can interact)
//   • About tab — bio, links, stats
//   • Admin tab — Quick Actions + Stats (only visible to self)
//
// Social rules for admin:
//   • Other users CAN follow admin → see posts in feed
//   • Admin CAN follow other users
//   • Admin CANNOT become fan of teams/players/coaches (by design)
//   • Admin badge shows on every post/comment by this account

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/vps_repository.dart';
import '../../core/theme/colors.dart';
import '../auth/presentation/auth_controller.dart';
import '../profile/presentation/edit_profile_sheet.dart';
import 'bulk_upload_screen.dart';

// ── Gold admin colour ──────────────────────────────────────────────────────────
const _kGold   = Color(0xFFFFD700);
const _kGoldBg = Color(0xFF1A1500);

class AdminProfileView extends ConsumerStatefulWidget {
  const AdminProfileView({super.key});
  @override
  ConsumerState<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends ConsumerState<AdminProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Social counts
  int _postCount = 0, _followerCount = 0, _followingCount = 0;

  // Posts
  List<Map<String, dynamic>> _posts = [];
  bool _postsLoading = true;

  // Platform stats (admin only)
  Map<String, int> _stats = {};
  bool _statsLoading = true;

  static const _vps = VpsRepository();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    await Future.wait([_loadProfile(), _loadPosts(), _loadStats()]);
  }

  Future<void> _loadProfile() async {
    try {
      final auth = ref.read(authControllerProvider);
      final userId = auth.user?.id ?? '';
      if (userId.isEmpty) return;
      final profile = await _vps.getProfile(userId);
      if (profile == null) return;
      if (mounted) {
        setState(() {
        _postCount      = (profile['postCount']      as int?) ?? 0;
        _followerCount  = (profile['followerCount']  as int?) ?? 0;
        _followingCount = (profile['followingCount'] as int?) ?? 0;
      });
      }
    } catch (_) {}
  }

  Future<void> _loadPosts() async {
    setState(() => _postsLoading = true);
    try {
      final userId = ref.read(authControllerProvider).user?.id ?? '';
      if (userId.isEmpty) return;
      final posts = await _vps.getUserPosts(userId, limit: 40);
      if (mounted) setState(() { _posts = posts; _postsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final s = await _vps.getAdminStats();
      if (mounted) {
        setState(() {
        _stats = {
          'users':        (s['users']        as num?)?.toInt() ?? 0,
          'posts':        (s['posts']        as num?)?.toInt() ?? 0,
          'matches':      (s['matches']      as num?)?.toInt() ?? 0,
          'teams':        (s['teams']        as num?)?.toInt() ?? 0,
          'players':      (s['players']      as num?)?.toInt() ?? 0,
          'competitions': (s['competitions'] as num?)?.toInt() ?? 0,
          'news':         (s['news']         as num?)?.toInt() ?? 0,
        };
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
      backgroundColor: PlayifyColors.background,
      body: Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
    );
    }

    return Scaffold(
      backgroundColor: PlayifyColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _ProfileHeader(
            user:           user,
            postCount:      _postCount,
            followerCount:  _followerCount,
            followingCount: _followingCount,
            onRefresh:      _load,
          )),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(TabBar(
              controller: _tab,
              labelColor:         _kGold,
              unselectedLabelColor: PlayifyColors.muted,
              indicatorColor:     _kGold,
              indicatorSize:      TabBarIndicatorSize.label,
              labelStyle:         const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'About'),
                Tab(text: '⚙ Admin'),
              ],
            )),
          ),
        ],
        body: TabBarView(controller: _tab, children: [
          // ── Posts tab ────────────────────────────────────────────────────────
          _postsLoading
              ? const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2))
              : _posts.isEmpty
                  ? _emptyPosts()
                  : RefreshIndicator(
                      onRefresh: _loadPosts,
                      color: _kGold,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _posts.length,
                        itemBuilder: (_, i) => _PostCard(post: _posts[i]),
                      ),
                    ),

          // ── About tab ────────────────────────────────────────────────────────
          _AboutTab(user: user),

          // ── Admin tab ────────────────────────────────────────────────────────
          _AdminTab(stats: _stats, loading: _statsLoading, onRefresh: _loadStats),
        ]),
      ),
    );
  }

  Widget _emptyPosts() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.post_add_rounded, color: PlayifyColors.muted, size: 48),
      const SizedBox(height: 12),
      const Text('No posts yet', style: TextStyle(color: PlayifyColors.muted, fontSize: 15)),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.add_rounded, color: _kGold),
        label: const Text('Create post', style: TextStyle(color: _kGold, fontWeight: FontWeight.w700)),
      ),
    ],
  ));
}

// ── Profile header ─────────────────────────────────────────────────────────────
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.user, required this.postCount,
    required this.followerCount, required this.followingCount,
    required this.onRefresh,
  });
  final dynamic user;
  final int postCount, followerCount, followingCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAvatar = (user.avatarUrl as String?)?.startsWith('http') == true;
    final name = '${user.firstName} ${user.lastName}'.trim();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1A0A), Color(0xFF071420)],
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top bar
          Row(children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: PlayifyColors.muted, size: 20),
              tooltip: 'Edit Profile',
              onPressed: () => showEditProfileSheet(context, user),
            ),
            IconButton(
              icon: const Icon(Icons.dashboard_rounded, color: _kGold, size: 20),
              tooltip: 'Admin Dashboard',
              onPressed: () => context.push('/admin'),
            ),
          ]),

          // Avatar + identity
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Gold-ring avatar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_kGold, Color(0xFFFFA500)]),
                boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFF0F1F35),
                backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl as String) : null,
                child: !hasAvatar ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(color: _kGold, fontSize: 34, fontWeight: FontWeight.w900),
                ) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name + verified
              Row(children: [
                Flexible(child: Text(
                  name.isNotEmpty ? name : 'Playify Official',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.w900, height: 1.1),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: _kGold, size: 20),
              ]),
              const SizedBox(height: 2),
              Text('@${user.handle}',
                  style: const TextStyle(color: PlayifyColors.muted, fontSize: 13)),
              const SizedBox(height: 6),
              // "Playify Official" badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGoldBg,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.admin_panel_settings_rounded, color: _kGold, size: 13),
                  SizedBox(width: 5),
                  Text('Playify Official',
                      style: TextStyle(color: _kGold, fontSize: 11, fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                ]),
              ),
            ])),
          ]),

          const SizedBox(height: 16),

          // Bio
          if ((user.bio as String).isNotEmpty) ...[
            Text(user.bio as String,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 14),
          ],

          // Counters
          Row(children: [
            _Counter(count: postCount,      label: 'Posts'),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () => _showFollowers(context),
              child: _Counter(count: followerCount, label: 'Followers'),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () => _showFollowing(context),
              child: _Counter(count: followingCount, label: 'Following'),
            ),
          ]),

          const SizedBox(height: 14),

          // Admin dashboard button
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGold,
                side: const BorderSide(color: _kGold, width: 1.5),
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

  void _showFollowers(BuildContext context) {
    // Navigate to followers list
    context.push('/profile/${(user.handle as String).replaceAll('@','')}?tab=followers');
  }
  void _showFollowing(BuildContext context) {
    context.push('/profile/${(user.handle as String).replaceAll('@','')}?tab=following');
  }
}

// ── Counter widget ─────────────────────────────────────────────────────────────
class _Counter extends StatelessWidget {
  const _Counter({required this.count, required this.label});
  final int count; final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(_fmt(count),
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
    Text(label,
        style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
  ]);
  String _fmt(int n) => n >= 1000000 ? '${(n/1000000).toStringAsFixed(1)}M'
      : n >= 1000 ? '${(n/1000).toStringAsFixed(1)}K'
      : '$n';
}

// ── Post card (admin posts feed) ──────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  const _PostCard({required this.post});
  final Map<String, dynamic> post;
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  int  _likes = 0;
  static const _vps = VpsRepository();

  @override
  void initState() {
    super.initState();
    _likes = (widget.post['likeCount'] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final p       = widget.post;
    final content = (p['content'] as String?) ?? '';
    final created = DateTime.tryParse(p['createdAt']?.toString() ?? '')?.toLocal();
    final age     = _ageLabel(created);
    final media   = (p['mediaUrls'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(padding: const EdgeInsets.fromLTRB(14,14,14,10), child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kGold, width: 1.5),
            ),
            child: const ClipOval(child: Center(
              child: Icon(Icons.admin_panel_settings_rounded, color: _kGold, size: 20),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Text('Playify Official',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              SizedBox(width: 4),
              Icon(Icons.verified_rounded, color: _kGold, size: 14),
            ]),
            Text(age, style: const TextStyle(color: PlayifyColors.muted, fontSize: 11)),
          ])),
        ])),

        // Content
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(content,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
          ),

        // Media
        if (media.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0), bottomRight: Radius.circular(0)),
            child: SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: media.length,
                itemBuilder: (_, i) => Image.network(
                  media[i], fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => Container(
                    color: PlayifyColors.surface,
                    child: const Icon(Icons.broken_image_rounded, color: PlayifyColors.muted),
                  ),
                ),
              ),
            ),
          ),

        // Actions
        Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10), child: Row(children: [
          // Like
          GestureDetector(
            onTap: () async {
              setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
              try {
                await _vps.toggleLike(p['id'] as String);
              } catch (_) {
                setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
              }
            },
            child: Row(children: [
              Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _liked ? const Color(0xFFE31B23) : PlayifyColors.muted, size: 20),
              const SizedBox(width: 4),
              Text('$_likes',
                  style: TextStyle(
                    color: _liked ? const Color(0xFFE31B23) : PlayifyColors.muted,
                    fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 20),
          // Comment
          GestureDetector(
            onTap: () {/* open comments */},
            child: Row(children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: PlayifyColors.muted, size: 19),
              const SizedBox(width: 4),
              Text('${(p['commentCount'] as int?) ?? 0}',
                  style: const TextStyle(color: PlayifyColors.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 20),
          // Share
          GestureDetector(
            onTap: () async {
              try { await _vps.sharePost(p['id'] as String); } catch (_) {}
            },
            child: const Icon(Icons.share_outlined, color: PlayifyColors.muted, size: 19),
          ),
          const Spacer(),
          Text('${(p['shareCount'] as int?) ?? 0} shares',
              style: const TextStyle(color: PlayifyColors.muted, fontSize: 11)),
        ])),
      ]),
    );
  }

  String _ageLabel(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours   < 24) return '${d.inHours}h';
    if (d.inDays    < 7)  return '${d.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── About tab ─────────────────────────────────────────────────────────────────
class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const _Section('About Playify Official', [
        _InfoRow(Icons.info_outline_rounded, 'Playify Official',
            'The official Playify account — announcements, features, and community updates.'),
        _InfoRow(Icons.admin_panel_settings_rounded, 'Role', 'Platform Administrator'),
        _InfoRow(Icons.shield_rounded, 'Status', 'Verified Official Account'),
        _InfoRow(Icons.language_rounded, 'Website', 'playifysport.fun'),
      ]),
      const SizedBox(height: 16),
      const _Section('Social rules for Admin', [
        _InfoRow(Icons.check_circle_outline_rounded, 'Can follow users',
            'Admin follows fans, athletes and creators.', color: Color(0xFF4CAF50)),
        _InfoRow(Icons.check_circle_outline_rounded, 'Fans can follow admin',
            'Following admin shows official posts in your feed.', color: Color(0xFF4CAF50)),
        _InfoRow(Icons.cancel_outlined, 'Cannot fan teams/players',
            'Admin manages entities — cannot fan them.', color: PlayifyColors.muted),
      ]),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title; final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: Colors.white,
        fontSize: 15, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(children: children),
    ),
  ]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.color});
  final IconData icon; final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color ?? PlayifyColors.muted, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: PlayifyColors.muted, fontSize: 11,
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
      ])),
    ]),
  );
}

// ── Admin tab ──────────────────────────────────────────────────────────────────
class _AdminTab extends StatelessWidget {
  const _AdminTab({required this.stats, required this.loading, required this.onRefresh});
  final Map<String, int> stats;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => onRefresh(),
    color: _kGold,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      // Quick action tiles
      const Text('Quick Actions',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _ActionGrid(context),
      const SizedBox(height: 20),

      // Platform stats
      const Text('Platform Stats',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      loading
          ? const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2))
          : _StatsGrid(stats),
    ]),
  );

  Widget _ActionGrid(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
    children: [
      _Tile(context, Icons.sports_soccer_rounded, PlayifyColors.electricBlue, 'Matches', () => context.push('/admin')),
      _Tile(context, Icons.groups_rounded, const Color(0xFF4CAF50), 'Teams', () => context.push('/admin')),
      _Tile(context, Icons.newspaper_rounded, const Color(0xFFFF9800), 'News', () => context.push('/admin')),
      _Tile(context, Icons.person_add_rounded, const Color(0xFF9C27B0), 'Users', () => context.push('/admin')),
      _Tile(context, Icons.upload_file_rounded, const Color(0xFF00BCD4), 'Bulk Upload', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkUploadScreen()))),
      _Tile(context, Icons.analytics_rounded, _kGold, 'Dashboard', () => context.push('/admin')),
    ],
  );

  Widget _Tile(BuildContext ctx, IconData icon, Color color, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );

  Widget _StatsGrid(Map<String, int> s) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.0,
    children: [
      _Stat('👤 Users',        s['users']        ?? 0, PlayifyColors.electricBlue),
      _Stat('📝 Posts',        s['posts']        ?? 0, const Color(0xFF4CAF50)),
      _Stat('⚽ Matches',      s['matches']      ?? 0, const Color(0xFFFF9800)),
      _Stat('🏟 Teams',        s['teams']        ?? 0, const Color(0xFF9C27B0)),
      _Stat('🏃 Players',      s['players']      ?? 0, const Color(0xFF00BCD4)),
      _Stat('🏆 Competitions', s['competitions'] ?? 0, _kGold),
      _Stat('📰 News',         s['news']         ?? 0, const Color(0xFFE31B23)),
    ],
  );

  Widget _Stat(String label, int n, Color color) => Container(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_fmt(n),
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: PlayifyColors.muted, fontSize: 11)),
    ]),
  );

  String _fmt(int n) => n >= 1000000 ? '${(n/1000000).toStringAsFixed(1)}M'
      : n >= 1000 ? '${(n/1000).toStringAsFixed(1)}K'
      : '$n';
}

// ── Tab bar delegate ───────────────────────────────────────────────────────────
class _TabDelegate extends SliverPersistentHeaderDelegate {
  const _TabDelegate(this.tabBar);
  final TabBar tabBar;
  @override double get minExtent => tabBar.preferredSize.height + 1;
  @override double get maxExtent => tabBar.preferredSize.height + 1;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: PlayifyColors.background, child: tabBar);
  @override bool shouldRebuild(_TabDelegate o) => o.tabBar != tabBar;
}
