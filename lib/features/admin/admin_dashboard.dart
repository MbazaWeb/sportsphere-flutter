import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/admin/app_admin.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../scores/presentation/admin_live_control.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD — full-screen admin panel for sportsphere.app@sportsphere.com
// Sections: Overview · Users · Content · Matches · News · System
// ══════════════════════════════════════════════════════════════════════════════

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Stats
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalMatches = 0;
  int _totalNews = 0;
  int _totalTeams = 0;
  bool _statsLoading = true;

  static SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final counts = await Future.wait([
        _sb.from('User').select('id').then((r) => (r as List).length),
        _sb.from('Post').select('id').then((r) => (r as List).length),
        _sb.from('Match').select('id').then((r) => (r as List).length),
        _sb.from('NewsItem').select('id').then((r) => (r as List).length),
        _sb.from('Team').select('id').then((r) => (r as List).length),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers   = counts[0];
          _totalPosts   = counts[1];
          _totalMatches = counts[2];
          _totalNews    = counts[3];
          _totalTeams   = counts[4];
          _statsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (!AppAdmin.isAdminUser(user)) {
      return Scaffold(
        backgroundColor: SportSphereColors.background,
        body: const Center(
          child: Text('Access denied',
              style: TextStyle(color: SportSphereColors.muted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: SportSphereColors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFFFFD700), size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: SportSphereColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: SportSphereColors.muted),
                    onPressed: _loadStats,
                  ),
                ],
              ),
            ),

            // ── Tab bar ───────────────────────────────────────────
            Container(
              color: SportSphereColors.background,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: SportSphereColors.white,
                unselectedLabelColor: SportSphereColors.muted,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                indicator: UnderlineTabIndicator(
                  borderSide: const BorderSide(
                      color: Color(0xFFFFD700), width: 2.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                tabs: const [
                  Tab(text: '📊 Overview'),
                  Tab(text: '👥 Users'),
                  Tab(text: '📝 Content'),
                  Tab(text: '⚽ Matches'),
                  Tab(text: '📰 News'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(
                    loading: _statsLoading,
                    users: _totalUsers,
                    posts: _totalPosts,
                    matches: _totalMatches,
                    news: _totalNews,
                    teams: _totalTeams,
                    onMatchControl: () => openAdminLiveControl(context, ref),
                    onRefresh: _loadStats,
                  ),
                  const _UsersTab(),
                  const _ContentTab(),
                  _MatchesTab(onLiveControl: () => openAdminLiveControl(context, ref)),
                  const _NewsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final bool loading;
  final int users, posts, matches, news, teams;
  final VoidCallback onMatchControl;
  final VoidCallback onRefresh;

  const _OverviewTab({
    required this.loading,
    required this.users,
    required this.posts,
    required this.matches,
    required this.news,
    required this.teams,
    required this.onMatchControl,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: SportSphereColors.electricBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Stats grid
          _SectionLabel('Platform Statistics'),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: CircularProgressIndicator(
                color: SportSphereColors.electricBlue, strokeWidth: 2))
          else
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _StatCard(label: 'Total Users', value: '$users',
                    icon: Icons.people_rounded, color: SportSphereColors.electricBlue),
                _StatCard(label: 'Total Posts', value: '$posts',
                    icon: Icons.article_rounded, color: SportSphereColors.sportGreen),
                _StatCard(label: 'Matches', value: '$matches',
                    icon: Icons.sports_soccer_rounded, color: const Color(0xFFE31B23)),
                _StatCard(label: 'Teams', value: '$teams',
                    icon: Icons.groups_rounded, color: const Color(0xFF9B6DFF)),
                _StatCard(label: 'News Articles', value: '$news',
                    icon: Icons.newspaper_rounded, color: SportSphereColors.sportOrange),
              ],
            ),

          const SizedBox(height: 24),

          // Quick actions
          _SectionLabel('Quick Actions'),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.sensors_rounded,
            color: const Color(0xFFE31B23),
            title: 'Live Match Control',
            subtitle: 'Update scores, status and match minutes in real time',
            onTap: onMatchControl,
          ),
          _ActionCard(
            icon: Icons.newspaper_rounded,
            color: SportSphereColors.sportOrange,
            title: 'Post News Article',
            subtitle: 'Publish breaking news, rumours or updates',
            onTap: () => _showNewsCompose(context),
          ),
          _ActionCard(
            icon: Icons.person_search_rounded,
            color: SportSphereColors.electricBlue,
            title: 'Manage Users',
            subtitle: 'View, verify or moderate user accounts',
            onTap: () {},
          ),
          _ActionCard(
            icon: Icons.add_circle_rounded,
            color: const Color(0xFF9B6DFF),
            title: 'Add Match / Fixture',
            subtitle: 'Schedule a new match in the database',
            onTap: () => _showAddMatch(context),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// USERS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      final rows = q.isEmpty
          ? await sb.from('profiles')
              .select('id, handle, first_name, last_name, role, is_verified, created_at')
              .order('created_at', ascending: false)
              .limit(50)
          : await sb.from('profiles')
              .select('id, handle, first_name, last_name, role, is_verified, created_at')
              .or('handle.ilike.%$q%,first_name.ilike.%$q%,last_name.ilike.%$q%')
              .limit(50);
      if (mounted) setState(() {
        _users = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String id, bool current) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_verified': !current})
          .eq('id', id);
      await _load(_search.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: SportSphereColors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: const TextStyle(color: SportSphereColors.muted),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: SportSphereColors.electricBlue),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: SportSphereColors.muted),
                onPressed: () => _load(_search.text.trim()),
              ),
              filled: true,
              fillColor: SportSphereColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _load,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: SportSphereColors.electricBlue, strokeWidth: 2))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final name =
                        '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                    final handle = u['handle'] ?? '';
                    final role = u['role'] ?? 'fan';
                    final verified = u['is_verified'] == true;
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: SportSphereColors.electricBlue
                            .withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: SportSphereColors.electricBlue,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(name.isNotEmpty ? name : handle,
                              style: const TextStyle(
                                  color: SportSphereColors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          if (verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFFFFD700), size: 14),
                          ],
                        ],
                      ),
                      subtitle: Text('@$handle  ·  $role',
                          style: const TextStyle(
                              color: SportSphereColors.muted, fontSize: 12)),
                      trailing: IconButton(
                        icon: Icon(
                          verified
                              ? Icons.verified_rounded
                              : Icons.verified_outlined,
                          color: verified
                              ? const Color(0xFFFFD700)
                              : SportSphereColors.muted,
                          size: 20,
                        ),
                        tooltip: verified ? 'Remove verification' : 'Verify user',
                        onPressed: () => _verify(u['id'].toString(), verified),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONTENT TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ContentTab extends StatefulWidget {
  const _ContentTab();
  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('Post')
          .select('id, content, postType, authorId, likeCount, commentCount, createdAt')
          .order('createdAt', ascending: false)
          .limit(50);
      if (mounted) setState(() {
        _posts = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SportSphereColors.surface,
        title: const Text('Delete post?',
            style: TextStyle(color: SportSphereColors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: SportSphereColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: SportSphereColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('Post').delete().eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: SportSphereColors.electricBlue, strokeWidth: 2));
    }
    if (_posts.isEmpty) {
      return const Center(child: Text('No posts yet',
          style: TextStyle(color: SportSphereColors.muted)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: SportSphereColors.electricBlue,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _posts.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        itemBuilder: (_, i) {
          final p = _posts[i];
          final content = (p['content'] as String? ?? '');
          final type = p['postType'] ?? 'text';
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SportSphereColors.sportGreen.withValues(alpha: 0.12),
              ),
              child: Icon(
                type == 'poll'
                    ? Icons.poll_rounded
                    : type == 'prediction'
                        ? Icons.insights_rounded
                        : Icons.article_rounded,
                color: SportSphereColors.sportGreen, size: 18,
              ),
            ),
            title: Text(
              content.length > 80 ? '${content.substring(0, 80)}...' : content,
              style: const TextStyle(color: SportSphereColors.white,
                  fontSize: 13),
              maxLines: 2,
            ),
            subtitle: Text(
              '$type  ·  ♥ ${p['likeCount'] ?? 0}  ·  💬 ${p['commentCount'] ?? 0}',
              style: const TextStyle(color: SportSphereColors.muted,
                  fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: SportSphereColors.danger, size: 20),
              onPressed: () => _delete(p['id'].toString()),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MATCHES TAB
// ══════════════════════════════════════════════════════════════════════════════

class _MatchesTab extends StatelessWidget {
  final VoidCallback onLiveControl;
  const _MatchesTab({required this.onLiveControl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActionCard(
          icon: Icons.sensors_rounded,
          color: const Color(0xFFE31B23),
          title: 'Live Match Control',
          subtitle: 'Update scores, status and minutes live',
          onTap: onLiveControl,
        ),
        _ActionCard(
          icon: Icons.add_rounded,
          color: SportSphereColors.sportGreen,
          title: 'Add New Match',
          subtitle: 'Schedule a fixture between two teams',
          onTap: () => _showAddMatch(context),
        ),
        const SizedBox(height: 20),
        const Text(
          'Matches are managed via the Live Control panel above.\n'
          'Use the Scores tab in the main app to view results.',
          style: TextStyle(
              color: SportSphereColors.muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NEWS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _NewsTab extends StatefulWidget {
  const _NewsTab();
  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('NewsItem')
          .select()
          .order('publishedAt', ascending: false)
          .limit(50);
      if (mounted) setState(() {
        _articles = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('${_articles.length} articles',
                    style: const TextStyle(color: SportSphereColors.muted)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.electricBlue),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Article'),
                onPressed: () => _showNewsCompose(context)
                    .then((_) => _load()),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: SportSphereColors.electricBlue, strokeWidth: 2))
              : _articles.isEmpty
                  ? const Center(
                      child: Text('No articles yet. Tap New Article to publish.',
                          style: TextStyle(color: SportSphereColors.muted),
                          textAlign: TextAlign.center))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: SportSphereColors.electricBlue,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount: _articles.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06)),
                        itemBuilder: (_, i) {
                          final a = _articles[i];
                          final breaking = a['is_breaking'] == true ||
                              a['category'] == 'breaking';
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (breaking
                                        ? SportSphereColors.danger
                                        : SportSphereColors.sportOrange)
                                    .withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                breaking
                                    ? Icons.warning_rounded
                                    : Icons.newspaper_rounded,
                                color: breaking
                                    ? SportSphereColors.danger
                                    : SportSphereColors.sportOrange,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              a['title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: SportSphereColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${a['category'] ?? 'updates'}  ·  ${a['source'] ?? 'SportSphere'}',
                              style: const TextStyle(
                                  color: SportSphereColors.muted,
                                  fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: SportSphereColors.danger, size: 20),
                              onPressed: () async {
                                await Supabase.instance.client
                                    .from('NewsItem')
                                    .delete()
                                    .eq('id', a['id'].toString());
                                await _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════════════════════════════════════════

Future<void> _showNewsCompose(BuildContext context) {
  final titleCtrl = TextEditingController();
  final summaryCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final sourceCtrl = TextEditingController(text: 'SportSphere');
  String category = 'updates';
  bool isBreaking = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SportSphereColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Publish News Article',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _AdminField(controller: titleCtrl, label: 'Title'),
              _AdminField(controller: summaryCtrl, label: 'Summary'),
              _AdminField(controller: bodyCtrl, label: 'Body', maxLines: 5),
              _AdminField(controller: sourceCtrl, label: 'Source'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: SportSphereColors.surface,
                style: const TextStyle(color: SportSphereColors.white),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: SportSphereColors.muted),
                ),
                items: const [
                  DropdownMenuItem(value: 'updates', child: Text('Updates')),
                  DropdownMenuItem(value: 'rumors', child: Text('Rumors')),
                  DropdownMenuItem(value: 'breaking', child: Text('Breaking')),
                ],
                onChanged: (v) => setLocal(() => category = v ?? category),
              ),
              SwitchListTile(
                value: isBreaking,
                onChanged: (v) => setLocal(() => isBreaking = v),
                title: const Text('Breaking news',
                    style: TextStyle(color: SportSphereColors.white)),
                activeColor: SportSphereColors.danger,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.electricBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    try {
                      final id =
                          'news-${DateTime.now().millisecondsSinceEpoch}';
                      await Supabase.instance.client
                          .from('NewsItem')
                          .insert({
                        'id': id,
                        'title': titleCtrl.text.trim(),
                        'summary': summaryCtrl.text.trim(),
                        'body': bodyCtrl.text.trim(),
                        'category': category,
                        'source': sourceCtrl.text.trim(),
                        'status': 'published',
                        'is_breaking': isBreaking,
                        'publishedAt': DateTime.now().toIso8601String(),
                        'likeCount': 0,
                        'commentCount': 0,
                        'shareCount': 0,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: const Text('Publish',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showAddMatch(BuildContext context) {
  final homeCtrl = TextEditingController();
  final awayCtrl = TextEditingController();
  final leagueCtrl = TextEditingController(text: 'Tanzania Premier League');
  DateTime kickoff = DateTime.now().add(const Duration(days: 1));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SportSphereColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Schedule Match',
                  style: TextStyle(color: SportSphereColors.white,
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _AdminField(controller: homeCtrl, label: 'Home Team'),
              _AdminField(controller: awayCtrl, label: 'Away Team'),
              _AdminField(controller: leagueCtrl, label: 'League'),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Kickoff: ${kickoff.day}/${kickoff.month}/${kickoff.year} ${kickoff.hour}:${kickoff.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: SportSphereColors.white),
                ),
                trailing: const Icon(Icons.calendar_today_rounded,
                    color: SportSphereColors.electricBlue),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: kickoff,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(kickoff),
                  );
                  if (time == null) return;
                  setLocal(() => kickoff = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.sportGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (homeCtrl.text.trim().isEmpty ||
                        awayCtrl.text.trim().isEmpty) return;
                    try {
                      final id =
                          'match-${DateTime.now().millisecondsSinceEpoch}';
                      await Supabase.instance.client.from('Match').insert({
                        'id': id,
                        'homeTeam': homeCtrl.text.trim(),
                        'awayTeam': awayCtrl.text.trim(),
                        'league': leagueCtrl.text.trim(),
                        'kickoffAt': kickoff.toUtc().toIso8601String(),
                        'status': 'scheduled',
                        'homeScore': 0,
                        'awayScore': 0,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: const Text('Schedule Match',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: SportSphereColors.muted.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
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
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionCard({
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xD0071422),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
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

class _AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  const _AdminField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: SportSphereColors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: SportSphereColors.muted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: SportSphereColors.electricBlue),
          ),
        ),
      ),
    );
  }
}
