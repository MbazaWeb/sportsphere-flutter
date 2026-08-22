import '../../../core/admin/app_admin.dart';
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

  static Future<int> _countPostsForIds(Iterable<String> ids) async {
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return 0;
    var total = 0;
    for (final id in unique) {
      try {
        final n = await _sb.rpc('count_posts_for_user', params: {'p_id': id});
        if (n is int && n > total) total = n;
        if (n is num && n.toInt() > total) total = n.toInt();
      } catch (_) {}
      for (final col in ['userId', 'authorId', 'user_id', 'author_id']) {
        try {
          final rows = await _sb.from('Post').select('id').eq(col, id);
          final c = (rows as List).length;
          if (c > total) total = c;
        } catch (_) {}
      }
    }
    return total;
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
    final isOfficial = key == 'sportsphere' ||
        key == 'sportsphere_official' ||
        key == 'sportsphere_app' ||
        key == 'playify' ||
        key == 'playify_official' ||
        key == 'playify_app' ||
        role == 'admin' ||
        role == 'official';

    // Admin / Official special treatment
    if (isOfficial) {
      // Fetch live counts from real tables
      final profileId = row?['id']?.toString() ?? '';
      int postCount = 0, followerCount = 0, followingCount = 0;
      try {
        final counts = await Future.wait([
          _countPostsForIds([profileId, _sb.auth.currentUser?.id ?? '']).then((n) => n),
          _sb.from('Follow').select('id').eq('"followingId"', profileId).then((r) => (r as List).length),
          _sb.from('Follow').select('id').eq('"followerId"', profileId).then((r) => (r as List).length),
        ]);
        postCount = counts[0]; followerCount = counts[1]; followingCount = counts[2];
      } catch (_) {}

      final currentUid = _sb.auth.currentUser?.id?.toString() ?? '';
      return FanProfileModel(
        firstName: 'SportSphere',
        lastName: '',
        handle: (row?['handle'] as String?) ?? key,
        fanOf: '',
        fanOfAccent: const Color(0xFFFFD700),
        bio: (row?['bio'] as String?) ??
            'Official SportSphere account. Platform news, live scores and verified content.',
        sport: '',      // no sport shown for official/admin
        location: '',   // no country shown
        joinedDate: DateTime.tryParse((row?['created_at'] as String?) ?? '') ??
            DateTime(2024, 1, 1),
        postCount: postCount,
        followerCount: followerCount,
        followingCount: followingCount,
        avatarAsset:
            (row?['avatar_url'] as String?) ?? (row?['avatarUrl'] as String?),
        coverAsset:
            (row?['cover_url'] as String?) ?? (row?['coverUrl'] as String?),
        isVerified: true,
        isOwnProfile: currentUid.isNotEmpty &&
            (profileId == currentUid || AppAdmin.isSessionAdmin),
      );
    }

    var fanOf = 'Playify Fan';
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
      isOwnProfile: _sb.auth.currentUser?.id != null &&
          row?['id']?.toString() == _sb.auth.currentUser?.id,
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
