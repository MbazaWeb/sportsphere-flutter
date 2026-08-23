import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../domain/models/match_model.dart';
import '../domain/models/match_status.dart';
import 'scores_repository.dart' show kMaxMatchesPerFetch;

/// Builds a [MatchModel] from a raw Supabase `Match` row.
///
/// This is the **single shared row mapper** for the scores feature — the
/// repository and any ad-hoc helper that needs to convert a row should call
/// this. It uses [formatScore] / [kLiveStatuses] / [kFinishedStatuses] from
/// [match_status.dart] so the score and live-decision vocabularies cannot
/// drift between files.
MatchModel matchFromRow(Map<String, dynamic> row) {
  final kick =
      DateTime.tryParse(row['kickoffAt']?.toString() ?? '') ?? DateTime.now();
  final hs = row['homeScore'];
  final ascore = row['awayScore'];
  final status = (row['status'] as String?) ?? 'scheduled';
  final statusLower = status.toLowerCase();
  final home = row['homeTeam'] as String? ?? '';
  final away = row['awayTeam'] as String? ?? '';
  final venue = (row['venue'] as String?)?.trim() ?? '';
  final minute = row['minute'] is num ? (row['minute'] as num).toInt() : null;
  final sportSlug =
      ((row['sport_slug'] as String?) ?? (row['sportSlug'] as String?) ?? 'football')
          .trim();
  final postId = (row['postId'] as String?)?.trim();

  // ── Single live heuristic ───────────────────────────────────────────────
  // A match is LIVE only if:
  //   - its status is explicitly in [kLiveStatuses], OR
  //   - its status is NOT in {finished, postponed, cancelled} AND now is in
  //     [kickoff, kickoff + 110 min].
  // We do NOT mutate the displayed status text — the UI shows the actual
  // status string. The `isLive` flag only drives the green pill / pulse.
  final now = DateTime.now();
  final inWindow = !now.isBefore(kick) &&
      now.isBefore(kick.add(const Duration(minutes: 110)));
  final isLive = kLiveStatuses.contains(statusLower) ||
      (inWindow &&
          !kFinishedStatuses.contains(statusLower) &&
          !kPostponedStatuses.contains(statusLower));

  // ── Single score formatter ──────────────────────────────────────────────
  final score = formatScore(
    hs is num ? hs.toInt() : null,
    ascore is num ? ascore.toInt() : null,
  );

  // Status text — keep the raw status (do NOT override with "LIVE" — the
  // badge on the card uses [MatchModel.isLive]).
  final statusText = status.isEmpty ? 'scheduled' : status;

  return MatchModel(
    id: (row['id'] as String?) ?? 'match',
    homeTeamName: home,
    awayTeamName: away,
    homeTeamLogo:
        (row['homeBadge'] as String?)?.trim() ?? NbcClubBadges.forName(home),
    awayTeamLogo:
        (row['awayBadge'] as String?)?.trim() ?? NbcClubBadges.forName(away),
    leagueName: row['league'] as String? ?? '',
    // No league-logo lookup exists in the codebase yet — leave empty rather
    // than misusing NbcClubBadges (which only knows club crests).
    leagueLogo: '',
    score: score,
    status: statusText,
    startTime: kick.toLocal(),
    isLive: isLive,
    sportSlug: sportSlug.isEmpty ? 'football' : sportSlug,
    venue: venue,
    postId: (postId != null && postId.isNotEmpty) ? postId : null,
    minute: minute,
  );
}

Future<List<MatchModel>> fetchLiveMatches({int limit = kMaxMatchesPerFetch}) async {
  return _publicFetch(() async {
    final rows = await Supabase.instance.client
        .from('Match')
        .select()
        .order('kickoffAt')
        .limit(limit);
    return [for (final r in rows as List) matchFromRow(Map<String, dynamic>.from(r))];
  });
}

/// Clears a stale JWT and retries once — mirrors [ScoresRepository._public].
///
/// Public Match reads must work for guests. If a stale JWT is still attached,
/// PostgREST returns JWT/session errors — clear local session and retry once.
Future<T> _publicFetch<T>(Future<T> Function() run) async {
  try {
    return await run();
  } catch (e) {
    final msg = e.toString().toLowerCase();
    final authish = msg.contains('jwt') ||
        msg.contains('session') ||
        msg.contains('401') ||
        msg.contains('expired') ||
        msg.contains('not authenticated') ||
        msg.contains('unauthorized');
    if (!authish) rethrow;
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    return await run();
  }
}

List<MatchModel> filterLive(List<MatchModel> all) =>
    all.where((m) => m.isLive).toList();

List<MatchModel> filterDay(List<MatchModel> all, DateTime day) => all
    .where((m) =>
        m.startTime.year == day.year &&
        m.startTime.month == day.month &&
        m.startTime.day == day.day)
    .toList();

List<MatchModel> filterUpcoming(List<MatchModel> all, DateTime? day) {
  final now = DateTime.now();
  final list = all
      .where((m) =>
          m.startTime.isAfter(now) &&
          !isFinishedStatus(m.status) &&
          !isPostponedStatus(m.status))
      .toList();
  if (day == null) return list;
  return filterDay(list, day);
}

List<MatchModel> filterResults(List<MatchModel> all, DateTime? day) {
  final list = all
      .where((m) => isFinishedStatus(m.status) || isPostponedStatus(m.status))
      .toList();
  if (day == null) return list;
  return filterDay(list, day);
}
