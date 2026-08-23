import '../../../core/admin/app_admin.dart';
import '../../../core/branding.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Profile/fan/fan_profile_view.dart';
import '../Profile/player/player_profile_view.dart';
import '../Profile/team/team_profile_view.dart';
import '../data/team_profile_lookup.dart';
import '../data/player_profile_lookup.dart';
import '../data/role_profile_lookup.dart';
import '../templates/role_profile_model.dart';

/// Loads profiles from Supabase only (no role_mocks).
class ProfileLoader {
  const ProfileLoader._();

  static SupabaseClient get _sb => Supabase.instance.client;

  /// Live social counts for any profile id (all roles).
  static Future<({int posts, int followers, int following})> _liveCounts(
      String profileId) async {
    if (profileId.isEmpty) {
      return (posts: 0, followers: 0, following: 0);
    }

    Future<int> rpcOr(String name, Future<int> Function() fb) async {
      try {
        final n = await _sb.rpc(name, params: {'p_id': profileId});
        if (n is int) return n;
        if (n is num) return n.toInt();
      } catch (_) {}
      return fb();
    }

    final posts = await rpcOr('count_posts_for_user', () async {
      try {
        final rows =
            await _sb.from('Post').select('id').eq('userId', profileId);
        return (rows as List).length;
      } catch (_) {
        return 0;
      }
    });

    final followers = await rpcOr('count_followers', () async {
      try {
        final rows = await _sb
            .from('Follow')
            .select('followerId')
            .eq('followingId', profileId);
        return (rows as List).length;
      } catch (_) {
        return 0;
      }
    });

    final following = await rpcOr('count_following', () async {
      try {
        final rows = await _sb
            .from('Follow')
            .select('followingId')
            .eq('followerId', profileId);
        return (rows as List).length;
      } catch (_) {
        return 0;
      }
    });

    return (posts: posts, followers: followers, following: following);
  }

  static Future<FanProfileModel> loadFanProfile(String handle) async {
    final key = handle.replaceAll('@', '').trim().toLowerCase();
    Map<String, dynamic>? row;
    try {
      row = await _sb.from('profiles').select().eq('handle', key).maybeSingle();
    } catch (_) {}
    try {
      row ??= await _sb.from('User').select().eq('handle', key).maybeSingle();
    } catch (_) {}

    final role = (row?['role'] as String? ?? '').toLowerCase();
    // #4.5 — Use kOfficialLegacyHandles so the list is maintained in a single
    // place (lib/core/branding.dart) and covers every Playify alias including
    // 'playifyofficial' (no underscore).
    final isOfficial = kOfficialLegacyHandles.contains(key) ||
        role == 'admin' ||
        role == 'official';

    // #3.3 — Surface the admin flag and raw role on FanProfileModel so
    // consumers can role-gate UI (e.g. hide the Become PRO button) without
    // re-querying the DB.
    final isAdminRole = role == 'admin' ||
        role == 'official' ||
        role == 'organization' ||
        role == 'moderator';
    final isAdmin = isAdminRole || AppAdmin.isSessionAdmin;

    final profileId = row?['id']?.toString() ?? '';
    final authId = _sb.auth.currentUser?.id ?? '';

    // Live counts for every role (not only admin)
    var counts = await _liveCounts(profileId);
    if (authId.isNotEmpty && authId != profileId) {
      final extra = await _liveCounts(authId);
      if (extra.posts > counts.posts) {
        counts = (
          posts: extra.posts,
          followers: counts.followers > extra.followers
              ? counts.followers
              : extra.followers,
          following: counts.following > extra.following
              ? counts.following
              : extra.following,
        );
      }
    }

    final postCount = counts.posts > 0
        ? counts.posts
        : ((row?['postCount'] as int?) ?? (row?['post_count'] as int?) ?? 0);
    final followerCount = counts.followers > 0
        ? counts.followers
        : ((row?['followerCount'] as int?) ??
            (row?['follower_count'] as int?) ??
            0);
    final followingCount = counts.following > 0
        ? counts.following
        : ((row?['followingCount'] as int?) ??
            (row?['following_count'] as int?) ??
            0);

    if (isOfficial) {
      return FanProfileModel(
        firstName: 'Playify',
        lastName: '',
        handle: (row?['handle'] as String?) ?? key,
        fanOf: '',
        fanOfAccent: const Color(0xFFFFD700),
        bio: (row?['bio'] as String?) ??
            'Official Playify account. Platform news, live scores and verified content.',
        sport: '',
        location: '',
        joinedDate: DateTime.tryParse((row?['created_at'] as String?) ??
                (row?['createdAt'] as String?) ??
                '') ??
            DateTime(2024, 1, 1),
        postCount: postCount,
        followerCount: followerCount,
        followingCount: followingCount,
        avatarAsset:
            (row?['avatar_url'] as String?) ?? (row?['avatarUrl'] as String?),
        coverAsset:
            (row?['cover_url'] as String?) ?? (row?['coverUrl'] as String?),
        isVerified: true,
        isOwnProfile: authId.isNotEmpty &&
            (profileId == authId || AppAdmin.isSessionAdmin),
        isAdmin: isAdmin,
        role: role.isEmpty ? 'admin' : role,
      );
    }

    var fanOf = 'Playify Fan';
    try {
      if (profileId.isNotEmpty) {
        final fans =
            await _sb.from('fans').select('target_id').eq('fan_id', profileId);
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
      joinedDate: DateTime.tryParse((row?['created_at'] as String?) ??
              (row?['createdAt'] as String?) ??
              '') ??
          DateTime.now(),
      postCount: postCount,
      followerCount: followerCount,
      followingCount: followingCount,
      avatarAsset:
          (row?['avatar_url'] as String?) ?? (row?['avatarUrl'] as String?),
      coverAsset:
          (row?['cover_url'] as String?) ?? (row?['coverUrl'] as String?),
      isVerified: (row?['is_verified'] as bool?) == true ||
          (row?['isVerified'] as bool?) == true,
      isOwnProfile: authId.isNotEmpty && profileId == authId,
      isAdmin: isAdmin,
      role: role.isEmpty ? 'fan' : role,
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
    return lookupRoleProfile(role, handle);
  }
}
