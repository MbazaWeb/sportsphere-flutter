import 'match_status.dart';

class MatchModel {
  const MatchModel({
    required this.id,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamLogo,
    required this.awayTeamLogo,
    required this.leagueName,
    required this.leagueLogo,
    required this.score,
    required this.status,
    required this.startTime,
    this.isLive = false,
    this.sportSlug = 'football',
    this.venue = '',
    this.postId,
    this.minute,
  });

  final String id;
  final String homeTeamName;
  final String awayTeamName;
  final String homeTeamLogo;
  final String awayTeamLogo;
  final String leagueName;
  final String leagueLogo;
  final String score;
  final String status;
  final DateTime startTime;
  final bool isLive;

  /// Sport slug, e.g. `football`, `basketball`, `tennis`.
  /// Defaults to `football` because the `Match` table does not yet carry its
  /// own `sport_slug` column — it is resolved from the league's sport when
  /// available (see [ScoresRepository._fromRow]).
  final String sportSlug;

  /// Free-text venue (stadium) of the match, if known.
  final String venue;

  /// Linked Post id (if the match has a discussion thread). Used for like /
  /// share / comment actions so they write to the social graph.
  final String? postId;

  /// Current minute when the match is live (e.g. `45`), null otherwise.
  final int? minute;

  MatchModel copyWith({
    String? score,
    String? status,
    bool? isLive,
    String? sportSlug,
    String? venue,
    String? postId,
    int? minute,
  }) {
    return MatchModel(
      id: id,
      homeTeamName: homeTeamName,
      awayTeamName: awayTeamName,
      homeTeamLogo: homeTeamLogo,
      awayTeamLogo: awayTeamLogo,
      leagueName: leagueName,
      leagueLogo: leagueLogo,
      score: score ?? this.score,
      status: status ?? this.status,
      startTime: startTime,
      isLive: isLive ?? this.isLive,
      sportSlug: sportSlug ?? this.sportSlug,
      venue: venue ?? this.venue,
      postId: postId ?? this.postId,
      minute: minute ?? this.minute,
    );
  }

  /// Parsed status (football-aware vocab).
  MatchStatus get parsedStatus => parseMatchStatus(status);
}
