import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../../../core/data/vps_repository.dart';
import '../domain/models/match_model.dart';
import '../domain/models/match_status.dart';
import '../domain/models/standing_model.dart';

const int kMaxMatchesPerFetch = 200;

/// Live scores — all data via VPS API (/v1/matches/*).
/// Admin mutations go through VPS /v1/admin/matches (JWT attached by ApiClient,
/// admin role enforced server-side by the VPS).
class ScoresRepository {
  const ScoresRepository();

  static final _vps = const VpsRepository();

  // ── Live / Today / Upcoming / Results ────────────────────────────────────

  Future<List<MatchModel>> getLive({int limit = kMaxMatchesPerFetch}) async {
    try {
      final rows = await _vps.getLiveMatches();
      final list = rows.map(_fromRow).toList();
      if (list.isNotEmpty) return list;
      // fallback: filter upcoming matches in-window
      final all = await _fetchAll(limit: limit);
      final now = DateTime.now().toUtc();
      return all.where((m) {
        if (isFinishedStatus(m.status) || isPostponedStatus(m.status)) return false;
        final end = m.startTime.add(const Duration(minutes: 110));
        return !now.isBefore(m.startTime) && now.isBefore(end);
      }).toList();
    } catch (e) {
      debugPrint('[SCORES] getLive: $e');
      return [];
    }
  }

  Future<List<MatchModel>> getToday({int limit = kMaxMatchesPerFetch}) async {
    try {
      final rows = await _vps.getTodayMatches();
      return rows.map(_fromRow).toList();
    } catch (e) {
      debugPrint('[SCORES] getToday: $e');
      return [];
    }
  }

  Future<List<MatchModel>> getUpcoming({DateTime? day, int limit = kMaxMatchesPerFetch}) async {
    try {
      final rows = await _vps.getUpcomingMatches();
      var list = rows.map(_fromRow).toList();
      if (day != null) {
        list = list.where((m) =>
            m.startTime.year == day.year &&
            m.startTime.month == day.month &&
            m.startTime.day == day.day).toList();
      }
      return list;
    } catch (e) {
      debugPrint('[SCORES] getUpcoming: $e');
      return [];
    }
  }

  Future<List<MatchModel>> getResults({DateTime? day, int limit = kMaxMatchesPerFetch}) async {
    try {
      final rows = await _vps.getResults();
      var list = rows.map(_fromRow).toList();
      if (list.isEmpty) {
        final now = DateTime.now().toUtc();
        final all = await _fetchAll(limit: limit);
        list = all
            .where((m) => m.startTime.add(const Duration(minutes: 110)).isBefore(now))
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
      }
      if (day != null) {
        list = list.where((m) =>
            m.startTime.year == day.year &&
            m.startTime.month == day.month &&
            m.startTime.day == day.day).toList();
      }
      return list;
    } catch (e) {
      debugPrint('[SCORES] getResults: $e');
      return [];
    }
  }

