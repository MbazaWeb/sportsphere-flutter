import 'dart:typed_data';
import 'dart:convert';
// lib/features/auth/data/auth_repository.dart
// All auth via VPS API — JWT stored locally, no Supabase SDK dependency.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/data/vps_repository.dart';
import '../domain/auth_state.dart';

/// Lightweight session stub exposing the fields the UI reads
/// synchronously (`accessToken` + `user.id`). Backed by an in-memory
/// cache populated by [AuthRepository._saveSession] /
/// [AuthRepository.hydrateProfile]. Returns `null` when no session
/// has been observed yet (e.g. fresh install, before login completes).
class _AuthSessionStub {
  final String? accessToken;
  final String? userId;
  const _AuthSessionStub({this.accessToken, this.userId});

  /// Mirrors `supabase.auth.currentSession.user.id` — used by callers
  /// that need the authenticated user's id without awaiting prefs.
  _AuthUserStub? get user =>
      userId == null ? null : _AuthUserStub(id: userId);
}

class _AuthUserStub {
  final String? id;
  const _AuthUserStub({this.id});
}

class AuthRepository {
  const AuthRepository();

  static final _vps = const VpsRepository();

  static const _kToken        = 'auth_access_token';
  static const _kRefresh      = 'auth_refresh_token';
  static const _kUserJson     = 'auth_user_json';
  // Also persisted to SharedPreferences so other repositories (e.g.
  // SocialRepository._getUid) can resolve the current uid without
  // decoding the JWT.
  static const _kUserId       = 'auth_user_id';

  // ── In-memory cache ───────────────────────────────────────────────────────
  // Populated by [_saveSession] / [hydrateProfile] / [getToken] so the UI
  // layer can read the access token + user id synchronously.
  static String? _cachedToken;
  static String? _cachedUserId;

  /// Synchronous session stub — used by `auth_controller.dart` to populate
  /// `AuthState.token` and `AuthState.user.id` without awaiting prefs.
  /// Returns `null` until a session has been observed (via [login],
  /// [register], [refreshToken], or [hydrateProfile]).
  _AuthSessionStub? get currentSession {
    if (_cachedToken == null && _cachedUserId == null) return null;
    return _AuthSessionStub(accessToken: _cachedToken, userId: _cachedUserId);
  }

