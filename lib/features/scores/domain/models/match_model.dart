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

  MatchModel copyWith({
    String? score,
    String? status,
    bool? isLive,
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
    );
  }
}
