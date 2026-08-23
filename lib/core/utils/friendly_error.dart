/// Maps technical exceptions to short, user-facing messages.
/// Never surfaces stack traces, Postgrest payloads, or console-style text.
///
/// CRITICAL RULE: A PostgREST (data query) failure must NEVER be classified
/// as an authentication/session failure. Only Supabase Auth itself can
/// establish that authentication is invalid.

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, AuthException;

String friendlyError(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error == null) return fallback;

  // Prefer explicit user messages from our own types
  if (error is FriendlyException) return error.message;

  final raw = error.toString();
  final lower = raw.toLowerCase();

  // ═══════════════════════════════════════════════════════════════════════
  // PostgrestException — data query errors from Supabase/PostgREST.
  // These must NEVER say "session expired" — they are DATA errors.
  // ═══════════════════════════════════════════════════════════════════════
  if (error is PostgrestException) {
    final status = error.statusCode;
    final code = error.code;
    final msg = (error.message ?? '').toLowerCase();

    // 403 = RLS / permission denied
    if (status == 403 || msg.contains('permission denied') || msg.contains('row-level security')) {
      return 'You don\'t have permission to access this content.';
    }

    // 401 from PostgREST = the attached JWT is invalid for this query.
    // This is a DATA-ACCESS issue, not a user session expiry. Do NOT tell
    // the user to sign in again — they may be a guest viewing public data.
    if (status == 401 || code == 'PGRST301') {
      return 'Could not load data. Pull down to retry.';
    }

    // 406 = no rows returned (e.g. .single() expected exactly one row)
    if (status == 406 || code == 'PGRST116') {
      return 'Data not found.';
    }

    // 42P01 = undefined table / column
    if (code == '42P01' || code == '42703') {
      return 'Service configuration error.';
    }

    // 23505 = unique constraint violation
    if (code == '23505') {
      return 'This already exists.';
    }

    // Network / connectivity inside PostgREST layer
    if (_matches(lower, const [
      'socketexception', 'failed host lookup', 'network is unreachable',
      'connection refused', 'connection reset', 'connection timed out',
    ])) {
      return 'No internet connection. Check your network and try again.';
    }

    debugPrintFriendly('[DATA]', error, status, code);
    return fallback;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AuthException — errors from Supabase Auth ONLY.
  // Only Auth can establish that authentication is invalid.
  // ═══════════════════════════════════════════════════════════════════════
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    final authMsg = (error.message ?? '').toLowerCase();

    // Invalid credentials
    if (_matches(authMsg, const [
      'invalid login credentials', 'invalid_credentials', 'wrong password',
      'incorrect password', 'invalid email or password', 'user not found',
      'invalid_grant',
    ])) {
      return 'Incorrect email/username or password. Please try again.';
    }

    // Email not confirmed
    if (_matches(authMsg, const ['email not confirmed', 'email_not_confirmed'])) {
      return 'Please confirm your email before signing in.';
    }

    // Rate limited
    if (_matches(authMsg, const [
      'email rate limit', 'over_email_send_rate_limit', 'too many requests', 'rate limit',
    ])) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // Duplicate user
    if (_matches(authMsg, const [
      'user already registered', 'already registered', 'email address is already',
      'duplicate key', 'already exists',
    ])) {
      return 'An account with this email already exists. Try signing in.';
    }

    // Weak password
    if (_matches(authMsg, const ['password should be', 'password is too weak', 'weak_password'])) {
      return 'Password is too weak. Use at least 6 characters.';
    }

    // Invalid email format
    if (_matches(authMsg, const ['invalid email', 'unable to validate email'])) {
      return 'Please enter a valid email address.';
    }

    // Session expiry — ONLY from AuthException
    if (_matches(authMsg, const ['session', 'jwt', 'refresh_token', 'token is expired', 'expired'])) {
      return 'Your session has expired. Please sign in again.';
    }

    debugPrintFriendly('[AUTH]', error, null, null);
    return 'Authentication error. Please try again.';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Generic / unknown error types — use keyword matching.
  // ═══════════════════════════════════════════════════════════════════════

  // Network / connectivity
  if (_matches(lower, const [
    'socketexception', 'failed host lookup', 'network is unreachable',
    'network_error', 'clientexception', 'connection refused',
    'connection reset', 'connection closed', 'connection timed out',
    'timed out', 'timeout', 'handshakeexception', 'xmlhttprequest',
    'failed to fetch', 'no internet', 'offline',
    'errno = 7', 'errno = 101', 'errno = 111',
  ])) {
    return 'No internet connection. Check your network and try again.';
  }

  // Server errors
  if (_matches(lower, const [
    '500', '502', '503', 'internal server', 'service unavailable',
  ])) {
    return 'Server is temporarily unavailable. Please try again shortly.';
  }

  // StateError from our code (e.g. "Sign in to like")
  if (error is StateError) {
    final msg = error.message;
    if (msg.contains('Sign in') || msg.contains('sign in') || msg.contains('Please sign')) {
      return msg;
    }
    if (msg.contains('required')) return msg;
  }

  // ArgumentError from our code
  if (error is ArgumentError) {
    return error.message.isNotEmpty ? error.message : 'Invalid input.';
  }

  // Strip common technical prefixes if message still looks human
  final cleaned = raw
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

// ── Internal debug logging ─────────────────────────────────────────────────

void debugPrintFriendly(String tag, Object error, int? status, String? code) {
  // Only in debug mode — never in release.
  assert(() {
    final buf = StringBuffer(tag);
    if (status != null) buf.write(' status=$status');
    if (code != null) buf.write(' code=$code');
    buf.write(' ${error.runtimeType}: $error');
    debugPrint(buf.toString());
    return true;
  }());
}

// Re-export for convenience
import 'package:flutter/foundation.dart' show debugPrint;