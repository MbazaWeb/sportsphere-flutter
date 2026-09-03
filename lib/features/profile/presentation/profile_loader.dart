import '../../../core/admin/app_admin.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/branding.dart';
import 'package:flutter/material.dart';
import '../../../core/data/vps_repository.dart';

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


  /// Live social counts for any profile id (all roles) — via VPS API.
  static Future<({int posts, int followers, int following})> _liveCounts(
      String profileId) async {
    if (profileId.isEmpty) return (posts: 0, followers: 0, following: 0);
    try {
      final profile = await const VpsRepository().getProfile(profileId);
      if (profile == null) {
        return (posts: 0, followers: 0, following: 0);
      }
      return (
        posts:     (profile['postCount']      as int?) ?? (profile['post_count']      as int?) ?? 0,
        followers: (profile['followerCount']  as int?) ?? (profile['follower_count']  as int?) ?? 0,
        following: (profile['followingCount'] as int?) ?? (profile['following_count'] as int?) ?? 0,
      );
    } catch (_) {
      return (posts: 0, followers: 0, following: 0);
    }
  }

  static Future<FanProfileModel> loadFanProfile(String handle) async {
    final key = handle.replaceAll('@', '').trim().toLowerCase();
    Map<String, dynamic>? row;
    try {
      row = await const VpsRepository().getProfile(key);
      // #FIX-NULLABLE — row is Map<String, dynamic>?; guard before isEmpty.
      if (row != null && row.isEmpty) row = null;
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
    final authId = const AuthRepository().currentSession?.user?.id ?? '';

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
            (row?['avatar_url'] as String?) ??
            (row?['avatarUrl'] as String?) ??
            'assets/images/Playify_logo.png', // fallback for official account
        coverAsset:
            (row?['cover_url'] as String?) ?? (row?['coverUrl'] as String?),
        isVerified: true,
        isOwnProfile: authId.isNotEmpty &&
            (profileId == authId || AppAdmin.isSessionAdmin),
        isAdmin: isAdmin,
        role: role.isEmpty ? 'admin' : role,
      );
    }

    var fanOf = '';  // empty — user must pick a team, no default
    try {
      if (profileId.isNotEmpty) {
        final fansRes = await const VpsRepository().get<Map<String, dynamic>>(
            '/v1/social/fans/$profileId/teams');
        final teamNames = (fansRes.data?['teams'] as List? ?? []).cast<String>();
        if (teamNames.isNotEmpty) {
          final n = teamNames.first.replaceAll(RegExp(r'\s+(SC|FC)\$'), '');
          fanOf = '$n Fan';
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
