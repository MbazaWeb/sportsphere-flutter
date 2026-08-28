// lib/features/auth/data/auth_repository.dart
// All auth via VPS API — JWT stored locally, no Supabase SDK dependency.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/data/vps_repository.dart';
import '../domain/auth_state.dart';

class AuthRepository {
  const AuthRepository();

  static final _vps = VpsRepository();

  static const _kToken        = 'auth_access_token';
  static const _kRefresh      = 'auth_refresh_token';
  static const _kUserJson     = 'auth_user_json';

  // ── Session ────────────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  Future<bool> get hasSession async => (await getToken()) != null;

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token   = data['token']        as String?;
    final refresh = data['refreshToken'] as String?;
    if (token   != null) await prefs.setString(_kToken,   token);
    if (refresh != null) await prefs.setString(_kRefresh, refresh);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUserJson);
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
    String? avatarUrl,
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
