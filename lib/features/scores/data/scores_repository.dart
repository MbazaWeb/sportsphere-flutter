import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../domain/models/match_model.dart';

/// Live scores/fixtures from Supabase `Match` + `League` (not hardcoded seed).
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
    // Soft live window when admin has not flipped status yet
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
    var q = _sb
        .from('Match')
        .select()
        .gte('kickoffAt', now.toIso8601String())
        .order('kickoffAt');
    final rows = await q;
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
        .or('status.eq.finished,status.eq.ft,status.eq.completed')
        .order('kickoffAt', ascending: false);
    var list = _mapRows(rows as List);
    if (list.isEmpty) {
      // Past kickoffs without score still show as result slots for admin
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
    var q = _sb.from('League').select('name,sport_slug,isActive').eq('isActive', true).order('name');
    final rows = await q;
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
    if (names.isEmpty) return const ['NBC Premier League', 'Ligi Kuu Bara'];
    return names;
  }

  Future<List<Map<String, dynamic>>> listTeams({String? leagueHint}) async {
    final rows = await _sb
        .from('Team')
        .select('id,name,logoUrl,accountUserId,sport_slug,city,country')
        .eq('isActive', true)
        .order('name');
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }

  Future<List<MatchModel>> _fetchAll() async {
    final rows = await _sb.from('Match').select().order('kickoffAt');
    return _mapRows(rows as List);
  }

  List<MatchModel> _mapRows(List rows) {
    return [
      for (final r in rows)
        _fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  MatchModel _fromRow(Map<String, dynamic> r) {
    final home = (r['homeTeam'] as String?) ?? 'Home';
    final away = (r['awayTeam'] as String?) ?? 'Away';
    final homeScore = r['homeScore'];
    final awayScore = r['awayScore'];
    final statusRaw = ((r['status'] as String?) ?? 'scheduled').toLowerCase();
    final kick = DateTime.tryParse((r['kickoffAt'] as String?) ?? '')?.toLocal() ??
        DateTime.now();
    final isLive = statusRaw == 'live' ||
        statusRaw == 'in_play' ||
        statusRaw == 'ht' ||
        statusRaw == '1h' ||
        statusRaw == '2h';
    String score = '-';
    if (homeScore != null && awayScore != null) {
      score = '$homeScore-$awayScore';
    }
    String status;
    if (isLive) {
      final min = r['minute'];
      status = min != null ? "$min'" : 'LIVE';
    } else if (statusRaw == 'finished' || statusRaw == 'ft' || statusRaw == 'completed') {
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
