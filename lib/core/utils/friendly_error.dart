/// Maps technical exceptions to short, user-facing messages.
/// Never surfaces stack traces, Postgrest payloads, or console-style text.
///
/// CRITICAL RULE: A PostgREST (data query) failure must NEVER be classified
/// as an authentication/session failure. Only Supabase Auth itself can
/// establish that authentication is invalid.
library;

import 'package:flutter/foundation.dart' show debugPrint;

String friendlyError(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error == null) return fallback;

  // Prefer explicit user messages from our own types
  if (error is FriendlyException) return error.message;

  final raw = error.toString();
  final lower = raw.toLowerCase();

  // Data-access and auth problems from legacy Supabase code paths are handled
  // generically here. The app is now VPS-first, and these messages are kept
  // user-friendly without importing Supabase SDK types directly.
  final lowerDataChecks = lower;
  if (_matches(lowerDataChecks, const [
    'permission denied', 'row-level security', 'pgrst301', 'pgrst116',
    'already exists', 'duplicate key', 'service configuration error',
    'invalid login credentials', 'invalid_credentials', 'wrong password',
    'incorrect password', 'invalid email or password', 'user not found',
    'session expired', 'jwt', 'refresh_token', 'token is expired',
    'email not confirmed', 'email_not_confirmed', 'too many requests',
    'rate limit', 'weak_password', 'invalid email', 'unable to validate email',
  ])) {
    if (_matches(lowerDataChecks, const ['permission denied', 'row-level security'])) {
      return 'You don\'t have permission to access this content.';
    }
    if (_matches(lowerDataChecks, const ['session expired', 'jwt', 'refresh_token', 'token is expired'])) {
      return 'Your session has expired. Please sign in again.';
    }
    if (_matches(lowerDataChecks, const ['invalid login credentials', 'invalid_credentials', 'wrong password', 'incorrect password', 'invalid email or password', 'user not found'])) {
      return 'Incorrect email/username or password. Please try again.';
    }
    if (_matches(lowerDataChecks, const ['email not confirmed', 'email_not_confirmed'])) {
      return 'Please confirm your email before signing in.';
    }
    if (_matches(lowerDataChecks, const ['too many requests', 'rate limit'])) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (_matches(lowerDataChecks, const ['weak_password', 'password should be'])) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (_matches(lowerDataChecks, const ['invalid email', 'unable to validate email'])) {
      return 'Please enter a valid email address.';
    }
    if (_matches(lowerDataChecks, const ['already exists', 'duplicate key'])) {
      return 'This already exists.';
    }
    if (_matches(lowerDataChecks, const ['pgrst116'])) {
      return 'Data not found.';
    }
    return fallback;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ApiException — errors from our VPS API.
  // ═══════════════════════════════════════════════════════════════════════
  if (error.runtimeType.toString().contains('ApiException')) {
    // Pass through the message directly — it's already user-friendly
    final cleaned2 = raw
      .replaceFirst(RegExp(r'^ApiException\(\d+/[^)]*\):\s*'), '')
      .replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '')
      .trim();
    if (cleaned2.isNotEmpty && !cleaned2.contains('{') && cleaned2.length < 200) {
      return cleaned2;
    }
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
  const FriendlyException(this.message);
  final String message;

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

