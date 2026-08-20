import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../domain/models/match_model.dart';
import '../domain/models/standing_model.dart';

/// Live scores / standings from Supabase only (no hardcoded fixtures).
class ScoresRepository {
  const ScoresRepository();

  SupabaseClient get _sb => Supabase.instance.client;

  Future<List<MatchModel>> getLive() async {
    final rows = await _sb
        .from('Match')
        .select()
        .or('status.eq.live,status.eq.in_play,status.eq.ht')
        .order('kickoffAt');
    final list = _mapRows(rows as List);
    if (list.isNotEmpty) return list;
    final now = DateTime.now().toUtc();
    final all = await _fetchAll();
    return all.where((m) {
      final end = m.startTime.add(const Duration(minutes: 110));
      return !now.isBefore(m.startTime) && now.isBefore(end);
    }).toList();
  }

  Future<List<MatchModel>> getToday() async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _sb
        .from('Match')
        .select()
        .gte('kickoffAt', start.toIso8601String())
        .lt('kickoffAt', end.toIso8601String())
        .order('kickoffAt');
    return _mapRows(rows as List);
  }

  Future<List<MatchModel>> getUpcoming({DateTime? day}) async {
    final now = DateTime.now().toUtc();
    final rows = await _sb
        .from('Match')
        .select()
        .gte('kickoffAt', now.toIso8601String())
        .order('kickoffAt');
    var list = _mapRows(rows as List);
    if (day != null) {
      list = list
          .where((m) =>
              m.startTime.year == day.year &&
              m.startTime.month == day.month &&
              m.startTime.day == day.day)
          .toList();
    }
    return list;
  }

  Future<List<MatchModel>> getResults({DateTime? day}) async {
    final rows = await _sb
        .from('Match')
        .select()
        .or('status.eq.finished,status.eq.ft,status.eq.completed,status.eq.FT')
        .order('kickoffAt', ascending: false);
    var list = _mapRows(rows as List);
    if (list.isEmpty) {
      final now = DateTime.now().toUtc();
      final all = await _fetchAll();
      list = all
          .where((m) => m.startTime.add(const Duration(minutes: 110)).isBefore(now))
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
    }
    if (day != null) {
      list = list
          .where((m) =>
              m.startTime.year == day.year &&
              m.startTime.month == day.month &&
              m.startTime.day == day.day)
          .toList();
    }
    return list;
  }

  Future<List<String>> listLeagues({String? sportSlug}) async {
    final rows = await _sb
        .from('League')
        .select('name,sport_slug,isActive')
        .eq('isActive', true)
        .order('name');
    final names = <String>[];
    for (final r in rows as List) {
      final m = Map<String, dynamic>.from(r as Map);
      if (sportSlug != null && sportSlug.isNotEmpty) {
        final slug = (m['sport_slug'] as String?) ?? 'football';
        if (slug != sportSlug) continue;
      }
      final name = m['name'] as String?;
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names;
  }

  Future<List<Map<String, dynamic>>> listTeams() async {
    final rows = await _sb
        .from('Team')
        .select('id,name,logoUrl,accountUserId,sport_slug,city,country')
        .eq('isActive', true)
        .order('name');
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }

  /// Standings from admin-finished matches only (homeScore/awayScore set).
  Future<List<StandingRow>> getStandings({required String league}) async {
    final rows = await _sb.from('Match').select(
        'homeTeam,awayTeam,homeScore,awayScore,status,homeBadge,awayBadge,league');

    final stats = <String, _Acc>{};
    final logos = <String, String>{};

    for (final raw in rows as List) {
      final r = Map<String, dynamic>.from(raw as Map);
      final leagueName = (r['league'] as String?) ?? '';
      if (league.isNotEmpty &&
          !leagueName.toLowerCase().contains(league.toLowerCase()) &&
          !league.toLowerCase().contains(leagueName.toLowerCase())) {
        // Allow NBC Premier League ↔ Ligi Kuu Bara alias
        final aliases = {
          'nbc premier league': 'ligi kuu bara',
          'ligi kuu bara': 'nbc premier league',
        };
        final a = league.toLowerCase();
        final b = leagueName.toLowerCase();
        final ok = aliases[a] == b || aliases[b] == a;
        if (!ok) continue;
      }
      final status = ((r['status'] as String?) ?? '').toLowerCase();
      final hs = r['homeScore'];
      final ascore = r['awayScore'];
      if (hs == null || ascore == null) continue;
      if (!(status == 'finished' ||
          status == 'ft' ||
          status == 'completed' ||
          status == 'full_time')) {
        continue;
      }
      final home = (r['homeTeam'] as String?) ?? 'Home';
      final away = (r['awayTeam'] as String?) ?? 'Away';
      final h = (hs as num).toInt();
      final a = (ascore as num).toInt();
      stats.putIfAbsent(home, _Acc.new);
      stats.putIfAbsent(away, _Acc.new);
      final hb = (r['homeBadge'] as String?) ?? '';
      final ab = (r['awayBadge'] as String?) ?? '';
      if (hb.isNotEmpty) logos[home] = hb;
      if (ab.isNotEmpty) logos[away] = ab;

      stats[home]!.played++;
      stats[away]!.played++;
      stats[home]!.gf += h;
      stats[home]!.ga += a;
      stats[away]!.gf += a;
      stats[away]!.ga += h;
      if (h > a) {
        stats[home]!.won++;
        stats[away]!.lost++;
        stats[home]!.pts += 3;
      } else if (h < a) {
        stats[away]!.won++;
        stats[home]!.lost++;
        stats[away]!.pts += 3;
      } else {
        stats[home]!.drawn++;
        stats[away]!.drawn++;
        stats[home]!.pts++;
        stats[away]!.pts++;
      }
    }

    final list = [
      for (final e in stats.entries)
        StandingRow(
          teamName: e.key,
          played: e.value.played,
          won: e.value.won,
          drawn: e.value.drawn,
          lost: e.value.lost,
          goalsFor: e.value.gf,
          goalsAgainst: e.value.ga,
          points: e.value.pts,
          logoUrl: logos[e.key] ?? NbcClubBadges.forName(e.key) ?? '',
        ),
    ];
    list.sort((a, b) {
      final p = b.points.compareTo(a.points);
      if (p != 0) return p;
      final gd = b.goalDifference.compareTo(a.goalDifference);
      if (gd != 0) return gd;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return list;
  }

  Future<List<MatchModel>> _fetchAll() async {
    final rows = await _sb.from('Match').select().order('kickoffAt');
    return _mapRows(rows as List);
  }

  List<MatchModel> _mapRows(List rows) => [
        for (final r in rows) _fromRow(Map<String, dynamic>.from(r as Map)),
      ];

  MatchModel _fromRow(Map<String, dynamic> r) {
    final home = (r['homeTeam'] as String?) ?? 'Home';
    final away = (r['awayTeam'] as String?) ?? 'Away';
    final homeScore = r['homeScore'];
    final awayScore = r['awayScore'];
    final statusRaw = ((r['status'] as String?) ?? 'scheduled').toLowerCase();
    final kick =
        DateTime.tryParse((r['kickoffAt'] as String?) ?? '')?.toLocal() ??
            DateTime.now();
    final isLive = statusRaw == 'live' ||
        statusRaw == 'in_play' ||
        statusRaw == 'ht' ||
        statusRaw == '1h' ||
        statusRaw == '2h';
    var score = '-';
    if (homeScore != null && awayScore != null) {
      score = '$homeScore-$awayScore';
    }
    late final String status;
    if (isLive) {
      final min = r['minute'];
      status = min != null ? "$min'" : 'LIVE';
    } else if (statusRaw == 'finished' ||
        statusRaw == 'ft' ||
        statusRaw == 'completed') {
      status = 'FT';
    } else if (r['events'] is Map && (r['events'] as Map)['round'] != null) {
      status = 'R${(r['events'] as Map)['round']}';
    } else {
      status = statusRaw;
    }
    final league = (r['league'] as String?) ?? 'League';
    final homeLogo = (r['homeBadge'] as String?)?.trim();
    final awayLogo = (r['awayBadge'] as String?)?.trim();
    return MatchModel(
      id: (r['id'] as String?) ?? 'match',
      homeTeamName: home,
      awayTeamName: away,
      homeTeamLogo: (homeLogo != null && homeLogo.isNotEmpty)
          ? homeLogo
          : (NbcClubBadges.forName(home) ?? ''),
      awayTeamLogo: (awayLogo != null && awayLogo.isNotEmpty)
          ? awayLogo
          : (NbcClubBadges.forName(away) ?? ''),
      leagueName: league,
      leagueLogo: NbcClubBadges.ligiKuuBara,
      score: score,
      status: status,
      startTime: kick,
      isLive: isLive,
    );
  }
}

class _Acc {
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int gf = 0;
  int ga = 0;
  int pts = 0;
}
