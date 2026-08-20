import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Profile/player/player_profile_view.dart';

String normalizePlayerHandle(String raw) {
  return raw.replaceAll('@', '').trim().toLowerCase().replaceAll(' ', '_');
}

Future<PlayerProfileModel> lookupPlayerProfile(String handle) async {
  final key = normalizePlayerHandle(handle);
  final slugDash = key.replaceAll('_', '-');
  final sb = Supabase.instance.client;

  Map<String, dynamic>? user;
  Map<String, dynamic>? player;

  // 1) Auth / social user by handle
  try {
    user = await sb.from('User').select().eq('handle', key).maybeSingle();
  } catch (_) {}
  try {
    user ??= await sb.from('User').select().eq('handle', handle).maybeSingle();
  } catch (_) {}
  try {
    user ??= await sb.from('profiles').select().eq('handle', key).maybeSingle();
  } catch (_) {}

  // 2) Player entity by account, slug, id, or name
  try {
    if (user != null) {
      player = await sb
          .from('Player')
          .select()
          .eq('accountUserId', user['id'])
          .maybeSingle();
    }
  } catch (_) {}

  try {
    player ??= await sb.from('Player').select().eq('slug', slugDash).maybeSingle();
  } catch (_) {}
  try {
    player ??= await sb.from('Player').select().eq('slug', key).maybeSingle();
  } catch (_) {}
  try {
    player ??= await sb.from('Player').select().eq('id', 'pl-$key').maybeSingle();
  } catch (_) {}
  try {
    player ??= await sb.from('Player').select().eq('id', 'pl-$slugDash').maybeSingle();
  } catch (_) {}
  // name match (e.g. clatouschama → Clatous Chama)
  if (player == null) {
    try {
      final guess = key.replaceAll('_', ' ').replaceAll('-', ' ');
      final rows = await sb
          .from('Player')
          .select()
          .ilike('name', '%$guess%')
          .limit(1);
      if ((rows as List).isNotEmpty) {
        player = Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
  }

  // If we found player first, load linked user
  if (user == null && player?['accountUserId'] != null) {
    try {
      user = await sb
          .from('User')
          .select()
          .eq('id', player!['accountUserId'])
          .maybeSingle();
    } catch (_) {}
  }

  // Resolve club + league names
  String club = '';
  String league = '';
  final teamId = player?['teamId']?.toString();
  final leagueId = player?['leagueId']?.toString();
  if (teamId != null && teamId.isNotEmpty) {
    try {
      final team =
          await sb.from('Team').select('name').eq('id', teamId).maybeSingle();
      club = (team?['name'] as String?) ?? '';
    } catch (_) {}
  }
  if (leagueId != null && leagueId.isNotEmpty) {
    try {
      final lg =
          await sb.from('League').select('name').eq('id', leagueId).maybeSingle();
      league = (lg?['name'] as String?) ?? '';
    } catch (_) {}
  }

  final fullName = (player?['name'] as String?) ??
      (user?['name'] as String?) ??
      '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim();
  final display = fullName.isNotEmpty ? fullName : key;
  final parts = display.split(RegExp(r'\s+'));
  final first = (player?['firstName'] as String?) ??
      (user?['first_name'] as String?) ??
      (parts.isNotEmpty ? parts.first : key);
  final last = (player?['lastName'] as String?) ??
      (user?['last_name'] as String?) ??
      (parts.length > 1 ? parts.sublist(1).join(' ') : '');

  final handleOut = (user?['handle'] as String?) ??
      (player?['slug'] as String?)?.replaceAll('-', '_') ??
      key;

  final dob = DateTime.tryParse(
        (player?['dateOfBirth'] as String?) ??
            (player?['dob'] as String?) ??
            '',
      ) ??
      DateTime(1995);

  final accountUserId =
      player?['accountUserId']?.toString() ?? user?['id']?.toString();

  // Season stats placeholder until match events exist
  final season = (player?['metadata'] is Map &&
          (player!['metadata'] as Map)['season'] != null)
      ? '${(player['metadata'] as Map)['season']}'
      : '2026/2027';

  final seasonStats = <PlayerSeasonStats>[
    PlayerSeasonStats(
      season: season,
      competition: league.isNotEmpty ? league : 'League',
      appearances: (player?['appearances'] as int?) ?? 0,
      starts: (player?['starts'] as int?) ?? 0,
      goals: (player?['goals'] as int?) ?? 0,
      assists: (player?['assists'] as int?) ?? 0,
      minutes: (player?['minutes'] as int?) ?? 0,
      yellowCards: (player?['yellowCards'] as int?) ?? 0,
      redCards: (player?['redCards'] as int?) ?? 0,
    ),
  ];

  // Career: at least current club if known
  final career = <PlayerCareerEntry>[];
  if (club.isNotEmpty) {
    career.add(PlayerCareerEntry(
      clubName: club,
      country: (player?['nationality'] as String?) ?? 'Tanzania',
      startYear: DateTime.now().year,
      leagueName: league.isNotEmpty ? league : null,
      appearances: (player?['appearances'] as int?) ?? 0,
      goals: (player?['goals'] as int?) ?? 0,
    ));
  }

  return PlayerProfileModel(
    firstName: first,
    lastName: last,
    handle: handleOut,
    fullName: display,
    position: (player?['position'] as String?) ?? 'Player',
    nationality: (player?['nationality'] as String?) ??
        (user?['country'] as String?) ??
        '',
    dob: dob,
    heightCm: (player?['heightCm'] as int?) ?? 0,
    preferredFoot: (player?['preferredFoot'] as String?) ??
        (player?['metadata'] is Map
            ? '${(player!['metadata'] as Map)['preferredFoot'] ?? '—'}'
            : '—'),
    currentClub: club,
    currentLeague: league,
    squadNumber: (player?['shirtNumber'] as int?) ??
        (player?['squadNumber'] as int?) ??
        0,
    contractStatus: (player?['contractStatus'] as String?) ??
        ((player?['isActive'] as bool?) == false ? 'Inactive' : 'Active'),
    accentColor: const Color(0xFF009DFF),
    postCount: (user?['postCount'] as int?) ?? 0,
    fanCount: (user?['fanCount'] as int?) ?? 0,
    followerCount: (user?['followerCount'] as int?) ?? 0,
    followingCount: (user?['followingCount'] as int?) ?? 0,
    career: career,
    seasonStats: seasonStats,
    allTimeGoals: (player?['goals'] as int?) ?? 0,
    allTimeAssists: (player?['assists'] as int?) ?? 0,
    allTimeAppearances: (player?['appearances'] as int?) ?? 0,
    allTimeMinutes: (player?['minutes'] as int?) ?? 0,
    allTimeYellowCards: (player?['yellowCards'] as int?) ?? 0,
    allTimeRedCards: (player?['redCards'] as int?) ?? 0,
    bio: (user?['bio'] as String?) ?? '',
    location: (user?['country'] as String?) ?? '',
    avatarAsset: (player?['photoUrl'] as String?) ??
        (user?['avatarUrl'] as String?) ??
        (user?['avatar_url'] as String?),
    coverAsset: (user?['coverUrl'] as String?) ?? (user?['cover_url'] as String?),
    isVerified: (player?['verified'] as bool?) == true ||
        (user?['isVerified'] as bool?) == true ||
        (user?['is_verified'] as bool?) == true,
    isClaimable: accountUserId == null && player != null,
    entityId: player?['id']?.toString(),
    accountUserId: accountUserId,
  );
}
