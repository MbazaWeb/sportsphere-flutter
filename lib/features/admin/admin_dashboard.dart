import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/admin/app_admin.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../scores/presentation/admin_live_control.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD — Full Rebuild
// Overview · Users · Content · Matches · News
// ══════════════════════════════════════════════════════════════════════════════

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalMatches = 0;
  int _totalTeams = 0;
  int _totalNews = 0;
  int _totalCommunities = 0;
  int _totalPlayers = 0;
  int _totalCoaches = 0;
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
      final results = await Future.wait([
        _count('profiles'),
        _count('Post'),
        _count('Match'),
        _count('Team'),
        _count('NewsItem'),
        _count('Community'),
        _countRole('player'),
        _countRole('coach'),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers = results[0];
          _totalPosts = results[1];
          _totalMatches = results[2];
          _totalTeams = results[3];
          _totalNews = results[4];
          _totalCommunities = results[5];
          _totalPlayers = results[6];
          _totalCoaches = results[7];
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<int> _count(String table) async {
    try {
      final r = await _sb.from(table).select('id');
      return (r as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countRole(String role) async {
    try {
      final r = await _sb
          .from('profiles')
          .select('id')
          .ilike('role', role);
      return (r as List).length;
    } catch (_) {
      try {
        final r = await _sb.from('User').select('id').ilike('role', role);
        return (r as List).length;
      } catch (_) {
        return 0;
      }
    }
  }

  void _goToTab(int index) {
    _tabs.animateTo(index);
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
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: SportSphereColors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
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

            // Tab bar
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
                    teams: _totalTeams,
                    news: _totalNews,
                    communities: _totalCommunities,
                    players: _totalPlayers,
                    coaches: _totalCoaches,
                    onMatchControl: () =>
                        openAdminLiveControl(context, ref),
                    onPostNews: () => _showNewsCompose(context)
                        .then((_) => _loadStats()),
                    onAddMatch: () => _showAddFixture(context)
                        .then((_) => _loadStats()),
                    onCreateTeam: () => _showCreateTeam(context)
                        .then((_) => _loadStats()),
                    onCreateCompetition: () =>
                        _showCreateCompetition(context)
                            .then((_) => _loadStats()),
                    onManageUsers: () => _goToTab(1),
                    onRefresh: _loadStats,
                  ),
                  const _UsersTab(),
                  const _ContentTab(),
                  _MatchesTab(
                    onLiveControl: () =>
                        openAdminLiveControl(context, ref),
                  ),
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
  final int users, posts, matches, teams, news, communities, players, coaches;
  final VoidCallback onMatchControl;
  final VoidCallback onPostNews;
  final VoidCallback onAddMatch;
  final VoidCallback onCreateTeam;
  final VoidCallback onCreateCompetition;
  final VoidCallback onManageUsers;
  final VoidCallback onRefresh;

  const _OverviewTab({
    required this.loading,
    required this.users,
    required this.posts,
    required this.matches,
    required this.teams,
    required this.news,
    required this.communities,
    required this.players,
    required this.coaches,
    required this.onMatchControl,
    required this.onPostNews,
    required this.onAddMatch,
    required this.onCreateTeam,
    required this.onCreateCompetition,
    required this.onManageUsers,
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
          const _SectionLabel('Platform Statistics'),
          const SizedBox(height: 10),
          if (loading)
            const Center(
                child: CircularProgressIndicator(
                    color: SportSphereColors.electricBlue, strokeWidth: 2))
          else
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                    label: 'Users',
                    value: '$users',
                    icon: Icons.people_rounded,
                    color: SportSphereColors.electricBlue),
                _StatCard(
                    label: 'Posts',
                    value: '$posts',
                    icon: Icons.article_rounded,
                    color: SportSphereColors.sportGreen),
                _StatCard(
                    label: 'Matches',
                    value: '$matches',
                    icon: Icons.sports_soccer_rounded,
                    color: const Color(0xFFE31B23)),
                _StatCard(
                    label: 'Teams',
                    value: '$teams',
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF9B6DFF)),
                _StatCard(
                    label: 'News',
                    value: '$news',
                    icon: Icons.newspaper_rounded,
                    color: SportSphereColors.sportOrange),
                _StatCard(
                    label: 'Communities',
                    value: '$communities',
                    icon: Icons.forum_rounded,
                    color: const Color(0xFF00C9A7)),
                _StatCard(
                    label: 'Players',
                    value: '$players',
                    icon: Icons.sports_rounded,
                    color: const Color(0xFFFF6B9D)),
                _StatCard(
                    label: 'Coaches',
                    value: '$coaches',
                    icon: Icons.psychology_rounded,
                    color: const Color(0xFFFFB800)),
              ],
            ),
          const SizedBox(height: 24),
          const _SectionLabel('Quick Actions'),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.sensors_rounded,
            color: const Color(0xFFE31B23),
            title: 'Live Match Control',
            subtitle: 'Real-time score + minute updates',
            onTap: onMatchControl,
          ),
          _ActionCard(
            icon: Icons.newspaper_rounded,
            color: SportSphereColors.sportOrange,
            title: 'Post News Article',
            subtitle: 'Breaking, updates or rumors',
            onTap: onPostNews,
          ),
          _ActionCard(
            icon: Icons.add_circle_rounded,
            color: SportSphereColors.sportGreen,
            title: 'Add Match / Fixture',
            subtitle: 'Schedule a new fixture',
            onTap: onAddMatch,
          ),
          _ActionCard(
            icon: Icons.groups_rounded,
            color: const Color(0xFF9B6DFF),
            title: 'Create Team',
            subtitle: 'Name, handle, country, league, logo',
            onTap: onCreateTeam,
          ),
          _ActionCard(
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFFFB800),
            title: 'Create Competition',
            subtitle: 'Name, sport, country, season, logo',
            onTap: onCreateCompetition,
          ),
          _ActionCard(
            icon: Icons.person_search_rounded,
            color: SportSphereColors.electricBlue,
            title: 'Manage Users',
            subtitle: 'Edit, verify, promote or delete accounts',
            onTap: onManageUsers,
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

  static const _roles = [
    'fan',
    'player',
    'coach',
    'team',
    'admin',
    'journalist',
    'analyst',
    'scout',
    'creator',
    'moderator',
    'official',
  ];

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      dynamic rows;
      if (q.isEmpty) {
        rows = await sb
            .from('profiles')
            .select(
                'id, handle, first_name, last_name, role, is_verified, avatar_url, created_at')
            .order('created_at', ascending: false)
            .limit(80);
      } else {
        rows = await sb
            .from('profiles')
            .select(
                'id, handle, first_name, last_name, role, is_verified, avatar_url, created_at')
            .or('handle.ilike.%$q%,first_name.ilike.%$q%,last_name.ilike.%$q%')
            .limit(50);
      }
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String id, bool current) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_verified': !current}).eq('id', id);
      await _load(_search.text.trim());
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _promote(String id, String currentRole) async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Promote / Change Role',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            ..._roles.map((r) => ListTile(
                  title: Text(r.toUpperCase(),
                      style: TextStyle(
                          color: r == currentRole
                              ? SportSphereColors.electricBlue
                              : SportSphereColors.white,
                          fontWeight: FontWeight.w600)),
                  trailing: r == currentRole
                      ? const Icon(Icons.check,
                          color: SportSphereColors.electricBlue)
                      : null,
                  onTap: () => Navigator.pop(context, r),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (next == null || next == currentRole) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': next}).eq('id', id);
      await _load(_search.text.trim());
      _snack('Role updated to $next');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _editUser(Map<String, dynamic> u) async {
    final nameCtrl = TextEditingController(
        text: '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim());
    final handleCtrl =
        TextEditingController(text: (u['handle'] as String? ?? ''));
    String role = (u['role'] as String? ?? 'fan').toLowerCase();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit User',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 16),
              _AdminField(controller: nameCtrl, label: 'Full name'),
              _AdminField(controller: handleCtrl, label: 'Handle (no @)'),
              const Text('Role',
                  style:
                      TextStyle(color: SportSphereColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: role == r,
                          selectedColor:
                              SportSphereColors.electricBlue.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                              color: role == r
                                  ? SportSphereColors.electricBlue
                                  : SportSphereColors.muted,
                              fontSize: 12),
                          onSelected: (_) => setLocal(() => role = r),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.electricBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save changes',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final parts = nameCtrl.text.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    try {
      await Supabase.instance.client.from('profiles').update({
        'first_name': first,
        'last_name': last,
        'handle': handleCtrl.text.trim().replaceAll('@', '').toLowerCase(),
        'role': role,
      }).eq('id', u['id'].toString());
      await _load(_search.text.trim());
      _snack('User updated');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _deleteUser(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SportSphereColors.surface,
        title: const Text('Delete user?',
            style: TextStyle(color: SportSphereColors.white)),
        content: Text(
          'Remove $name permanently? This cannot be undone.',
          style: const TextStyle(color: SportSphereColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
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
      await Supabase.instance.client.from('profiles').delete().eq('id', id);
      await _load(_search.text.trim());
      _snack('User deleted');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _createUser() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final handleCtrl = TextEditingController();
    String role = 'fan';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create User',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 16),
              _AdminField(controller: emailCtrl, label: 'Email'),
              _AdminField(controller: nameCtrl, label: 'Full name'),
              _AdminField(controller: handleCtrl, label: 'Handle'),
              const Text('Role',
                  style:
                      TextStyle(color: SportSphereColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: role == r,
                          selectedColor: SportSphereColors.electricBlue
                              .withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                              color: role == r
                                  ? SportSphereColors.electricBlue
                                  : SportSphereColors.muted,
                              fontSize: 12),
                          onSelected: (_) => setLocal(() => role = r),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.sportGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create account',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Email required');
      return;
    }
    final parts = nameCtrl.text.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final handle = handleCtrl.text
        .trim()
        .replaceAll('@', '')
        .toLowerCase()
        .isEmpty
        ? email.split('@').first
        : handleCtrl.text.trim().replaceAll('@', '').toLowerCase();

    try {
      // Create auth user (admin flow – requires service role on backend ideally).
      // Fallback: insert profile row directly for now.
      final id = 'user-${DateTime.now().millisecondsSinceEpoch}';
      await Supabase.instance.client.from('profiles').insert({
        'id': id,
        'email': email,
        'first_name': first,
        'last_name': last,
        'handle': handle,
        'role': role,
        'is_verified': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _load(_search.text.trim());
      _snack('User created (profile only – invite via auth if needed)');
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: SportSphereColors.white),
                  decoration: InputDecoration(
                    hintText: 'Search users…',
                    hintStyle: const TextStyle(color: SportSphereColors.muted),
                    prefixIcon: const Icon(Icons.search,
                        color: SportSphereColors.muted, size: 20),
                    filled: true,
                    fillColor: SportSphereColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _load,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SportSphereColors.sportGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Create'),
                onPressed: _createUser,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: SportSphereColors.electricBlue, strokeWidth: 2))
              : _users.isEmpty
                  ? const Center(
                      child: Text('No users found',
                          style: TextStyle(color: SportSphereColors.muted)))
                  : RefreshIndicator(
                      onRefresh: () => _load(_search.text.trim()),
                      color: SportSphereColors.electricBlue,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06)),
                        itemBuilder: (_, i) {
                          final u = _users[i];
                          final first = u['first_name'] as String? ?? '';
                          final last = u['last_name'] as String? ?? '';
                          final name = '$first $last'.trim();
                          final handle = u['handle'] as String? ?? '';
                          final role =
                              (u['role'] as String? ?? 'fan').toLowerCase();
                          final verified = u['is_verified'] == true;
                          final avatar = u['avatar_url'] as String?;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: SportSphereColors.electricBlue
                                  .withValues(alpha: 0.15),
                              backgroundImage: avatar != null &&
                                      avatar.isNotEmpty
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar == null || avatar.isEmpty
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: SportSphereColors.electricBlue,
                                          fontWeight: FontWeight.w800),
                                    )
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name.isNotEmpty ? name : handle,
                                    style: const TextStyle(
                                        color: SportSphereColors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (verified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded,
                                      color: Color(0xFFFFD700), size: 14),
                                ],
                              ],
                            ),
                            subtitle: Text('@$handle  ·  $role',
                                style: const TextStyle(
                                    color: SportSphereColors.muted,
                                    fontSize: 12)),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: SportSphereColors.muted, size: 20),
                              color: SportSphereColors.surface2,
                              onSelected: (v) {
                                switch (v) {
                                  case 'edit':
                                    _editUser(u);
                                    break;
                                  case 'promote':
                                    _promote(u['id'].toString(), role);
                                    break;
                                  case 'verify':
                                    _verify(u['id'].toString(), verified);
                                    break;
                                  case 'delete':
                                    _deleteUser(
                                        u['id'].toString(),
                                        name.isNotEmpty ? name : handle);
                                    break;
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit',
                                        style: TextStyle(
                                            color: SportSphereColors.white))),
                                const PopupMenuItem(
                                    value: 'promote',
                                    child: Text('Promote / Change role',
                                        style: TextStyle(
                                            color: SportSphereColors.white))),
                                PopupMenuItem(
                                    value: 'verify',
                                    child: Text(
                                        verified
                                            ? 'Remove verification'
                                            : 'Verify (gold tick)',
                                        style: const TextStyle(
                                            color: SportSphereColors.white))),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(
                                            color: SportSphereColors.danger))),
                              ],
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
          .select(
              'id, content, postType, authorId, likeCount, commentCount, isPinned, createdAt')
          .order('createdAt', ascending: false)
          .limit(60);
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _togglePin(String id, bool current) async {
    try {
      await Supabase.instance.client
          .from('Post')
          .update({'isPinned': !current}).eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _createPost() async {
    final contentCtrl = TextEditingController();
    String postType = 'text';
    bool isPrediction = false;
    bool hasPoll = false;
    final pollOptions = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Post',
                    style: TextStyle(
                        color: SportSphereColors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                const SizedBox(height: 16),
                _AdminField(
                    controller: contentCtrl, label: 'Post text', maxLines: 4),
                const Text('Type',
                    style: TextStyle(
                        color: SportSphereColors.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['text', 'image', 'video', 'poll', 'prediction']
                      .map((t) => ChoiceChip(
                            label: Text(t),
                            selected: postType == t,
                            selectedColor: SportSphereColors.electricBlue
                                .withValues(alpha: 0.25),
                            labelStyle: TextStyle(
                                color: postType == t
                                    ? SportSphereColors.electricBlue
                                    : SportSphereColors.muted,
                                fontSize: 12),
                            onSelected: (_) => setLocal(() {
                              postType = t;
                              hasPoll = t == 'poll';
                              isPrediction = t == 'prediction';
                            }),
                          ))
                      .toList(),
                ),
                if (hasPoll) ...[
                  const SizedBox(height: 12),
                  const Text('Poll options',
                      style: TextStyle(
                          color: SportSphereColors.muted, fontSize: 12)),
                  ...pollOptions.map((c) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _AdminField(controller: c, label: 'Option'),
                      )),
                  TextButton.icon(
                    onPressed: () => setLocal(
                        () => pollOptions.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add option'),
                  ),
                ],
                const SizedBox(height: 16),
                // Note: image/video upload would use image_picker + storage
                // in a full implementation; placeholder for now.
                if (postType == 'image' || postType == 'video')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.cloud_upload_rounded,
                            color: SportSphereColors.muted, size: 32),
                        SizedBox(height: 8),
                        Text('Media upload (wire image_picker + Supabase Storage)',
                            style: TextStyle(
                                color: SportSphereColors.muted, fontSize: 12),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: SportSphereColors.sportGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
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
    if (ok != true || contentCtrl.text.trim().isEmpty) return;

    try {
      final id = 'post-${DateTime.now().millisecondsSinceEpoch}';
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final payload = <String, dynamic>{
        'id': id,
        'content': contentCtrl.text.trim(),
        'postType': postType,
        'authorId': uid,
        'likeCount': 0,
        'commentCount': 0,
        'isPinned': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (hasPoll) {
        payload['pollOptions'] = pollOptions
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (isPrediction) {
        payload['isPrediction'] = true;
      }
      await Supabase.instance.client.from('Post').insert(payload);
      await _load();
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
          child: Row(
            children: [
              const Expanded(
                child: Text('All Posts',
                    style: TextStyle(
                        color: SportSphereColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SportSphereColors.sportGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Post'),
                onPressed: _createPost,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: SportSphereColors.electricBlue, strokeWidth: 2))
              : _posts.isEmpty
                  ? const Center(
                      child: Text('No posts yet',
                          style: TextStyle(color: SportSphereColors.muted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: SportSphereColors.electricBlue,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06)),
                        itemBuilder: (_, i) {
                          final p = _posts[i];
                          final content = (p['content'] as String? ?? '');
                          final type = p['postType'] ?? 'text';
                          final likes = p['likeCount'] ?? 0;
                          final comments = p['commentCount'] ?? 0;
                          final pinned = p['isPinned'] == true;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SportSphereColors.electricBlue
                                    .withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                pinned
                                    ? Icons.push_pin_rounded
                                    : Icons.article_rounded,
                                color: pinned
                                    ? const Color(0xFFFFD700)
                                    : SportSphereColors.electricBlue,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              content.isEmpty ? '(empty)' : content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: SportSphereColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '$type  ·  $likes likes  ·  $comments comments',
                              style: const TextStyle(
                                  color: SportSphereColors.muted, fontSize: 11),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: SportSphereColors.muted, size: 20),
                              color: SportSphereColors.surface2,
                              onSelected: (v) {
                                if (v == 'pin') {
                                  _togglePin(p['id'].toString(), pinned);
                                } else if (v == 'delete') {
                                  _delete(p['id'].toString());
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'pin',
                                  child: Text(
                                      pinned ? 'Unpin' : 'Pin / Feature',
                                      style: const TextStyle(
                                          color: SportSphereColors.white)),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete',
                                      style: TextStyle(
                                          color: SportSphereColors.danger)),
                                ),
                              ],
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
// MATCHES TAB
// ══════════════════════════════════════════════════════════════════════════════

class _MatchesTab extends StatefulWidget {
  final VoidCallback onLiveControl;
  const _MatchesTab({required this.onLiveControl});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> {
  List<Map<String, dynamic>> _matches = [];
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
          .from('Match')
          .select(
              'id, homeTeam, awayTeam, league, kickoffAt, status, homeScore, awayScore, venue')
          .order('kickoffAt', ascending: false)
          .limit(40);
      if (mounted) {
        setState(() {
          _matches = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateResult(Map<String, dynamic> m) async {
    final homeCtrl =
        TextEditingController(text: '${m['homeScore'] ?? 0}');
    final awayCtrl =
        TextEditingController(text: '${m['awayScore'] ?? 0}');
    String status = (m['status'] as String? ?? 'scheduled').toLowerCase();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m['homeTeam'] ?? 'Home'} vs ${m['awayTeam'] ?? 'Away'}',
                style: const TextStyle(
                    color: SportSphereColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _AdminField(
                          controller: homeCtrl, label: 'Home score')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _AdminField(
                          controller: awayCtrl, label: 'Away score')),
                ],
              ),
              const Text('Status',
                  style:
                      TextStyle(color: SportSphereColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['scheduled', 'live', 'ht', 'ft', 'postponed']
                    .map((s) => ChoiceChip(
                          label: Text(s.toUpperCase()),
                          selected: status == s,
                          selectedColor: SportSphereColors.electricBlue
                              .withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                              color: status == s
                                  ? SportSphereColors.electricBlue
                                  : SportSphereColors.muted,
                              fontSize: 12),
                          onSelected: (_) => setLocal(() => status = s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.electricBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Update Result',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('Match').update({
        'homeScore': int.tryParse(homeCtrl.text.trim()) ?? 0,
        'awayScore': int.tryParse(awayCtrl.text.trim()) ?? 0,
        'status': status,
      }).eq('id', m['id'].toString());
      await _load();
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.emoji_events_rounded,
                      label: 'Competition',
                      color: const Color(0xFFFFB800),
                      onTap: () => _showCreateCompetition(context)
                          .then((_) => _load()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.groups_rounded,
                      label: 'Create Team',
                      color: const Color(0xFF9B6DFF),
                      onTap: () =>
                          _showCreateTeam(context).then((_) => _load()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.add_circle_rounded,
                      label: 'Fixture',
                      color: SportSphereColors.sportGreen,
                      onTap: () =>
                          _showAddFixture(context).then((_) => _load()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniAction(
                      icon: Icons.sensors_rounded,
                      label: 'Live Control',
                      color: const Color(0xFFE31B23),
                      onTap: widget.onLiveControl,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: SportSphereColors.electricBlue, strokeWidth: 2))
              : _matches.isEmpty
                  ? const Center(
                      child: Text('No matches yet. Create a fixture.',
                          style: TextStyle(color: SportSphereColors.muted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: SportSphereColors.electricBlue,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06)),
                        itemBuilder: (_, i) {
                          final m = _matches[i];
                          final status =
                              (m['status'] as String? ?? 'scheduled')
                                  .toUpperCase();
                          final home = m['homeTeam'] ?? 'Home';
                          final away = m['awayTeam'] ?? 'Away';
                          final hs = m['homeScore'] ?? 0;
                          final as_ = m['awayScore'] ?? 0;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            title: Text(
                              '$home  $hs – $as_  $away',
                              style: const TextStyle(
                                  color: SportSphereColors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            subtitle: Text(
                              '${m['league'] ?? '—'}  ·  $status',
                              style: const TextStyle(
                                  color: SportSphereColors.muted, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: SportSphereColors.electricBlue,
                                  size: 20),
                              tooltip: 'Update result',
                              onPressed: () => _updateResult(m),
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

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
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
          .select(
              'id, title, summary, category, is_breaking, source, created_at, image_url')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _articles = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: SportSphereColors.surface,
        title: const Text('Delete article?',
            style: TextStyle(color: SportSphereColors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: SportSphereColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
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
      await Supabase.instance.client
          .from('NewsItem')
          .delete()
          .eq('id', id);
      await _load();
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
          child: Row(
            children: [
              const Expanded(
                child: Text('News Articles',
                    style: TextStyle(
                        color: SportSphereColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SportSphereColors.sportOrange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Article'),
                onPressed: () =>
                    _showNewsCompose(context).then((_) => _load()),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: SportSphereColors.electricBlue, strokeWidth: 2))
              : _articles.isEmpty
                  ? const Center(
                      child: Text(
                          'No articles yet. Tap New Article to publish.',
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
                              width: 36,
                              height: 36,
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
                                  color: SportSphereColors.muted, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: SportSphereColors.danger, size: 20),
                              onPressed: () =>
                                  _delete(a['id'].toString()),
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
// SHARED SHEETS & HELPERS
// ══════════════════════════════════════════════════════════════════════════════

Future<void> _showNewsCompose(BuildContext context,
    {Map<String, dynamic>? existing}) {
  final titleCtrl =
      TextEditingController(text: existing?['title'] as String? ?? '');
  final summaryCtrl =
      TextEditingController(text: existing?['summary'] as String? ?? '');
  final bodyCtrl =
      TextEditingController(text: existing?['body'] as String? ?? '');
  final sourceCtrl = TextEditingController(
      text: existing?['source'] as String? ?? 'SportSphere');
  String category = existing?['category'] as String? ?? 'updates';
  bool isBreaking = existing?['is_breaking'] == true;
  bool addPoll = false;
  bool addPrediction = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SportSphereColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'New Article' : 'Edit Article',
                  style: const TextStyle(
                      color: SportSphereColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 16),
              _AdminField(controller: titleCtrl, label: 'Title'),
              _AdminField(controller: summaryCtrl, label: 'Summary'),
              _AdminField(
                  controller: bodyCtrl, label: 'Body text', maxLines: 5),
              _AdminField(controller: sourceCtrl, label: 'Source'),
              const Text('Category',
                  style:
                      TextStyle(color: SportSphereColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['breaking', 'updates', 'rumors']
                    .map((c) => ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          selectedColor: SportSphereColors.sportOrange
                              .withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                              color: category == c
                                  ? SportSphereColors.sportOrange
                                  : SportSphereColors.muted,
                              fontSize: 12),
                          onSelected: (_) => setLocal(() {
                            category = c;
                            if (c == 'breaking') isBreaking = true;
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Breaking news',
                    style: TextStyle(color: SportSphereColors.white)),
                value: isBreaking,
                activeColor: SportSphereColors.danger,
                onChanged: (v) => setLocal(() => isBreaking = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add Poll',
                    style: TextStyle(color: SportSphereColors.white)),
                value: addPoll,
                activeColor: SportSphereColors.electricBlue,
                onChanged: (v) => setLocal(() => addPoll = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add Prediction',
                    style: TextStyle(color: SportSphereColors.white)),
                value: addPrediction,
                activeColor: SportSphereColors.sportGreen,
                onChanged: (v) => setLocal(() => addPrediction = v),
              ),
              const SizedBox(height: 8),
              // Image / PDF placeholders
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Wire image_picker + storage upload
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Image upload: connect image_picker + Supabase Storage')),
                        );
                      },
                      icon: const Icon(Icons.image_rounded, size: 18),
                      label: const Text('Image'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SportSphereColors.muted,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'PDF upload: connect file_picker + Supabase Storage')),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SportSphereColors.muted,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SportSphereColors.sportOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    try {
                      final payload = {
                        'title': titleCtrl.text.trim(),
                        'summary': summaryCtrl.text.trim(),
                        'body': bodyCtrl.text.trim(),
                        'source': sourceCtrl.text.trim(),
                        'category': category,
                        'is_breaking': isBreaking,
                        'created_at':
                            DateTime.now().toUtc().toIso8601String(),
                        if (addPoll) 'has_poll': true,
                        if (addPrediction) 'has_prediction': true,
                      };
                      if (existing != null) {
                        await Supabase.instance.client
                            .from('NewsItem')
                            .update(payload)
                            .eq('id', existing['id'].toString());
                      } else {
                        payload['id'] =
                            'news-${DateTime.now().millisecondsSinceEpoch}';
                        await Supabase.instance.client
                            .from('NewsItem')
                            .insert(payload);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: Text(
                      existing == null ? 'Publish Article' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showCreateCompetition(BuildContext context) {
  final nameCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final seasonCtrl = TextEditingController();
  String sport = 'football';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SportSphereColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Competition',
                style: TextStyle(
                    color: SportSphereColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 16),
            _AdminField(controller: nameCtrl, label: 'Name'),
            _AdminField(controller: countryCtrl, label: 'Country'),
            _AdminField(controller: seasonCtrl, label: 'Season (e.g. 2025/26)'),
            const Text('Sport',
                style: TextStyle(color: SportSphereColors.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                'football',
                'basketball',
                'netball',
                'athletics',
                'volleyball',
                'rugby'
              ]
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: sport == s,
                        selectedColor:
                            SportSphereColors.electricBlue.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                            color: sport == s
                                ? SportSphereColors.electricBlue
                                : SportSphereColors.muted,
                            fontSize: 12),
                        onSelected: (_) => setLocal(() => sport = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    final id =
                        'comp-${DateTime.now().millisecondsSinceEpoch}';
                    await Supabase.instance.client.from('Competition').insert({
                      'id': id,
                      'name': nameCtrl.text.trim(),
                      'sport': sport,
                      'country': countryCtrl.text.trim(),
                      'season': seasonCtrl.text.trim(),
                      'created_at':
                          DateTime.now().toUtc().toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    // Table may not exist yet – still close & inform
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Competition: $e')));
                      Navigator.pop(ctx);
                    }
                  }
                },
                child: const Text('Create Competition',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showCreateTeam(BuildContext context) {
  final nameCtrl = TextEditingController();
  final handleCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final leagueCtrl = TextEditingController();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SportSphereColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Team',
              style: TextStyle(
                  color: SportSphereColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          const SizedBox(height: 16),
          _AdminField(controller: nameCtrl, label: 'Team name'),
          _AdminField(controller: handleCtrl, label: 'Handle'),
          _AdminField(controller: countryCtrl, label: 'Country'),
          _AdminField(controller: leagueCtrl, label: 'League / Competition'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9B6DFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  final id = 'team-${DateTime.now().millisecondsSinceEpoch}';
                  await Supabase.instance.client.from('Team').insert({
                    'id': id,
                    'name': nameCtrl.text.trim(),
                    'handle': handleCtrl.text
                        .trim()
                        .replaceAll('@', '')
                        .toLowerCase(),
                    'country': countryCtrl.text.trim(),
                    'league': leagueCtrl.text.trim(),
                    'created_at':
                        DateTime.now().toUtc().toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Create Team',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showAddFixture(BuildContext context) {
  final homeCtrl = TextEditingController();
  final awayCtrl = TextEditingController();
  final leagueCtrl = TextEditingController();
  final venueCtrl = TextEditingController();
  DateTime kickoff = DateTime.now().add(const Duration(days: 1));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SportSphereColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Match / Fixture',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 16),
              _AdminField(controller: homeCtrl, label: 'Home team'),
              _AdminField(controller: awayCtrl, label: 'Away team'),
              _AdminField(
                  controller: leagueCtrl, label: 'Competition / League'),
              _AdminField(controller: venueCtrl, label: 'Venue'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kick-off',
                    style: TextStyle(color: SportSphereColors.muted)),
                subtitle: Text(
                  '${kickoff.day}/${kickoff.month}/${kickoff.year}  ${kickoff.hour.toString().padLeft(2, '0')}:${kickoff.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: SportSphereColors.white,
                      fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.calendar_today_rounded,
                    color: SportSphereColors.electricBlue),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: kickoff,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(kickoff),
                  );
                  if (time == null) return;
                  setLocal(() => kickoff = DateTime(date.year, date.month,
                      date.day, time.hour, time.minute));
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
                        'venue': venueCtrl.text.trim(),
                        'kickoffAt': kickoff.toUtc().toIso8601String(),
                        'status': 'scheduled',
                        'homeScore': 0,
                        'awayScore': 0,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
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
      text,
      style: const TextStyle(
        color: SportSphereColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
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
        color: const Color(0xD0071422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          Text(label,
              style: const TextStyle(
                  color: SportSphereColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
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
              width: 44,
              height: 44,
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
            borderSide:
                const BorderSide(color: SportSphereColors.electricBlue),
          ),
        ),
      ),
    );
  }
}
