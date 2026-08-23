import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../domain/models/match_model.dart';
import '../domain/models/match_status.dart';
import '../domain/models/standing_model.dart';

/// Cap on the number of rows fetched per paged query. Tune with care —
/// Supabase/PostgREST has a 1000-row hard ceiling per request.
const int kMaxMatchesPerFetch = 200;

/// Live scores / standings from Supabase only (no hardcoded fixtures).
class ScoresRepository {
  const ScoresRepository();

  SupabaseClient get _sb => Supabase.instance.client;

  // NOTE: The previous _public() wrapper called signOut(scope: local)
  // when a data query failed with JWT/session/401 keywords. This was
  // INCORRECT — a data query failure must NEVER destroy the auth session.
  // _ensureValidSession() in main.dart handles stale JWT at startup.
  // If a public query fails here, the error propagates to the UI which
  // shows the appropriate message via friendlyError().

  // ─────────────────────────────────────────────────────────────────────────
  // Live / Today / Upcoming / Results
  // ─────────────────────────────────────────────────────────────────────────

  /// All matches currently in play.
  ///
  /// Two-tier filter (unified vocab via [kLiveStatuses] /
  /// [kFinishedStatuses] / [kPostponedStatuses]):
  ///   1. SQL: `status in (live, in_play, ht, 1h, 2h)`
  ///   2. Fallback: any match whose status is NOT in (finished ∪ postponed)
  ///      AND whose kickoff is within the last 110 minutes.
  Future<List<MatchModel>> getLive({int limit = kMaxMatchesPerFetch}) async {
      final liveOr = kLiveStatuses.map((s) => 'status.eq.$s').join(',');
      final rows = await _sb
          .from('Match')
          .select()
          .or(liveOr)
          .order('kickoffAt')
          .limit(limit);
      final list = _mapRows(rows as List);
      if (list.isNotEmpty) return list;

      final now = DateTime.now().toUtc();
      final all = await _fetchAll(limit: limit);
      return all.where((m) {
        if (isFinishedStatus(m.status) || isPostponedStatus(m.status)) {
          return false;
        }
        final end = m.startTime.add(const Duration(minutes: 110));
        return !now.isBefore(m.startTime) && now.isBefore(end);
      }).toList();
  }

  Future<List<MatchModel>> getToday({int limit = kMaxMatchesPerFetch}) async {
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final rows = await _sb
          .from('Match')
          .select()
          .gte('kickoffAt', start.toIso8601String())
          .lt('kickoffAt', end.toIso8601String())
          .order('kickoffAt')
          .limit(limit);
      return _mapRows(rows as List);
  }

