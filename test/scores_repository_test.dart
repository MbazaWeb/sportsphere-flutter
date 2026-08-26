import 'package:flutter_test/flutter_test.dart';
import 'package:playify/features/scores/data/scores_repository.dart';

// ScoresRepository provides offline/fallback mock data used when Supabase
// is unreachable. The live data path goes through fetchLiveMatches() in
// live_scores.dart (Supabase), but the provider falls back to this repo.
// These tests verify the fallback layer stays consistent.
void main() {
  group('ScoresRepository (offline fallback)', () {
    const repo = ScoresRepository();

    test('getLive returns non-empty list with isLive=true', () async {
      final matches = await repo.getLive();
      expect(matches, isNotEmpty);
      expect(matches.every((m) => m.isLive), true);
    });

    test('getToday returns matches without isLive flag', () async {
      final matches = await repo.getToday();
      expect(matches, isNotEmpty);
      expect(matches.every((m) => !m.isLive), true);
    });

    test('getUpcoming returns future-dated matches', () async {
      final matches = await repo.getUpcoming();
      expect(matches, isNotEmpty);
      final now = DateTime.now();
      expect(matches.every((m) => m.startTime.isAfter(now)), true);
    });

    test('getResults returns finished matches with FT status', () async {
      final matches = await repo.getResults();
      expect(matches, isNotEmpty);
      expect(matches.every((m) => m.status == 'FT'), true);
    });

    test('MatchModel.copyWith preserves unchanged fields', () async {
      final matches = await repo.getLive();
      final m = matches.first;
      final updated = m.copyWith(score: '3 - 0');
      expect(updated.score, '3 - 0');
      expect(updated.homeTeamName, m.homeTeamName);
      expect(updated.id, m.id);
    });
  });
}
