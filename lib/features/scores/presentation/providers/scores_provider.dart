import '../../../../core/realtime/soketi_service.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/live_scores.dart';
import '../../data/scores_repository.dart';
import '../../domain/models/match_model.dart';

final scoresRepositoryProvider = Provider<ScoresRepository>(
  (_) => const ScoresRepository(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Realtime — ONE shared channel for the whole feature.
// ─────────────────────────────────────────────────────────────────────────────
//
// Previously both [ScoresPage] (in `scores_page.dart`) and this file opened
// their own `public."Match"` channels (`scores-match-live` and `public-match`).
// We now keep a single channel named `scores-realtime`; [ScoresPage] just
// watches [matchRealtimeTickProvider] instead of subscribing on its own.
//
// Every time a Match row changes (insert/update/delete) we bump a counter so
// any provider that calls `ref.watch(matchRealtimeTickProvider)` re-fetches.
// Realtime via Soketi WebSocket with 20s polling fallback
final matchRealtimeTickProvider = StreamProvider<int>((ref) {
  final controller = StreamController<int>.broadcast();
  var n = 0;
  controller.add(n);

  // Soketi stream — fires instantly on match.updated events
  StreamSubscription<Map<String, dynamic>>? soketiSub;
  try {
    soketiSub = SoketiService.instance.matchUpdates.listen((_) {
      n += 1;
      if (!controller.isClosed) controller.add(n);
    });
  } catch (_) {}

  // Polling fallback — every 20s regardless of Soketi status
  final timer = Timer.periodic(const Duration(seconds: 20), (_) {
    n += 1;
    if (!controller.isClosed) controller.add(n);
  });

  ref.onDispose(() {
    soketiSub?.cancel();
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

// ─────────────────────────────────────────────────────────────────────────────
// Day-rollover — invalidates `todayMatchesProvider` at local midnight so a
// long-lived ScoresPage tab doesn't show "yesterday's today" after midnight.
// ─────────────────────────────────────────────────────────────────────────────
class TodayDay extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    _scheduleRollover(today);
    ref.onDispose(() => _timer?.cancel());
    return today;
  }

  void _scheduleRollover(DateTime currentDay) {
    _timer?.cancel();
    final next = currentDay.add(const Duration(days: 1));
    final delay = next.difference(DateTime.now());
    // The timer is cancelled in `ref.onDispose`, so when this callback fires
    // the notifier is guaranteed to still be alive.
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      final n = DateTime.now();
      state = DateTime(n.year, n.month, n.day);
      _scheduleRollover(state);
    });
  }
}

final todayDayProvider =
    NotifierProvider<TodayDay, DateTime>(TodayDay.new);

// ─────────────────────────────────────────────────────────────────────────────
// Date notifiers used by Upcoming / Results tabs.
// ─────────────────────────────────────────────────────────────────────────────

/// Common base for date-picker notifiers so callers can hold a
/// `NotifierProvider<DateNotifier, DateTime>` reference and call `update()`
/// without knowing the concrete subclass.
abstract class DateNotifier extends Notifier<DateTime> {
  void update(DateTime d) => state = d;
}

class UpcomingDate extends DateNotifier {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  }
}

class ResultsDate extends DateNotifier {
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

// ─────────────────────────────────────────────────────────────────────────────
// Source — single deduped list of matches for the local filters.
// ─────────────────────────────────────────────────────────────────────────────
//
// The previous implementation concatenated [getLive] + [getToday] +
// [getUpcoming] + [getResults] with no dedupe, so the same match appeared
// multiple times across tabs. We now dedupe by `id`.
Future<List<MatchModel>> _source() async {
  try {
    return await fetchLiveMatches();
  } catch (_) {
    const repo = ScoresRepository();
    // M16 — The previous implementation awaited the four queries one after
    // another. They're independent reads against the same table, so run
    // them in parallel via Future.wait — this collapses ~4× RTT into ~1×.
    final results = await Future.wait([
      repo.getLive(),
      repo.getToday(),
      repo.getUpcoming(),
      repo.getResults(),
    ]);
    final a = results[0];
    final b = results[1];
    final c = results[2];
    final d = results[3];
    final seen = <String>{};
    final out = <MatchModel>[];
    for (final m in [...a, ...b, ...c, ...d]) {
      if (seen.add(m.id)) out.add(m);
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab providers — each watches the realtime tick so they refresh on row
// changes. They use [NotifierProvider] (not autoDispose) so the channel
// stays alive while the ScoresPage is mounted.
// ─────────────────────────────────────────────────────────────────────────────
final liveMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  ref.watch(matchRealtimeTickProvider);
  return filterLive(await _source());
});

final todayMatchesProvider = FutureProvider<List<MatchModel>>((ref) async {
  ref.watch(matchRealtimeTickProvider);
  final today = ref.watch(todayDayProvider);
  return filterDay(await _source(), today);
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
