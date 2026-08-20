import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Profile/fan/fan_profile_view.dart';
import '../Profile/player/player_profile_view.dart';
import '../Profile/team/team_profile_view.dart';
import '../data/team_profile_lookup.dart';
import '../data/player_profile_lookup.dart';
import '../templates/role_profile_model.dart';

/// Loads profiles from Supabase only (no role_mocks).
class ProfileLoader {
  const ProfileLoader._();

  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<FanProfileModel> loadFanProfile(String handle) async {
    final key = handle.replaceAll('@', '').trim().toLowerCase();
    Map<String, dynamic>? row;
    try {
      row = await _sb.from('profiles').select().eq('handle', key).maybeSingle();
    } catch (_) {}
    try {
      row ??= await _sb.from('User').select().eq('handle', key).maybeSingle();
    } catch (_) {}

    var fanOf = 'SportSphere Fan';
    try {
      final id = row?['id']?.toString();
      if (id != null) {
        final fans =
            await _sb.from('fans').select('target_id').eq('fan_id', id);
        final tids = [
          for (final r in fans as List) (r as Map)['target_id']?.toString()
        ].whereType<String>().toList();
        if (tids.isNotEmpty) {
          final teams = await _sb
              .from('Team')
              .select('name,accountUserId')
              .inFilter('accountUserId', tids)
              .limit(1);
          if ((teams as List).isNotEmpty) {
            final n = '${(teams.first as Map)['name']}'
                .replaceAll(RegExp(r'\s+(SC|FC)$'), '');
            fanOf = '$n Fan';
          }
        }
      }
    } catch (_) {}

    final first = (row?['first_name'] as String?) ??
        (row?['name'] as String?)?.split(' ').first ??
        key;
    final last = (row?['last_name'] as String?) ??
        ((row?['name'] as String?)?.split(' ').skip(1).join(' ') ?? '');
    return FanProfileModel(
      firstName: first,
      lastName: last,
      handle: (row?['handle'] as String?) ?? key,
      fanOf: fanOf,
      fanOfAccent: const Color(0xFF009DFF),
      bio: (row?['bio'] as String?) ?? '',
      sport: 'Football',
      location: (row?['country'] as String?) ?? '',
      joinedDate: DateTime.tryParse((row?['created_at'] as String?) ?? '') ??
          DateTime.now(),
      postCount: (row?['postCount'] as int?) ?? 0,
      followerCount: (row?['followerCount'] as int?) ?? 0,
      followingCount: (row?['followingCount'] as int?) ?? 0,
      avatarAsset:
          (row?['avatar_url'] as String?) ?? (row?['avatarUrl'] as String?),
      coverAsset:
          (row?['cover_url'] as String?) ?? (row?['coverUrl'] as String?),
      isVerified: (row?['is_verified'] as bool?) == true ||
          (row?['isVerified'] as bool?) == true,
      isOwnProfile: false,
    );
  }

  static Future<PlayerProfileModel> loadPlayerProfile(String handle) async {
    return lookupPlayerProfile(handle);
  }

  static Future<TeamProfileModel> loadTeamProfile(String handle) async {
    return lookupTeamProfile(handle);
  }

