/// Simple in-memory rate limiter to prevent abuse on client-side actions
/// (like, vote, STK, share).
class RateLimiter {

  RateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 1),
  });
  final int maxAttempts;
  final Duration window;
  final Map<String, List<DateTime>> _attempts = {};

  /// Returns true if the action is allowed, false if rate-limited.
  bool allow(String key) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    final attempts = (_attempts[key] ?? [])
        .where((t) => t.isAfter(cutoff))
        .toList()
      ..add(now);
    _attempts[key] = attempts;

    // Evict old entries periodically
    if (_attempts.length > 100) {
      _attempts.removeWhere(
        (k, v) => v.isEmpty || v.last.isBefore(cutoff),
      );
    }

    return attempts.length <= maxAttempts;
  }

  /// How many attempts remain in the current window.
  int remaining(String key) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    final count =
        (_attempts[key] ?? []).where((t) => t.isAfter(cutoff)).length;
    return maxAttempts - count;
  }

  /// Resets the limiter for a key.
  void reset(String key) => _attempts.remove(key);
}

/// Global rate limiters for common actions.
final likeLimiter = RateLimiter(maxAttempts: 30, window: const Duration(minutes: 1));
final voteLimiter = RateLimiter(maxAttempts: 10, window: const Duration(minutes: 1));
final stkLimiter = RateLimiter(maxAttempts: 5, window: const Duration(minutes: 1));
final shareLimiter = RateLimiter(maxAttempts: 20, window: const Duration(minutes: 1));
final commentLimiter = RateLimiter(maxAttempts: 15, window: const Duration(minutes: 1));
