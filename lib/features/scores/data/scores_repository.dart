import '../domain/models/match_model.dart';

// ── Scores repository ──────────────────────────────────────────────────────────
//
// Currently returns mock data.
// Wire to GET /scores/live, /scores/today, etc. when the backend is ready.

class ScoresRepository {
  const ScoresRepository();

  Future<List<MatchModel>> getLive() async {
    await Future.delayed(const Duration(milliseconds: 300)); // simulate network
    return _live;
  }

  Future<List<MatchModel>> getToday() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _today;
  }

  Future<List<MatchModel>> getUpcoming() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _upcoming;
  }

  Future<List<MatchModel>> getResults() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _results;
  }
}

// ── Mock datasets ──────────────────────────────────────────────────────────────

final _now = DateTime.now();

final _live = <MatchModel>[
  MatchModel(
    id: 'l1',
    homeTeamName: 'Man City',
    awayTeamName: 'Arsenal',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Premier League',
    leagueLogo: '',
    score: '2 - 1',
    status: "85'",
    startTime: _now.subtract(const Duration(minutes: 85)),
    isLive: true,
  ),
  MatchModel(
    id: 'l2',
    homeTeamName: 'Simba SC',
    awayTeamName: 'Young Africans',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Tanzania Premier League',
    leagueLogo: '',
    score: '1 - 0',
    status: "63'",
    startTime: _now.subtract(const Duration(minutes: 63)),
    isLive: true,
  ),
  MatchModel(
    id: 'l3',
    homeTeamName: 'Real Madrid',
    awayTeamName: 'Bayern München',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'UEFA Champions League',
    leagueLogo: '',
    score: '0 - 0',
    status: "HT",
    startTime: _now.subtract(const Duration(minutes: 45)),
    isLive: true,
  ),
];

final _today = <MatchModel>[
  MatchModel(
    id: 't1',
    homeTeamName: 'Barcelona',
    awayTeamName: 'Atletico Madrid',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'La Liga',
    leagueLogo: '',
    score: '- -',
    status: '20:00',
    startTime: _now.copyWith(hour: 20, minute: 0),
  ),
  MatchModel(
    id: 't2',
    homeTeamName: 'Liverpool',
    awayTeamName: 'Chelsea',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Premier League',
    leagueLogo: '',
    score: '- -',
    status: '18:30',
    startTime: _now.copyWith(hour: 18, minute: 30),
  ),
  MatchModel(
    id: 't3',
    homeTeamName: 'Al Ahly',
    awayTeamName: 'Zamalek',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Egyptian Premier League',
    leagueLogo: '',
    score: '- -',
    status: '21:30',
    startTime: _now.copyWith(hour: 21, minute: 30),
  ),
];

final _upcoming = <MatchModel>[
  MatchModel(
    id: 'u1',
    homeTeamName: 'PSG',
    awayTeamName: 'Inter Milan',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'UEFA Champions League',
    leagueLogo: '',
    score: '- -',
    status: 'Tomorrow 21:00',
    startTime: _now.add(const Duration(days: 1)),
  ),
  MatchModel(
    id: 'u2',
    homeTeamName: 'Tanzania',
    awayTeamName: 'Kenya',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'AFCON Qualifier',
    leagueLogo: '',
    score: '- -',
    status: 'Sat 19:00',
    startTime: _now.add(const Duration(days: 3)),
  ),
  MatchModel(
    id: 'u3',
    homeTeamName: 'Juventus',
    awayTeamName: 'AC Milan',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Serie A',
    leagueLogo: '',
    score: '- -',
    status: 'Sun 20:45',
    startTime: _now.add(const Duration(days: 4)),
  ),
];

final _results = <MatchModel>[
  MatchModel(
    id: 'r1',
    homeTeamName: 'Dortmund',
    awayTeamName: 'Leipzig',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Bundesliga',
    leagueLogo: '',
    score: '3 - 1',
    status: 'FT',
    startTime: _now.subtract(const Duration(days: 1)),
  ),
  MatchModel(
    id: 'r2',
    homeTeamName: 'Young Africans',
    awayTeamName: 'Azam FC',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Tanzania Premier League',
    leagueLogo: '',
    score: '2 - 2',
    status: 'FT',
    startTime: _now.subtract(const Duration(days: 1)),
  ),
  MatchModel(
    id: 'r3',
    homeTeamName: 'Arsenal',
    awayTeamName: 'Tottenham',
    homeTeamLogo: '',
    awayTeamLogo: '',
    leagueName: 'Premier League',
    leagueLogo: '',
    score: '2 - 0',
    status: 'FT',
    startTime: _now.subtract(const Duration(days: 2)),
  ),
];

extension _DateTimeCopyWith on DateTime {
  DateTime copyWith({int? hour, int? minute}) => DateTime(
        year,
        month,
        day,
        hour ?? this.hour,
        minute ?? this.minute,
      );
}
