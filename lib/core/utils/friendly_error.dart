/// Maps technical exceptions to short, user-facing messages.
/// Never surfaces stack traces, Postgrest payloads, or console-style text.
String friendlyError(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error == null) return fallback;

  // Prefer explicit user messages from our own types
  if (error is FriendlyException) return error.message;

  final raw = error.toString();
  final lower = raw.toLowerCase();

  // ── Network / connectivity ───────────────────────────────────────────────
  if (_matches(lower, const [
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'network_error',
    'clientexception',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'timed out',
    'timeout',
    'handshakeexception',
    'xmlhttprequest',
    'failed to fetch',
    'no internet',
    'offline',
    'errno = 7',
    'errno = 101',
    'errno = 111',
  ])) {
    return 'No internet connection. Check your network and try again.';
  }

  // ── Auth: wrong password / user ──────────────────────────────────────────
  // M7 — Removed the duplicate 'email not confirmed' needle from this list.
  // The "Please confirm your email" message is owned by the dedicated block
  // below (`'email not confirmed'`, `'email_not_confirmed'`). Keeping it in
  // this list too caused the wrong copy ("Incorrect email/username or
  // password") to surface when a user tried to sign in before confirming.
  if (_matches(lower, const [
    'invalid login credentials',
    'invalid_credentials',
    'wrong password',
    'incorrect password',
    'invalid email or password',
    'user not found',
    'invalid_grant',
  ])) {
    return 'Incorrect email/username or password. Please try again.';
  }

  if (_matches(lower, const [
    'email rate limit',
    'over_email_send_rate_limit',
    'too many requests',
    'rate limit',
  ])) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  if (_matches(lower, const [
    'user already registered',
    'already registered',
    'email address is already',
    'duplicate key',
    'already exists',
  ])) {
    return 'An account with this email already exists. Try signing in.';
  }

  if (_matches(lower, const [
    'password should be',
    'password is too weak',
    'weak_password',
  ])) {
    return 'Password is too weak. Use at least 6 characters.';
  }

  if (_matches(lower, const [
    'email not confirmed',
    'email_not_confirmed',
  ])) {
    return 'Please confirm your email before signing in.';
  }

  if (_matches(lower, const [
    'invalid email',
    'unable to validate email',
  ])) {
    return 'Please enter a valid email address.';
  }

  if (_matches(lower, const [
    'session',
    'jwt',
    'refresh_token',
    'not authenticated',
    'unauthorized',
    '401',
  ])) {
    return 'Your session expired. Please sign in again.';
  }

  // ── Permission / server ──────────────────────────────────────────────────
  if (_matches(lower, const [
    'permission denied',
    'row-level security',
    'rls',
    '403',
    'forbidden',
  ])) {
    return 'You don’t have permission to do that.';
  }

  if (_matches(lower, const [
    '500',
    '502',
    '503',
    'internal server',
    'service unavailable',
  ])) {
    return 'Server is temporarily unavailable. Please try again shortly.';
  }

  // Strip common technical prefixes if message still looks human
  var cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '')
      .replaceFirst(RegExp(r'^AuthException\(.*?\):\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException\(.*?\):\s*'), '')
      .replaceFirst(RegExp(r'^AuthRetryableFetchException:\s*'), '')
      .trim();

  // If it still looks like a stack / JSON / code dump, use fallback
  if (cleaned.contains('\n') ||
      cleaned.contains('{') ||
      cleaned.contains('at ') ||
      cleaned.length > 140 ||
      RegExp(r'^[A-Z][a-zA-Z]+Exception').hasMatch(cleaned)) {
    return fallback;
  }

  if (cleaned.isEmpty) return fallback;
  return cleaned;
}

bool _matches(String lower, List<String> needles) {
  for (final n in needles) {
    if (lower.contains(n)) return true;
  }
  return false;
}

/// Exception that already carries a safe user message.
class FriendlyException implements Exception {
  final String message;
  const FriendlyException(this.message);

  @override
  String toString() => message;
}