  static Future<RoleProfileModel> loadRoleProfile(
    String role,
    String handle,
  ) async {
    final key = handle.replaceAll('@', '').trim().toLowerCase();
    final roleKey = role.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

    Map<String, dynamic>? user;
    try {
      user = await _sb.from('User').select().eq('handle', key).maybeSingle();
      user ??=
          await _sb.from('profiles').select().eq('handle', key).maybeSingle();
    } catch (_) {}

    // Prefer role column when handle points at a real account
    final dbRole = ((user?['role'] as String?) ?? roleKey).toLowerCase();
    final name = (user?['name'] as String?) ??
        '${user?['first_name'] ?? key} ${user?['last_name'] ?? ''}'.trim();
    final label = _prettyRole(dbRole.isNotEmpty ? dbRole : roleKey);

    final shape = _shapeFor(dbRole.isNotEmpty ? dbRole : roleKey);
    final accent = _accentFor(dbRole.isNotEmpty ? dbRole : roleKey);

    final uid = user?['id']?.toString();
    var postCount = (user?['postCount'] as int?) ?? 0;
    var followerCount = (user?['followerCount'] as int?) ?? 0;
    var followingCount = (user?['followingCount'] as int?) ?? 0;
    var fanCount = (user?['fanCount'] as int?) ?? 0;

    final posts = <ProfilePost>[];
    if (uid != null) {
      try {
        final rows = await _sb
            .from('Post')
            .select('id,content,likeCount,commentCount,shareCount,createdAt,mediaUrls')
            .eq('userId', uid)
            .order('createdAt', ascending: false)
            .limit(20);
        for (final r in rows as List) {
          final m = Map<String, dynamic>.from(r as Map);
          final media = m['mediaUrls'];
          final hasMedia = media is List && media.isNotEmpty;
          posts.add(ProfilePost(
            text: (m['content'] as String?) ?? '',
            hashtags: const [],
            timeAgo: _ageLabel(m['createdAt']?.toString()),
            likes: (m['likeCount'] as int?) ?? 0,
            comments: (m['commentCount'] as int?) ?? 0,
            shares: (m['shareCount'] as int?) ?? 0,
            hasImage: hasMedia,
            imageUrl: hasMedia ? media.first.toString() : null,
          ));
        }
        if (postCount == 0) postCount = posts.length;
      } catch (_) {}
    }

    final headerStats = <RoleStat>[
      RoleStat('$postCount', 'Posts'),
      if (shape == RoleShape.person || shape == RoleShape.org)
        RoleStat('$fanCount', 'Fans'),
      RoleStat('$followerCount', 'Followers'),
      RoleStat('$followingCount', 'Following'),
    ];

    return RoleProfileModel(
      displayName: name.isEmpty ? key : name,
      handle: (user?['handle'] as String?) ?? key,
      roleLabel: label,
      subtitle: label,
      bio: (user?['bio'] as String?) ?? '',
      location: (user?['country'] as String?) ?? (user?['location'] as String?) ?? '',
      accent: accent,
      shape: shape,
      headerStats: headerStats,
      aboutFields: [
        if ((user?['email'] as String?) != null)
          AboutField('Email', user!['email'] as String),
        AboutField('Role', label),
        if ((user?['country'] as String?) != null)
          AboutField('Country', user!['country'] as String),
      ],
      posts: posts,
      members: const [],
      membersTitle: shape == RoleShape.org ? 'Members' : 'Members',
      statsRows: const [],
      entityId: uid,
      isClaimable: uid == null,
      profileType: roleKey,
      isVerified: (user?['isVerified'] as bool?) == true ||
          (user?['is_verified'] as bool?) == true,
    );
  }

  static String _prettyRole(String role) {
    final map = {
      'support_staff': 'Support Staff',
      'commercial_partner': 'Commercial Partner',
      'media_broadcast': 'Media / Broadcast',
      'media': 'Media / Broadcast',
    };
    if (map.containsKey(role)) return map[role]!;
    if (role.isEmpty) return 'User';
    return role.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static RoleShape _shapeFor(String role) {
    const org = {
      'academy', 'league', 'competition', 'organization', 'community',
      'media_broadcast', 'media', 'team',
    };
    const commerce = {
      'business', 'sponsor', 'commercial_partner', 'venue',
    };
    if (org.contains(role)) return RoleShape.org;
    if (commerce.contains(role)) return RoleShape.commerce;
    return RoleShape.person;
  }

  static Color _accentFor(String role) {
    switch (role) {
      case 'coach':
        return const Color(0xFF00C853);
      case 'scout':
        return const Color(0xFFFF6D00);
      case 'agent':
        return const Color(0xFF7C4DFF);
      case 'journalist':
        return const Color(0xFF2979FF);
      case 'league':
      case 'competition':
        return const Color(0xFFFFD600);
      case 'sponsor':
        return const Color(0xFFFFD700);
      case 'venue':
        return const Color(0xFFE31B23);
      default:
        return const Color(0xFF009DFF);
    }
  }

  static String _ageLabel(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

