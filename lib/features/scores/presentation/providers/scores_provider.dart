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

class UpcomingDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  }
}

class ResultsDate extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).subtract(const Duration(days: 1));
  }
}

final upcomingDateProvider =
    NotifierProvider<UpcomingDate, DateTime>(UpcomingDate.new);

final resultsDateProvider =
    NotifierProvider<ResultsDate, DateTime>(ResultsDate.new);

final upcomingMatchesProvider = FutureProvider<List<MatchModel>>((ref) {
  final day = ref.watch(upcomingDateProvider);
  return ref.watch(scoresRepositoryProvider).getUpcoming(day: day);
});

final resultsProvider = FutureProvider<List<MatchModel>>((ref) {
  final day = ref.watch(resultsDateProvider);
  return ref.watch(scoresRepositoryProvider).getResults(day: day);
});