  Future<List<MatchModel>> _fetchAll({int limit = kMaxMatchesPerFetch}) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/matches/all', query: {'limit': limit});
      final rows = (res.data?['matches'] as List? ?? []).cast<Map<String, dynamic>>();
      return rows.map(_fromRow).toList();
    } catch (_) {
      // fallback: today + upcoming + results combined
      final results = await Future.wait([
        _vps.getTodayMatches(),
        _vps.getUpcomingMatches(),
        _vps.getResults(),
      ]);
      final all = <Map<String, dynamic>>{};
      for (final list in results) {
        for (final m in list) all.add(m);
      }
      return all.map(_fromRow).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
  }

  // ── Leagues / teams ───────────────────────────────────────────────────────

  Future<List<String>> listLeagues({String? sportSlug}) async {
    try {
      // Get distinct league names from VPS matches
      final res = await _vps.get<Map<String, dynamic>>('/v1/matches/leagues');
      return ((res.data?['leagues']) as List? ?? []).cast<String>();
    } catch (_) {
      // Fallback: get from results
      try {
        final rows = await _vps.getResults();
        final seen = <String>{};
        final names = <String>[];
        for (final r in rows) {
          final name = (r['league'] as String?)?.trim();
          if (name != null && name.isNotEmpty && seen.add(name.toLowerCase())) {
            names.add(name);
          }
        }
        names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return names;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> listTeams() async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/admin/teams');
      return ((res.data?['teams']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Standings ─────────────────────────────────────────────────────────────

  Future<List<StandingRow>> getStandings({
    required String league,
    String sportSlug = 'football',
  }) async {
    try {
      final rows = await _vps.getStandings(league);
      return rows.map((r) => StandingRow(
        teamName:     r['team']?.toString() ?? '',
        played:       (r['p']   as int?) ?? 0,
        won:          (r['w']   as int?) ?? 0,
        drawn:        (r['d']   as int?) ?? 0,
        lost:         (r['l']   as int?) ?? 0,
        goalsFor:     (r['gf']  as int?) ?? 0,
        goalsAgainst: (r['ga']  as int?) ?? 0,
        points:       (r['pts'] as int?) ?? 0,
        logoUrl:      NbcClubBadges.forName(r['team']?.toString() ?? ''),
      )).toList();
    } catch (e) {
      debugPrint('[SCORES] getStandings: $e');
      return [];
    }
  }

  // ── Admin mutations — use VPS /v1/admin/matches ───────────────────────────

  Future<void> updateMatchResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    await updateMatchLive(
      matchId: matchId, homeScore: homeScore,
      awayScore: awayScore, status: 'finished',
    );
  }

  Future<void> updateMatchLive({
    required String matchId,
    int? homeScore, int? awayScore,
    String? status, int? minute,
  }) async {
    final patch = <String, dynamic>{};
    if (homeScore != null) patch['homeScore'] = homeScore;
    if (awayScore != null) patch['awayScore'] = awayScore;
    if (status   != null) patch['status']    = status;
    if (minute   != null) patch['minute']    = minute;
    await _vps.patch<void>('/v1/admin/matches/$matchId', data: patch);
  }

  Future<List<Map<String, dynamic>>> listMatchesForAdmin({int limit = 40, int offset = 0}) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/admin/matches', query: {'limit': limit, 'offset': offset},
      );
      return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String q, {int limit = 20}) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/social/players/search', query: {'q': q, 'limit': limit},
      );
      return ((res.data?['players']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  // ── Row mapper ────────────────────────────────────────────────────────────

  MatchModel _fromRow(Map<String, dynamic> r) {
    final home = (r['homeTeam'] as String?) ?? 'Home';
    final away = (r['awayTeam'] as String?) ?? 'Away';
    final hs   = r['homeScore'];
    final as_  = r['awayScore'];
    final statusRaw = ((r['status'] as String?) ?? 'scheduled').toLowerCase();
    final kick = DateTime.tryParse((r['kickoffAt'] as String?) ?? '')?.toLocal() ?? DateTime.now();
    final venue   = (r['venue'] as String?)?.trim() ?? '';
    final minute  = r['minute'] is num ? (r['minute'] as num).toInt() : null;
    final postId  = (r['postId'] as String?)?.trim();
    final sportSlug = ((r['sport_slug'] as String?) ?? (r['sportSlug'] as String?) ?? 'football').trim();
    final isLive  = kLiveStatuses.contains(statusRaw);
    final score   = formatScore(hs is num ? hs.toInt() : null, as_ is num ? as_.toInt() : null);
    final String statusText;
    if (isLive) {
      statusText = minute != null ? "$minute'" : 'LIVE';
    } else if (kFinishedStatuses.contains(statusRaw)) {
      statusText = 'FT';
    } else if (_extractRound(r['events']) != null) {
      statusText = 'R${_extractRound(r['events'])}';
    } else {
      statusText = statusRaw.isEmpty ? 'scheduled' : statusRaw;
    }
    final homeLogo = (r['homeBadge'] as String?)?.trim();
    final awayLogo = (r['awayBadge'] as String?)?.trim();
    return MatchModel(
      id:            (r['id'] as String?) ?? 'match',
      homeTeamName:  home,
      awayTeamName:  away,
      homeTeamLogo:  (homeLogo != null && homeLogo.isNotEmpty) ? homeLogo : NbcClubBadges.forName(home),
      awayTeamLogo:  (awayLogo != null && awayLogo.isNotEmpty) ? awayLogo : NbcClubBadges.forName(away),
      leagueName:    (r['league'] as String?) ?? 'League',
      leagueLogo:    '',
      score:         score,
      status:        statusText,
      startTime:     kick,
      isLive:        isLive,
      sportSlug:     sportSlug.isEmpty ? 'football' : sportSlug,
      venue:         venue,
      postId:        (postId != null && postId.isNotEmpty) ? postId : null,
      minute:        minute,
    );
  }

  static int? _extractRound(Object? events) {
    if (events == null) return null;
    try {
      if (events is Map)  { final r = events['round']; return r is num ? r.toInt() : r is String ? int.tryParse(r) : null; }
      if (events is List) { for (final e in events) { if (e is Map) { final r = e['round']; if (r is num) return r.toInt(); } } }
      if (events is String && events.isNotEmpty) { final d = jsonDecode(events); return _extractRound(d); }
    } catch (_) {}
    return null;
  }
}