  Future<List<MatchModel>> getUpcoming({
    DateTime? day,
    int limit = kMaxMatchesPerFetch,
  }) async {
    final now = DateTime.now().toUtc();
    final rows = await _sb
        .from('Match')
        .select()
        .gte('kickoffAt', now.toIso8601String())
        .order('kickoffAt')
        .limit(limit);
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

  Future<List<MatchModel>> getResults({
    DateTime? day,
    int limit = kMaxMatchesPerFetch,
  }) async {
    final finishedOr = kFinishedStatuses.map((s) => 'status.eq.$s').join(',');
    final rows = await _sb
        .from('Match')
        .select()
        .or(finishedOr)
        .order('kickoffAt', ascending: false)
        .limit(limit);
    var list = _mapRows(rows as List);
    if (list.isEmpty) {
      final now = DateTime.now().toUtc();
      final all = await _fetchAll(limit: limit);
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

  Future<List<MatchModel>> _fetchAll({int limit = kMaxMatchesPerFetch}) async {
      final rows =
          await _sb.from('Match').select().order('kickoffAt').limit(limit);
      return _mapRows(rows as List);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Leagues / teams
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // Standings
  // ─────────────────────────────────────────────────────────────────────────

  /// Standings computed from admin-finished matches only.
  ///
  /// Sport-aware:
  ///   * football / hockey / rugby → 3 pts/win, 1 pt/draw, draws column shown.
  ///   * basketball / tennis / volleyball / … → 2 pts/win, 0 pts/draw, draws
  ///     always 0 (no draws column meaningful).
  ///
  /// `league` is matched EXACTLY against the `league` column (case-insensitive
  /// `.ilike()` with no wildcards). The previous fuzzy `.contains()` logic
  /// matched "Premier" to "Premiership" and other false positives.
  Future<List<StandingRow>> getStandings({
    required String league,
    String sportSlug = 'football',
  }) async {
    // Push the league filter to SQL so we don't download the entire Match
    // table just to discard most of it in memory (H6). The in-memory
    // leagueName check below is kept as a defensive safety net for any
    // rows whose stored league value differs only by trailing whitespace.
    // .limit(500) caps the download — well below the PostgREST 1000-row
    // ceiling but large enough for a full season of matches in one league.
    final leagueLower = league.toLowerCase().trim();
    var query = _sb.from('Match').select(
        'homeTeam,awayTeam,homeScore,awayScore,status,homeBadge,awayBadge,league');
    if (leagueLower.isNotEmpty) {
      query = query.ilike('league', league);
    }
    final rows = await query.limit(500);

    final stats = <String, _Acc>{};
    final logos = <String, String>{};
    final hasDraws = sportHasDraws(sportSlug);
    final winPts = winPointsForSport(sportSlug);
    final drawPts = drawPointsForSport(sportSlug);

    for (final raw in rowList) {
      final r = Map<String, dynamic>.from(raw as Map);
      final leagueName = ((r['league'] as String?) ?? '').toLowerCase().trim();

      // Filter: if league specified, check that this match belongs to it.
      // Accept if: exact match, OR either name contains the other (handles
      // "NBC Tanzania Premier League" vs "Tanzania Premier League" etc.)
      if (leagueLower.isNotEmpty) {
        final match = leagueName == leagueLower ||
            leagueName.contains(leagueLower) ||
            leagueLower.contains(leagueName);
        if (!match) continue;
      }

      final status = ((r['status'] as String?) ?? '').toLowerCase();
      if (!kFinishedStatuses.contains(status)) continue;

      final hs = r['homeScore'];
      final ascore = r['awayScore'];
      if (hs == null || ascore == null) continue;

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
        stats[home]!.pts += winPts;
      } else if (h < a) {
        stats[away]!.won++;
        stats[home]!.lost++;
        stats[away]!.pts += winPts;
      } else if (hasDraws) {
        stats[home]!.drawn++;
        stats[away]!.drawn++;
        stats[home]!.pts += drawPts;
        stats[away]!.pts += drawPts;
      } else {
        // Sport without draws — shouldn't happen, but be safe.
        stats[home]!.drawn++;
        stats[away]!.drawn++;
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
          logoUrl: logos[e.key] ?? NbcClubBadges.forName(e.key),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Row mapping
  // ─────────────────────────────────────────────────────────────────────────

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
    final venue = (r['venue'] as String?)?.trim() ?? '';
    final minute = r['minute'] is num ? (r['minute'] as num).toInt() : null;
    final postId = (r['postId'] as String?)?.trim();
    final sportSlug =
        ((r['sport_slug'] as String?) ?? (r['sportSlug'] as String?) ?? 'football')
            .trim();

    // Unify the "is live" decision across the entire feature.
    final isLive = kLiveStatuses.contains(statusRaw);

    // One formatter, used everywhere — never two divergent ones.
    final score = formatScore(
      homeScore is num ? homeScore.toInt() : null,
      awayScore is num ? awayScore.toInt() : null,
    );

    // Status badge text — keep showing the actual status, do NOT override it
    // with a synthetic "LIVE" pill (the [isLive] flag handles that on the UI
    // side). Round info comes from `events` (a jsonb list per schema, but some
    // legacy rows still write a Map).
    final String status;
    if (isLive) {
      status = minute != null ? "$minute'" : 'LIVE';
    } else if (kFinishedStatuses.contains(statusRaw)) {
      status = 'FT';
    } else if (_extractRound(r['events']) != null) {
      status = 'R${_extractRound(r['events'])}';
    } else {
      status = statusRaw.isEmpty ? 'scheduled' : statusRaw;
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
          : NbcClubBadges.forName(home),
      awayTeamLogo: (awayLogo != null && awayLogo.isNotEmpty)
          ? awayLogo
          : NbcClubBadges.forName(away),
      leagueName: league,
      leagueLogo: '',
      score: score,
      status: status,
      startTime: kick,
      isLive: isLive,
      sportSlug: sportSlug.isEmpty ? 'football' : sportSlug,
      venue: venue,
      postId: (postId != null && postId.isNotEmpty) ? postId : null,
      minute: minute,
    );
  }

  /// `events` is jsonb. Schema default is `'[]'` (a List), but some legacy
  /// writers may still push a Map. Handle both — return the first integer-like
  /// `round` value found, or null.
  static int? _extractRound(Object? events) {
    if (events == null) return null;
    try {
      if (events is Map) {
        final round = events['round'];
        if (round is num) return round.toInt();
        if (round is String) return int.tryParse(round);
        return null;
      }
      if (events is List) {
        for (final e in events) {
          if (e is Map) {
            final round = e['round'];
            if (round is num) return round.toInt();
            if (round is String) return int.tryParse(round);
          }
        }
      }
      // Fallback: events stored as a JSON string.
      if (events is String && events.isNotEmpty) {
        final decoded = jsonDecode(events);
        if (decoded is Map) return _extractRound(decoded);
        if (decoded is List) return _extractRound(decoded);
      }
    } catch (_) {
      // Malformed jsonb — never throw inside the row mapper.
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Admin mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Admin: set final score and mark finished.
  Future<void> updateMatchResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    await updateMatchLive(
      matchId: matchId,
      homeScore: homeScore,
      awayScore: awayScore,
      status: 'finished',
    );
  }

  /// Admin live control: status + scores + minute.
  Future<void> updateMatchLive({
    required String matchId,
    int? homeScore,
    int? awayScore,
    String? status,
    int? minute,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (homeScore != null) patch['homeScore'] = homeScore;
    if (awayScore != null) patch['awayScore'] = awayScore;
    if (status != null) patch['status'] = status;
    if (minute != null) patch['minute'] = minute;
    await _sb.from('Match').update(patch).eq('id', matchId);
  }

  /// Admin: paginated list of matches for the live-control sheet.
  ///
  /// `offset` is 0-based; the query selects a window of `[offset, offset+limit)`.
  Future<List<Map<String, dynamic>>> listMatchesForAdmin({
    int limit = 40,
    int offset = 0,
  }) async {
    final rows = await _sb
        .from('Match')
        .select('id,homeTeam,awayTeam,homeScore,awayScore,status,kickoffAt,minute')
        .order('kickoffAt', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String q, {int limit = 20}) async {
    final rows = await _sb
        .from('Player')
        .select('id,name,slug,teamId,position')
        .ilike('name', '%$q%')
        .limit(limit);
    return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
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
