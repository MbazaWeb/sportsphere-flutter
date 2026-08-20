import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Profile/fan/fan_profile_view.dart';
import '../Profile/player/player_profile_view.dart';
import '../Profile/team/team_profile_view.dart';
import '../data/team_profile_lookup.dart';
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
    final key = handle.replaceAll('@', '').trim().toLowerCase();
    Map<String, dynamic>? user;
    Map<String, dynamic>? player;
    try {
      user = await _sb.from('User').select().eq('handle', key).maybeSingle();
      user ??=
          await _sb.from('profiles').select().eq('handle', key).maybeSingle();
    } catch (_) {}
    try {
      if (user != null) {
        player = await _sb
            .from('Player')
            .select()
            .eq('accountUserId', user['id'])
            .maybeSingle();
      }
    } catch (_) {}

    final name = (user?['name'] as String?) ??
        '${user?['first_name'] ?? key} ${user?['last_name'] ?? ''}'.trim();
    final parts = name.split(' ');
    return PlayerProfileModel(
      firstName: parts.isNotEmpty ? parts.first : key,
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      handle: (user?['handle'] as String?) ?? key,
      fullName: name,
      position: (player?['position'] as String?) ?? 'Player',
      nationality: (player?['nationality'] as String?) ??
          (user?['country'] as String?) ??
          'Tanzania',
      dob: DateTime.tryParse((player?['dob'] as String?) ?? '') ??
          DateTime(1995),
      heightCm: (player?['heightCm'] as int?) ?? 175,
      preferredFoot: (player?['preferredFoot'] as String?) ?? 'Right',
      currentClub: (player?['teamName'] as String?) ?? '',
      currentLeague: (player?['league'] as String?) ?? '',
      squadNumber: (player?['squadNumber'] as int?) ?? 0,
      contractStatus: (player?['contractStatus'] as String?) ?? 'Active',
      accentColor: const Color(0xFF009DFF),
      postCount: (user?['postCount'] as int?) ?? 0,
      fanCount: (user?['fanCount'] as int?) ?? 0,
      followerCount: (user?['followerCount'] as int?) ?? 0,
      followingCount: (user?['followingCount'] as int?) ?? 0,
      career: const [],
      seasonStats: const [],
      allTimeGoals: (player?['goals'] as int?) ?? 0,
      allTimeAssists: (player?['assists'] as int?) ?? 0,
      allTimeAppearances: (player?['appearances'] as int?) ?? 0,
      allTimeMinutes: 0,
      allTimeYellowCards: 0,
      allTimeRedCards: 0,
      isClaimable: player?['accountUserId'] == null,
      entityId: player?['id']?.toString(),
    );
  }

  static Future<TeamProfileModel> loadTeamProfile(String handle) async {
    return lookupTeamProfile(handle);
  }

  static Future<RoleProfileModel> loadRoleProfile(
    String role,
    String handle,
  ) async {
    final key = handle.replaceAll('@', '').trim().toLowerCase();
    Map<String, dynamic>? user;
    try {
      user = await _sb.from('User').select().eq('handle', key).maybeSingle();
      user ??=
          await _sb.from('profiles').select().eq('handle', key).maybeSingle();
    } catch (_) {}
    final name = (user?['name'] as String?) ??
        '${user?['first_name'] ?? key} ${user?['last_name'] ?? ''}'.trim();
    final label =
        role.isEmpty ? 'User' : '${role[0].toUpperCase()}${role.substring(1)}';
    return RoleProfileModel(
      displayName: name,
      handle: (user?['handle'] as String?) ?? key,
      roleLabel: label,
      subtitle: label,
      bio: (user?['bio'] as String?) ?? '',
      location: (user?['country'] as String?) ?? '',
      accent: const Color(0xFF009DFF),
      shape: RoleShape.person,
      headerStats: [
        RoleStat('${user?['postCount'] ?? 0}', 'Posts'),
        RoleStat('${user?['followerCount'] ?? 0}', 'Followers'),
        RoleStat('${user?['followingCount'] ?? 0}', 'Following'),
      ],
      aboutFields: const [],
      posts: const [],
      members: const [],
      membersTitle: 'Members',
      statsRows: const [],
      entityId: user?['id']?.toString(),
      isClaimable: false,
      profileType: role.toLowerCase(),
    );
  }
}

