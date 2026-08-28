import '../../../core/data/vps_supabase_compat.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/team_color_picker.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../Profile/team/team_profile_view.dart';

String normalizeTeamHandle(String raw) {
  return raw.replaceAll('@', '').trim().toLowerCase().replaceAll('-', '_');
}

Future<TeamProfileModel> lookupTeamProfile(String handle) async {
  final key = normalizeTeamHandle(handle);
  final sb = VpsSupabaseCompat.client;

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
    if (user == null && team?['accountUserId'] != null) {
      user = await sb
          .from('User')
          .select()
          .eq('id', team!['accountUserId'])
          .maybeSingle();
    }
  } catch (_) {}

  final name =
      (team?['name'] as String?) ?? (user?['name'] as String?) ?? handle;
  final logo = (team?['logoUrl'] as String?) ??
      (user?['avatarUrl'] as String?) ??
      NbcClubBadges.forName(name);
  final teamId = team?['id']?.toString();

  final squad = await _loadSquad(sb, teamId: teamId, teamName: name);
  final seasonStats = await _loadSeasonStats(sb, teamName: name);

  final coachesOnly = squad.where((m) => m.role == SquadRole.coach).toList();
  final coachName = coachesOnly.isEmpty ? null : coachesOnly.first.name;

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
    coach: coachName ?? '',
    description: (team?['description'] as String?) ?? '',
    accentColor: parseHexColor(team?['primaryColor']?.toString()) ??
        parseHexColor((team?['metadata'] is Map ? (team!['metadata'] as Map)['primaryColor'] : null)?.toString()) ??
        const Color(0xFFE31B23),
    postCount: (user?['postCount'] as int?) ??
        (user?['post_count'] as int?) ??
        0,
    fanCount: (user?['fanCount'] as int?) ??
        (user?['fan_count'] as int?) ??
        0,
    followingCount: (user?['followingCount'] as int?) ??
        (user?['following_count'] as int?) ??
        0,
    squad: squad,
    seasonStats: seasonStats,
    logoAsset: logo,
    isVerified: true,
  );
}

Future<List<SquadMember>> _loadSquad(
  dynamic sb, {
  String? teamId,
  required String teamName,
}) async {
  final members = <SquadMember>[];
  try {
    dynamic playerQ = sb.from('Player').select();
    if (teamId != null && teamId.isNotEmpty) {
      playerQ = playerQ.eq('teamId', teamId);
    } else {
      return members;
    }
    final players = await playerQ.order('shirtNumber').limit(80);
    for (final r in players as List) {
      final m = Map<String, dynamic>.from(r as Map);
      final nm = (m['name'] as String?) ?? 'Player';
      final slug = (m['slug'] as String?) ??
          nm.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      members.add(SquadMember(
        name: nm,
        handle: slug,
        role: SquadRole.player,
        subrole: (m['position'] as String?) ?? 'Player',
        squadNumber: m['shirtNumber'] as int?,
        nationality: m['nationality'] as String?,
        avatarAsset: m['photoUrl'] as String?,
        profileRoute: '/player/$slug',
      ));
    }
  } catch (_) {}

  try {
    if (teamId == null || teamId.isEmpty) return members;
    final coaches =
        await sb.from('Coach').select().eq('teamId', teamId).limit(20);
    for (final r in coaches as List) {
      final m = Map<String, dynamic>.from(r as Map);
      final nm = (m['name'] as String?) ?? 'Coach';
      final slug = (m['slug'] as String?) ??
          nm.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final roleLabel = (m['role'] as String?) ?? 'coach';
      members.add(SquadMember(
        name: nm,
        handle: slug,
        role: SquadRole.coach,
        subrole: roleLabel.replaceAll('_', ' '),
        nationality: m['nationality'] as String?,
        avatarAsset: m['photoUrl'] as String?,
        profileRoute: '/role/coach/$slug',
      ));
    }
  } catch (_) {}
  return members;
}

