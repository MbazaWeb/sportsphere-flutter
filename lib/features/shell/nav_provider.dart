// ============================================================
// Cross-widget navigation providers
// ============================================================
// These providers exist so widgets that live OUTSIDE SportSphereShell
// (e.g. SpotlightCard in the home feed) can request a tab switch and an
// optional "scroll to this match" highlight on the Scores tab.
//
// Without these, the only way to switch tabs is to call setState on the
// private _SportSphereShellState — which is not exposed.
//
// Note: Riverpod 3.x deprecated StateProvider. We use Notifier /
// NotifierProvider (the recommended successor) instead.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the active tab inside SportSphereShell.
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) {
    if (index != state) state = index;
  }
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

/// When non-null, the Scores tab should scroll to / highlight the given
/// matchId. The Scores page consumes this on next build, scrolls the
/// relevant match card into view, and then clears it (sets it back to
/// null) so the highlight doesn't replay on every rebuild.
class PendingMatchNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;

  void clear() => state = null;
}

final pendingMatchIdProvider =
    NotifierProvider<PendingMatchNotifier, String?>(PendingMatchNotifier.new);
