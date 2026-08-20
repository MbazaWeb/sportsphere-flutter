import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../Profile/team/team_profile_view.dart';

String normalizeTeamHandle(String raw) {
  return raw.replaceAll('@', '').trim().toLowerCase().replaceAll('-', '_');
}

Future<TeamProfileModel> lookupTeamProfile(String handle) async {
  final key = normalizeTeamHandle(handle);
  final sb = Supabase.instance.client;

  Map<String, dynamic>? team;
  Map<String, dynamic>? user;

  try {
    user = await sb.from('User').select().eq('handle', key).maybeSingle();
  } catch (_) {}

  if (user == null) {
    try {
      user = await sb.from('User').select().eq('handle', handle).maybeSingle();
    } catch (_) {}
  }

  try {
    if (user != null) {
      team = await sb
          .from('Team')
          .select()
          .eq('accountUserId', user['id'])
          .maybeSingle();
    }
    team ??= await sb
        .from('Team')
        .select()
        .eq('slug', key.replaceAll('_', '-'))
        .maybeSingle();
    team ??= await sb
        .from('Team')
        .select()
        .eq('id', 'tm-${key.replaceAll('_', '-')}')
        .maybeSingle();
    team ??= await sb.from('Team').select().eq('id', 'tm-$key').maybeSingle();
    // resolve user from team account if needed
    if (user == null && team?['accountUserId'] != null) {
      user = await sb
          .from('User')
          .select()
          .eq('id', team!['accountUserId'])
          .maybeSingle();
    }
  } catch (_) {}

  if (team == null && user == null) {
    return TeamProfileModel(
      name: handle,
      handle: key,
      sport: 'Football',
      competition: 'Ligi Kuu Bara',
      country: 'Tanzania',
      city: '',
      stadium: '',
      founded: 2000,
      coach: '',
      description: '',
      accentColor: const Color(0xFF009DFF),
      postCount: 0,
      fanCount: 0,
      followingCount: 0,
      squad: const [],
      seasonStats: const [],
      logoAsset: NbcClubBadges.defaultTeam,
    );
  }

  final name =
      (team?['name'] as String?) ?? (user?['name'] as String?) ?? handle;
  final logo = (team?['logoUrl'] as String?) ??
      (user?['avatarUrl'] as String?) ??
      NbcClubBadges.forName(name);
  final accountUserId =
      team?['accountUserId']?.toString() ?? user?['id']?.toString();
  final teamId = team?['id']?.toString();

  return TeamProfileModel(
    name: name,
    handle: (user?['handle'] as String?) ?? key,
    sport: (team?['sport_slug'] as String?)?.isNotEmpty == true
        ? (team!['sport_slug'] as String)
        : 'Football',
    competition: 'Ligi Kuu Bara',
    country: (team?['country'] as String?) ?? 'Tanzania',
    city: (team?['city'] as String?) ?? '',
    stadium: (team?['venue'] as String?) ?? '',
    founded: (team?['foundedYear'] as int?) ?? 2000,
    coach: '',
    description: (team?['description'] as String?) ?? '',
    accentColor: const Color(0xFFE31B23),
    postCount: (user?['postCount'] as int?) ?? 0,
    fanCount: (user?['fanCount'] as int?) ?? 0,
    followingCount: (user?['followingCount'] as int?) ?? 0,
    squad: const [],
    seasonStats: const [],
    logoAsset: logo,
    entityId: teamId,
    accountUserId: accountUserId,
    isClaimable: accountUserId == null,
    isVerified: true,
  );
}
