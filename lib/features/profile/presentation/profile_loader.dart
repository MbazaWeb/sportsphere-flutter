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
        role == 'admin' ||
        role == 'official';

    // Admin / Official special treatment
    if (isOfficial) {
      return FanProfileModel(
        firstName: 'SportSphere',
        lastName: '',
        handle: (row?['handle'] as String?) ?? key,
        fanOf: '', // no "Fan of" section
        fanOfAccent: const Color(0xFFFFD700),
        bio: (row?['bio'] as String?) ??
            'Official SportSphere account. Platform news, live scores and verified content.',
        sport: 'All Sports',
        location: '', // no country shown
        joinedDate: DateTime.tryParse((row?['created_at'] as String?) ?? '') ??
            DateTime(2024, 1, 1),
        postCount: (row?['postCount'] as int?) ?? 0,
        followerCount: (row?['followerCount'] as int?) ?? 0,
        followingCount: (row?['followingCount'] as int?) ?? 0,
        avatarAsset:
            (row?['avatar_url'] as String?) ?? (row?['avatarUrl'] as String?),
        coverAsset:
            (row?['cover_url'] as String?) ?? (row?['coverUrl'] as String?),
        isVerified: true, // always gold tick
        isOwnProfile: _sb.auth.currentUser?.id != null &&
            row?['id']?.toString() == _sb.auth.currentUser?.id,
      );
    }

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
