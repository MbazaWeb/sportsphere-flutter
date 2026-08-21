import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_state.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AUTH REPOSITORY — Supabase only
// ══════════════════════════════════════════════════════════════════════════════
//
// Single source of truth for authentication. Uses Supabase Auth directly.
// Supabase manages session persistence internally — no TokenStore needed.
// The Dio ApiClient is kept for other REST calls, NOT used here.

class AuthRepository {
  const AuthRepository();

  static SupabaseClient get _sb => Supabase.instance.client;

  // ── Session helpers ────────────────────────────────────────────────────────

  Session? get currentSession => _sb.auth.currentSession;
  bool get hasSession => currentSession != null;

  // ── Hydrate (app start) ───────────────────────────────────────────────────

  /// Reads the persisted Supabase session and fetches the profile row.
  /// Returns null when no session exists → guest mode.
  Future<UserProfile?> hydrateProfile() async {
    final session = currentSession;
    if (session == null) return null;
    try {
      return await _fetchProfile(session.user.id);
    } catch (e) {
      debugPrint('[Auth] hydrateProfile error: $e');
      return _minimalProfile(session.user);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    // Accept handle or email — handle → email@sportsphere.test convention
    final clean = identifier.trim().toLowerCase().replaceAll('@', '');
    final email = clean.contains('.') || clean.contains('@')
        ? identifier.trim().toLowerCase()
        : '$clean@sportsphere.test';

    try {
      final res = await _sb.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) throw AuthException('Sign-in returned no user.');
      return await _fetchProfile(user.id);
    } on AuthException catch (e) {
      throw _friendly(e);
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<UserProfile> register({
    required String firstName,
    required String lastName,
    required String email,
    required String handle,
    required String country,
    required DateTime dob,
    required String password,
  }) async {
    try {
      final res = await _sb.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'handle': handle.trim().toLowerCase().replaceAll('@', ''),
          'role': 'fan',
        },
      );

      final user = res.user;
      if (user == null) {
        // Email confirmation required
        throw AuthException(
            'Check your email to confirm your account, then log in.');
      }

      final profileData = <String, dynamic>{
        'id': user.id,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim().toLowerCase(),
        'handle': handle.trim().toLowerCase().replaceAll('@', ''),
        'country': country,
        'dob': dob.toIso8601String().split('T').first,
        'role': 'fan',
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Upsert into User table (falls back to profiles)
      try {
        await _sb.from('User').upsert(profileData);
      } catch (_) {
        try {
          await _sb.from('profiles').upsert(profileData);
        } catch (e2) {
          debugPrint('[Auth] profile upsert failed: $e2');
        }
      }

      return UserProfile(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        handle: handle.trim().toLowerCase().replaceAll('@', ''),
        country: country,
        dob: dob,
        joinedDate: DateTime.now(),
        role: 'fan',
      );
    } on AuthException catch (e) {
      throw _friendly(e);
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _sb.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('[Auth] signOut error: $e');
    }
  }

  // ── Profile fetch ──────────────────────────────────────────────────────────

  Future<UserProfile> _fetchProfile(String uid) async {
    Map<String, dynamic>? row;
    try {
      row = await _sb.from('User').select().eq('id', uid).maybeSingle();
    } catch (_) {}
    try {
      row ??= await _sb.from('profiles').select().eq('id', uid).maybeSingle();
    } catch (_) {}

    if (row != null) return _rowToProfile(row);

    final user = _sb.auth.currentUser;
    if (user != null) return _minimalProfile(user);
    throw StateError('No profile found for uid $uid');
  }

  UserProfile _rowToProfile(Map<String, dynamic> r) {
    DateTime _d(Object? v, DateTime fb) =>
        v == null ? fb : (DateTime.tryParse(v.toString()) ?? fb);

    final first = (r['first_name'] as String?) ??
        (r['name'] as String?)?.split(' ').first ??
        '';
    final last = (r['last_name'] as String?) ??
        ((r['name'] as String?)?.split(' ').skip(1).join(' ') ?? '');

    return UserProfile(
      firstName: first,
      lastName: last,
      email: (r['email'] as String?) ?? '',
      handle: (r['handle'] as String?) ?? '',
      country: (r['country'] as String?) ?? '',
      dob: _d(r['dob'], DateTime(1990)),
      joinedDate: _d(r['createdAt'] ?? r['joinedDate'], DateTime.now()),
      role: (r['role'] as String?) ?? 'fan',
      avatarUrl: r['avatarUrl'] as String?,
      coverUrl: r['coverUrl'] as String?,
      isVerified: (r['isVerified'] as bool?) ?? false,
      bio: (r['bio'] as String?) ?? '',
      postCount: (r['postCount'] as int?) ?? 0,
      followerCount: (r['followerCount'] as int?) ?? 0,
      followingCount: (r['followingCount'] as int?) ?? 0,
    );
  }

  UserProfile _minimalProfile(User user) {
    final m = user.userMetadata ?? {};
    return UserProfile(
      firstName:
          (m['first_name'] as String?) ?? user.email?.split('@').first ?? 'User',
      lastName: (m['last_name'] as String?) ?? '',
      email: user.email ?? '',
      handle: (m['handle'] as String?) ??
          (user.email?.split('@').first ?? 'user'),
      country: (m['country'] as String?) ?? '',
      dob: DateTime(1990),
      joinedDate: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      role: (m['role'] as String?) ?? 'fan',
    );
  }


  Exception _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login') ||
        m.contains('invalid credentials') ||
        m.contains('email not confirmed')) {
      return Exception('Incorrect email or password.');
    }
    if (m.contains('already registered') || m.contains('already exists')) {
      return Exception(
          'An account with this email already exists. Try logging in.');
    }
    if (m.contains('rate limit')) {
      return Exception('Too many attempts. Please wait a moment.');
    }
    return Exception(e.message);
  }
}
