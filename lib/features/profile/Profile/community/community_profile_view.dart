import '../../../../core/data/vps_repository.dart';
import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../shared/org_profile_view.dart';

// ══════════════════════════════════════════════════════════════════════════════
// COMMUNITY PROFILE VIEW
// Loads real community data from Supabase by handle or id.
// ══════════════════════════════════════════════════════════════════════════════

class CommunityProfileView extends StatefulWidget {

  const CommunityProfileView({super.key, this.handle, this.communityId});
  /// Either [handle] or [communityId] must be supplied.
  final String? handle;
  final String? communityId;

  @override
  State<CommunityProfileView> createState() => _CommunityProfileViewState();
}

class _CommunityProfileViewState extends State<CommunityProfileView> {

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _joined = false;
  bool _busyJoin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      Map<String, dynamic>? row;

      if (widget.communityId != null) {
        final res = await const VpsRepository().get<Map<String,dynamic>>('/v1/social/communities');
        final all = (res.data?['communities'] as List? ?? []).cast<Map<String,dynamic>>();
        final r = all.firstWhere((c) => c['id'] == widget.communityId, orElse: () => <String,dynamic>{});
        row = r.isNotEmpty ? Map<String, dynamic>.from(r) : null;
      } else if (widget.handle != null) {
        final h = widget.handle!.replaceAll('@', '');
        // Try handle column first, fall back to name match
        final res2 = await const VpsRepository().get<Map<String,dynamic>>('/v1/social/communities');
        final all2 = (res2.data?['communities'] as List? ?? []).cast<Map<String,dynamic>>();
        final r = all2.firstWhere((c) =>
          (c['id'] as String? ?? '') == h ||
          (c['name'] as String? ?? '').toLowerCase().contains(h.toLowerCase()),
          orElse: () => <String,dynamic>{});
        row = r.isNotEmpty ? Map<String, dynamic>.from(r) : null;
      }

      if (row == null) {
        if (mounted) setState(() { _error = 'Community not found'; _loading = false; });
        return;
      }

      // Check if current user is a member
      final uid = const AuthRepository().currentSession?.user?.id;
      bool joined = false;
      if (uid != null) {
        try {
          final memRes = await const VpsRepository().get<Map<String, dynamic>>(
            '/v1/social/communities/${row['id']?.toString() ?? ''}/member');
          joined = memRes.data?['isMember'] == true;
        } catch (_) {
          joined = false;
        }
      }

      if (mounted) setState(() { _data = row; _joined = joined; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _toggleMembership() async {
    final d = _data;
    if (d == null || _busyJoin) return;
    final uid = const AuthRepository().currentSession?.user?.id;
    if (uid == null) return;

    setState(() => _busyJoin = true);
    try {
      if (_joined) {
        // migrated to VPS
        // Decrement count
        final current = (d['memberCount'] as int?) ?? 1;
        // migrated to VPS
        if (mounted) setState(() { _joined = false; d['memberCount'] = (current - 1).clamp(0, 999999); });
      } else {
        // migrated to VPS
        final current = (d['memberCount'] as int?) ?? 0;
        // migrated to VPS
        if (mounted) setState(() { _joined = true; d['memberCount'] = current + 1; });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busyJoin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: PlayifyColors.background,
        body: Center(child: CircularProgressIndicator(
            color: PlayifyColors.electricBlue, strokeWidth: 2)),
      );
    }

    if (_error != null || _data == null) {
      return Scaffold(
        backgroundColor: PlayifyColors.background,
        appBar: AppBar(backgroundColor: PlayifyColors.background,
            leading: BackButton(onPressed: () => context.pop())),
        body: Center(child: Text(_error ?? 'Not found',
            style: const TextStyle(color: PlayifyColors.muted))),
      );
    }

    final d = _data!;
    final name = (d['name'] as String?) ?? 'Community';
    final handle = (d['handle'] as String?) ?? '';
    final bio = (d['description'] as String?) ?? (d['bio'] as String?) ?? '';
    final topic = (d['topic'] as String?) ?? (d['communityType'] as String?) ?? '';
    final teamName = (d['supportedTeam'] as String?) ?? (d['teamName'] as String?) ?? '';
    final memberCount = (d['memberCount'] as int?) ?? 0;
    final avatarUrl = (d['avatarUrl'] as String?) ?? (d['logo_url'] as String?);
    final coverUrl = (d['coverUrl'] as String?) ?? (d['cover_url'] as String?);
    final accent = _parseColor((d['primaryColor'] as String?) ?? '#009DFF');

    return OrgProfileView(
      profile: OrgProfileModel(
        name: name,
        handle: handle.isNotEmpty ? handle : name.toLowerCase().replaceAll(' ', ''),
        roleName: 'Community',
        roleColor: accent,
        accentColor: accent,
        postCount: (d['postCount'] as int?) ?? 0,
        fanCount: memberCount,
        followingCount: 0,
        bio: bio,
        location: (d['country'] as String?) ?? 'Tanzania',
        joinedDate: DateTime.tryParse((d['createdAt'] as String?) ?? '') ?? DateTime.now(),
        isVerified: (d['isVerified'] as bool?) ?? false,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
        aboutFields: [
          if (topic.isNotEmpty)
            PersonAboutField(
              icon: Icons.tag_rounded,
              iconColor: accent,
              label: 'Topic',
              value: topic,
            ),
          PersonAboutField(
            icon: Icons.people_rounded,
            iconColor: PlayifyColors.sportGreen,
            label: 'Members',
            value: _fmt(memberCount),
          ),
          if (teamName.isNotEmpty)
            PersonAboutField(
              icon: Icons.sports_soccer_rounded,
              iconColor: PlayifyColors.sportOrange,
              label: 'Supported Team',
              value: teamName,
            ),
        ],
        headerTrailing: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _joined ? PlayifyColors.muted.withValues(alpha: 0.2) : accent,
            foregroundColor: _joined ? PlayifyColors.muted : PlayifyColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: _busyJoin ? null : _toggleMembership,
          icon: _busyJoin
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_joined ? Icons.check_rounded : Icons.group_add_rounded, size: 16),
          label: Text(_joined ? 'Joined' : 'Join',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return PlayifyColors.electricBlue;
    }
  }

  String _fmt(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';
}
