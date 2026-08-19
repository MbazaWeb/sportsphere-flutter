import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scores_repository.dart';
import '../../domain/models/match_model.dart';

final scoresRepositoryProvider = Provider<ScoresRepository>(
  (_) => const ScoresRepository(),
);

final liveMatchesProvider = FutureProvider<List<MatchModel>>((ref) {
  return ref.watch(scoresRepositoryProvider).getLive();
});

final todayMatchesProvider = FutureProvider<List<MatchModel>>((ref) {
  return ref.watch(scoresRepositoryProvider).getToday();
});

final upcomingMatchesProvider = FutureProvider<List<MatchModel>>((ref) {
  return ref.watch(scoresRepositoryProvider).getUpcoming();
});

final resultsProvider = FutureProvider<List<MatchModel>>((ref) {
  return ref.watch(scoresRepositoryProvider).getResults();
});