  // ── Session ────────────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    await _loadCachedSession();
    return _cachedToken;
  }

  Future<bool> get hasSession async => (await getToken()) != null;

  /// Populate the in-memory cache from SharedPreferences (lazy, idempotent).
  Future<void> _loadCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken ??= prefs.getString(_kToken);
      _cachedUserId ??= prefs.getString(_kUserId);
    } catch (e) {
      debugPrint('[AUTH] _loadCachedSession: $e');
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token   = data['token']        as String?;
    final refresh = data['refreshToken'] as String?;
    final userId  = _extractUserId(data);
    if (token   != null) {
      await prefs.setString(_kToken, token);
      _cachedToken = token;
    }
    if (refresh != null) await prefs.setString(_kRefresh, refresh);
    if (userId  != null) {
      await prefs.setString(_kUserId, userId);
      _cachedUserId = userId;
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUserJson);
    await prefs.remove(_kUserId);
    _cachedToken = null;
    _cachedUserId = null;
  }

  /// Extract the user id from a VPS auth response.
  /// `login`/`register`/`refreshToken` wrap the user inside `data['user']`,
  /// while `getMe` returns the user map directly — handle both shapes.
  String? _extractUserId(Map<String, dynamic> data) {
    final u = (data['user'] as Map<String, dynamic>?) ?? data;
    final id = u['id'] ?? u['userId'] ?? u['user_id'];
    return id?.toString();
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    final isEmail = identifier.contains('@');
    final data = await _vps.login(
      email:    isEmail ? identifier.trim().toLowerCase() : null,
      handle:   isEmail ? null : identifier.trim().replaceAll('@', ''),
      password: password,
    );
    await _saveSession(data);
    return _profileFrom(data);
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
    List<String> favTeamIds = const [],
    String? avatarUrl,  // data URI (base64) OR null
  }) async {
    if (password.isEmpty) throw ArgumentError('Password is required');

    final data = await _vps.register(
      email:     email,
      password:  password,
      firstName: firstName,
      lastName:  lastName,
      handle:    handle,
      country:   country,
      dob:       dob.toIso8601String(),
      role:      'fan',
    );
    await _saveSession(data);

    // Upload avatar AFTER session saved — now we have a JWT
    if (avatarUrl != null && avatarUrl.startsWith('data:')) {
      try {
        final comma = avatarUrl.indexOf(',');
        if (comma >= 0) {
          final bytes = base64Decode(avatarUrl.substring(comma + 1));
          final ext   = avatarUrl.contains('image/png') ? 'png' : 'jpg';
          final cdnUrl = await _vps.uploadAvatarBytes(bytes, ext: ext);
          // Patch profile with real CDN URL
          await _vps.updateProfile({'avatar_url': cdnUrl});
          // Return updated profile with avatar
          final profile = _profileFrom(data);
          return profile.copyWith(avatarUrl: cdnUrl);
        }
      } catch (e) {
        debugPrint('[AUTH] avatar upload after register: \$e');
        // Non-fatal — user can upload avatar later
      }
    }

    return _profileFrom(data);
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try { await _vps.logout(); } catch (_) {}
    await _clearSession();
  }

  Future<void> signOutLocal() async => _clearSession();

  // ── Hydrate profile ────────────────────────────────────────────────────────
  Future<UserProfile?> hydrateProfile() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final data = await _vps.getMe();
      // getMe returns the user map directly — cache the user id so
      // `currentSession?.user.id` resolves without another trip.
      final userId = _extractUserId(data);
      if (userId != null) {
        _cachedUserId = userId;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kUserId, userId);
        } catch (e) {
          debugPrint('[AUTH] hydrateProfile: persist userId failed: $e');
        }
      }
      return _profileFrom(data);
    } catch (e) {
      debugPrint('[AUTH] hydrateProfile failed: $e');
      return null;
    }
  }

  Future<UserProfile?> refreshProfile() => hydrateProfile();

  // ── Update profile ─────────────────────────────────────────────────────────
  Future<UserProfile?> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? handle,
    String? country,
    String? bio,
    DateTime? dateOfBirth,
    String? avatarUrl,
    String? coverUrl,
    String? themeColor,
  }) async {
    await _vps.patch<Map<String, dynamic>>('/v1/auth/profile', data: {
      if (firstName   != null) 'firstName':   firstName,
      if (lastName    != null) 'lastName':    lastName,
      if (handle      != null) 'handle':      handle,
      if (country     != null) 'country':     country,
      if (bio         != null) 'bio':         bio,
      if (dateOfBirth != null) 'dob':         dateOfBirth.toIso8601String(),
      if (avatarUrl   != null) 'avatarUrl':   avatarUrl,
      if (coverUrl    != null) 'coverUrl':    coverUrl,
      if (themeColor  != null) 'themeColor':  themeColor,
    });
    return hydrateProfile();
  }

  // ── Password ───────────────────────────────────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) throw ArgumentError('Current password is required');
    if (newPassword.isEmpty)     throw ArgumentError('New password is required');
    await _vps.changePassword(
      currentPassword: currentPassword,
      newPassword:     newPassword,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _vps.forgotPassword(email);
  }

  Future<void> resendConfirmation(String email) async {
    await _vps.post<void>('/v1/auth/resend-confirmation',
        data: {'email': email.trim().toLowerCase()});
  }

  // ── Token refresh ──────────────────────────────────────────────────────────
  Future<void> refreshToken() async {
    final prefs   = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_kRefresh);
    if (refresh == null) return;
    try {
      final data = await _vps.refreshToken(refresh);
      await _saveSession(data);
    } catch (e) {
      debugPrint('[AUTH] refreshToken failed: $e');
      await _clearSession();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  UserProfile _profileFrom(Map<String, dynamic> data) {
    final u = (data['user'] as Map<String, dynamic>?) ?? data;
    return UserProfile(
      firstName:     (u['firstName']  ?? u['first_name']  ?? '') as String,
      lastName:      (u['lastName']   ?? u['last_name']   ?? '') as String,
      email:         (u['email']      ?? '') as String,
      handle:        (u['handle']     ?? '') as String,
      country:       (u['country']    ?? '') as String,
      dob:           DateTime.tryParse((u['dob'] ?? '').toString()) ?? DateTime.now(),
      joinedDate:    DateTime.tryParse((u['createdAt'] ?? u['created_at'] ?? '').toString()) ?? DateTime.now(),
      role:          (u['role']       ?? 'fan') as String,
      avatarUrl:     u['avatarUrl']   ?? u['avatar_url'],
      coverUrl:      u['coverUrl']    ?? u['cover_url'],
      isVerified:    (u['isVerified'] ?? u['is_verified'] ?? false) as bool,
      themeColor:    (u['themeColor'] ?? u['theme_color'] ?? '#168CFF') as String,
      bio:           (u['bio']        ?? '') as String,
      createdAt:     DateTime.tryParse((u['createdAt'] ?? u['created_at'] ?? '').toString()),
      postCount:     (u['postCount']      ?? u['post_count']      ?? 0) as int,
      followerCount: (u['followerCount']  ?? u['follower_count']  ?? 0) as int,
      followingCount:(u['followingCount'] ?? u['following_count'] ?? 0) as int,
    );
  }
}