Future<List<TeamSeasonStats>> _loadSeasonStats(
  dynamic sb, {
  required String teamName,
}) async {
  try {
    // Filter at SQL level so we only download matches this team actually
    // played in, instead of the entire Match table (H7). .limit(200) is a
    // defensive cap — a single team plays <50 matches/season, so 200 is
    // more than enough headroom for multi-season lookups.
    //
    // NOTE: this filter narrows the league-table aggregate (pts/gd/gfMap)
    // below to only this team's opponents, so `leaguePosition` becomes a
    // rank-among-opponents rather than a true league rank. That is an
    // acceptable tradeoff for not pulling the whole table on every profile
    // view; the team's own played/w/d/l/gf/ga/cs numbers remain exact.
    final rows = await sb
        .from('Match')
        .select('homeTeam,awayTeam,homeScore,awayScore,status,season,league')
        .or('homeTeam.eq.$teamName,awayTeam.eq.$teamName')
        .limit(200);
    var played = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0, cs = 0;
    var season = '2026/2027';
    var competition = 'Ligi Kuu Bara';

    // league table for position
    final pts = <String, int>{};
    final gd = <String, int>{};
    final gfMap = <String, int>{};

    void ensure(String t) {
      pts.putIfAbsent(t, () => 0);
      gd.putIfAbsent(t, () => 0);
      gfMap.putIfAbsent(t, () => 0);
    }

    for (final raw in rows as List) {
      final r = Map<String, dynamic>.from(raw as Map);
      final status = ((r['status'] as String?) ?? '').toLowerCase();
      final hs = r['homeScore'];
      final as_ = r['awayScore'];
      if (hs == null || as_ == null) continue;
      if (!(status == 'finished' ||
          status == 'ft' ||
          status == 'completed' ||
          status == 'full_time')) {
        continue;
      }
      final home = (r['homeTeam'] as String?) ?? '';
      final away = (r['awayTeam'] as String?) ?? '';
      final h = (hs as num).toInt();
      final a = (as_ as num).toInt();
      if (r['season'] != null) season = r['season'].toString();
      if (r['league'] != null) competition = r['league'].toString();

      ensure(home);
      ensure(away);
      gfMap[home] = gfMap[home]! + h;
      gfMap[away] = gfMap[away]! + a;
      gd[home] = gd[home]! + (h - a);
      gd[away] = gd[away]! + (a - h);
      if (h > a) {
        pts[home] = pts[home]! + 3;
      } else if (h < a) {
        pts[away] = pts[away]! + 3;
      } else {
        pts[home] = pts[home]! + 1;
        pts[away] = pts[away]! + 1;
      }

      final isHome = _sameTeam(home, teamName);
      final isAway = _sameTeam(away, teamName);
      if (!isHome && !isAway) continue;

      played++;
      if (isHome) {
        gf += h;
        ga += a;
        if (a == 0) cs++;
        if (h > a) {
          w++;
        } else if (h < a) {
          l++;
        } else {
          d++;
        }
      } else {
        gf += a;
        ga += h;
        if (h == 0) cs++;
        if (a > h) {
          w++;
        } else if (a < h) {
          l++;
        } else {
          d++;
        }
      }
    }

    // rank
    final ranked = pts.keys.toList()
      ..sort((a, b) {
        final p = pts[b]!.compareTo(pts[a]!);
        if (p != 0) return p;
        final g = gd[b]!.compareTo(gd[a]!);
        if (g != 0) return g;
        return gfMap[b]!.compareTo(gfMap[a]!);
      });
    var position = 0;
    for (var i = 0; i < ranked.length; i++) {
      if (_sameTeam(ranked[i], teamName)) {
        position = i + 1;
        break;
      }
    }

    if (played == 0 && position == 0) {
      return [
        TeamSeasonStats(
          season: season,
          competition: competition,
          matches: 0,
          wins: 0,
          draws: 0,
          losses: 0,
          goalsFor: 0,
          goalsAgainst: 0,
          cleanSheets: 0,
          leaguePosition: 0,
        ),
      ];
    }

    return [
      TeamSeasonStats(
        season: season,
        competition: competition,
        matches: played,
        wins: w,
        draws: d,
        losses: l,
        goalsFor: gf,
        goalsAgainst: ga,
        cleanSheets: cs,
        leaguePosition: position,
      ),
    ];
  } catch (_) {
    return [
      const TeamSeasonStats(
        season: '2026/2027',
        competition: 'Ligi Kuu Bara',
        matches: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        cleanSheets: 0,
        leaguePosition: 0,
      ),
    ];
  }
}

bool _sameTeam(String a, String b) {
  final x = a.trim().toLowerCase();
  final y = b.trim().toLowerCase();
  if (x == y) return true;
  if (x.contains(y) || y.contains(x)) return true;
  final xs = x.replaceAll(RegExp(r'\s+(sc|fc)$'), '');
  final ys = y.replaceAll(RegExp(r'\s+(sc|fc)$'), '');
  return xs == ys;
}
