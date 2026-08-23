import 'package:flutter/material.dart';

/// Canonical status vocabulary for [MatchModel].
///
/// The Supabase `Match.status` column is a free-form string that has drifted
/// across many writers (`live`, `in_play`, `ht`, `1h`, `2h`, `finished`, `ft`,
/// `completed`, `full_time`, `postponed`, `cancelled`, `scheduled`, `upcoming`).
/// This enum + parser centralises that sprawl so the UI/data layers always
/// agree on what a status means.
enum MatchStatus {
  scheduled,
  live,
  halfTime,
  finished,
  postponed,
  cancelled,
  unknown;

  bool get isLive => this == MatchStatus.live || this == MatchStatus.halfTime;
  bool get isFinished => this == MatchStatus.finished;
  bool get isPostponedOrCancelled =>
      this == MatchStatus.postponed || this == MatchStatus.cancelled;
}

/// Lower-cased status strings that mean "match is in play".
const Set<String> kLiveStatuses = {
  'live',
  'in_play',
  'ht',
  '1h',
  '2h',
};

/// Lower-cased status strings that mean "match is over".
const Set<String> kFinishedStatuses = {
  'finished',
  'ft',
  'completed',
  'full_time',
  'fulltime',
  'ended',
  'final',
  'done',
  'played',
  'result',
  'fts',
  '90',
  'aet',
  'pen',
};

/// Lower-cased status strings that mean "match won't be played as scheduled".
const Set<String> kPostponedStatuses = {
  'postponed',
  'cancelled',
  'canceled',
};

/// Lower-cased status strings that mean "match has not started yet".
const Set<String> kScheduledStatuses = {
  'scheduled',
  'upcoming',
  'ns',
  'not_started',
};

/// Parses a raw status string (any case) into a [MatchStatus].
MatchStatus parseMatchStatus(String? raw) {
  if (raw == null || raw.isEmpty) return MatchStatus.scheduled;
  final s = raw.toLowerCase().trim();
  if (kLiveStatuses.contains(s)) {
    return s == 'ht' ? MatchStatus.halfTime : MatchStatus.live;
  }
  if (kFinishedStatuses.contains(s)) return MatchStatus.finished;
  if (kPostponedStatuses.contains(s)) {
    return s.startsWith('cancel') ? MatchStatus.cancelled : MatchStatus.postponed;
  }
  if (kScheduledStatuses.contains(s)) return MatchStatus.scheduled;
  return MatchStatus.unknown;
}

/// True if a match with this raw status should be considered "in play" right
/// now (used to colour the badge / show the LIVE pill).
bool isLiveStatus(String? raw) => parseMatchStatus(raw).isLive;

/// True if the match has finished.
bool isFinishedStatus(String? raw) => parseMatchStatus(raw).isFinished;

/// True if the match is postponed or cancelled.
bool isPostponedStatus(String? raw) => parseMatchStatus(raw).isPostponedOrCancelled;

/// Single source of truth for rendering a score line.
///
/// Returns `'-'` only when BOTH scores are null. If exactly one is null the
/// other is shown alone (e.g. `'2 -'`). Otherwise `'2 - 0'`.
String formatScore(int? home, int? away) {
  if (home == null && away == null) return '-';
  final h = home?.toString() ?? '-';
  final a = away?.toString() ?? '-';
  return '$h - $a';
}

/// Material icon for a sport slug. Defaults to soccer.
IconData sportIconFor(String? sportSlug) {
  switch ((sportSlug ?? 'football').toLowerCase()) {
    case 'basketball':
      return Icons.sports_basketball;
    case 'tennis':
      return Icons.sports_tennis;
    case 'volleyball':
      return Icons.sports_volleyball;
    case 'rugby':
      return Icons.sports_rugby;
    case 'cricket':
      return Icons.sports_cricket;
    case 'boxing':
      return Icons.sports_mma;
    case 'mma':
      return Icons.sports_mma;
    case 'cycling':
      return Icons.directions_bike;
    case 'swimming':
      return Icons.pool;
    case 'golf':
      return Icons.sports_golf;
    case 'hockey':
    case 'handball':
      return Icons.sports_handball;
    case 'badminton':
      return Icons.sports_tennis;
    case 'table_tennis':
      return Icons.sports_tennis;
    case 'motorsport':
      return Icons.sports_motorsports;
    case 'esports':
      return Icons.sports_esports;
    case 'athletics':
      return Icons.directions_run;
    case 'netball':
      return Icons.sports_soccer;
    case 'wrestling':
      return Icons.sports_mma;
    case 'football':
    default:
      return Icons.sports_soccer;
  }
}

/// Whether the standings computation for this sport should treat draws as
/// possible (football, hockey) or impossible (basketball, tennis, etc.).
bool sportHasDraws(String? sportSlug) {
  switch ((sportSlug ?? 'football').toLowerCase()) {
    case 'football':
    case 'hockey':
    case 'handball':
    case 'rugby':
      return true;
    default:
      return false;
  }
}

/// Points awarded for a win in this sport. Football = 3, most others = 2.
int winPointsForSport(String? sportSlug) {
  switch ((sportSlug ?? 'football').toLowerCase()) {
    case 'football':
    case 'hockey':
    case 'rugby':
      return 3;
    default:
      return 2;
  }
}

/// Points awarded for a draw in this sport. 0 if draws aren't possible.
int drawPointsForSport(String? sportSlug) =>
    sportHasDraws(sportSlug) ? 1 : 0;
