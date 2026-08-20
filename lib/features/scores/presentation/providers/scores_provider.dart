import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/live_scores.dart';
import '../../data/scores_repository.dart';
import '../../domain/models/match_model.dart';

final scoresRepositoryProvider = Provider<ScoresRepository>(
  (_) => const ScoresRepository(),
);

/// Increments whenever a Match row changes (websocket).
final matchRealtimeTickProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>();
  var n = 0;
  controller.add(n);
  final channel = Supabase.instance.client
      .channel('public-match')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'Match',
        callback: (_) {
          n += 1;
          controller.add(n);
        },
      )
      .subscribe();
  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

Future<List<MatchModel>> _source() async {
  try {
    return await fetchLiveMatches();
  } catch (_) {
    final repo = const ScoresRepository();
    final a = await repo.getLive();
    final b = await repo.getToday();
    final c = await repo.getUpcoming();
    final d = await repo.getResults();
    return [...a, ...b, ...c, ...d];
  }
}

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

final liveMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  ref.watch(matchRealtimeTickProvider);
  return filterLive(await _source());
});

final todayMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  ref.watch(matchRealtimeTickProvider);
  return filterDay(await _source(), DateTime.now());
});

final upcomingMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  ref.watch(matchRealtimeTickProvider);
  final day = ref.watch(upcomingDateProvider);
  return filterUpcoming(await _source(), day);
});

final resultsProvider = FutureProvider<List<MatchModel>>((ref) async {
  ref.watch(matchRealtimeTickProvider);
  final day = ref.watch(resultsDateProvider);
  return filterResults(await _source(), day);
});
