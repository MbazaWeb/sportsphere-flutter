class StandingRow {
  const StandingRow({
    required this.teamName,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
    this.logoUrl = '',
  });

  final String teamName;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int points;
  final String logoUrl;

  int get goalDifference => goalsFor - goalsAgainst;
}
