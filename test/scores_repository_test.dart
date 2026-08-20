import 'package:flutter_test/flutter_test.dart';
import 'package:sportsphere_app/features/scores/data/scores_repository.dart';
import 'package:sportsphere_app/features/scores/domain/models/match_model.dart';

void main() {
  group('ScoresRepository', () {
    const repo = ScoresRepository();

    test('getUpcoming returns future-dated matches only', () async {
      final matches = await repo.getUpcoming();
      final now = DateTime.now();
      for (final m in matches) {
        expect(
          m.startTime.isAfter(now),
          true,
          reason: '${m.homeTeamName} vs ${m.awayTeamName} startTime should be in future',
        );
      }
    });

    test('getResults returns finished matches only', () async {
      final matches = await repo.getResults();
      final cutoff = DateTime.now().subtract(const Duration(minutes: 110));
      for (final m in matches) {
        expect(
          m.startTime.isBefore(cutoff),
          true,
          reason: '${m.homeTeamName} vs ${m.awayTeamName} should have ended',
        );
      }
    });

    test('getLive returns only matches that overlap current time window', () async {
      final matches = await repo.getLive();
      final now = DateTime.now();
      for (final m in matches) {
        final end = m.startTime.add(const Duration(minutes: 110));
        expect(
          !now.isBefore(m.startTime) && now.isBefore(end),
          true,
          reason: '${m.homeTeamName} vs ${m.awayTeamName} should be within live window',
        );
      }
      // Empty outside match windows is fine
    });

    test('getToday returns only matches on the current calendar date', () async {
      final matches = await repo.getToday();
      final now = DateTime.now();
      for (final m in matches) {
        expect(m.startTime.year, now.year);
        expect(m.startTime.month, now.month);
        expect(m.startTime.day, now.day);
      }
    });

    test('upcoming and results are disjoint sets', () async {
      final upcoming = await repo.getUpcoming();
      final results = await repo.getResults();
      final upcomingIds = upcoming.map((m) => m.id).toSet();
      final resultIds = results.map((m) => m.id).toSet();
      expect(upcomingIds.intersection(resultIds), isEmpty);
    });

    test('MatchModel copyWith produces updated copy preserving unchanged fields', () {
      final m = MatchModel(
        id: 'test-1',
        homeTeamName: 'Simba SC',
        awayTeamName: 'Young Africans SC',
        homeTeamLogo: '',
        awayTeamLogo: '',
        leagueName: 'Ligi Kuu Bara',
        leagueLogo: '',
        score: '-',
        status: 'scheduled',
        startTime: DateTime(2026, 9, 1, 15, 0),
        isLive: false,
      );
      final updated = m.copyWith(score: '2 - 1', status: 'FT');
      expect(updated.score, '2 - 1');
      expect(updated.status, 'FT');
      expect(updated.homeTeamName, 'Simba SC');
      expect(updated.id, 'test-1');
      expect(updated.isLive, false);
    });
  });
}
