import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_state.dart';

/// Auth + identity. Always keeps `profiles` and public."User" in sync.
class AuthRepository {
  AuthRepository();

  SupabaseClient get _sb => Supabase.instance.client;

  Session? get currentSession => _sb.auth.currentSession;

  Future<String?> currentToken() async => currentSession?.accessToken;

  Future<void> signOut() async {
    await _sb.auth.signOut();
  }

  Future<void> clearLocalSession() async {
    try {
      await _sb.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('auth clearLocalSession: $e');
    }
  }

  Future<UserProfile?> currentProfile() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    try {
      await syncIdentity();
      return await _profileById(user.id);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('401') ||
          msg.contains('jwt') ||
          msg.contains('unauthorized')) {
        await clearLocalSession();
        return null;
      }
      rethrow;
    }
  }

  /// Idempotent: create/update both `profiles` and `User` from Auth + metadata.
  Future<void> syncIdentity({
    String? firstName,
    String? lastName,
    String? handle,
    String? country,
    String? dobIso,
    String? bio,
    String? role,
    String? avatarUrl,
    String? coverUrl,
    String? themeColor,
  }) async {
    final u = _sb.auth.currentUser;
    if (u == null) return;

    final meta = u.userMetadata ?? {};
    final existing = await _profileById(u.id);

    final cleanHandle = (handle ??
            existing?.handle ??
            meta['handle'] as String? ??
            u.id.replaceAll('-', '').substring(0, 10))
        .trim()
        .toLowerCase()
        .replaceAll('@', '');

    final fn = (firstName ??
            existing?.firstName ??
            meta['first_name'] as String? ??
            '')
        .trim();
    final ln = (lastName ??
            existing?.lastName ??
            meta['last_name'] as String? ??
            '')
        .trim();
    final display = ('$fn $ln').trim();
    final email = (u.email ?? existing?.email ?? '${u.id}@users.local')
        .trim()
        .toLowerCase();
    final roleVal =
        (role ?? existing?.role ?? meta['role'] as String? ?? 'fan').trim();
    final countryVal = (country ??
            existing?.country ??
            meta['country'] as String? ??
            '')
        .trim();
    final dob = dobIso ??
        existing?.dob.toIso8601String().split('T').first ??
        meta['dob'] as String?;
    final bioVal = bio ?? existing?.bio ?? '';
    final initials = (
      (fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '')
    ).toUpperCase();
    final verified = u.emailConfirmedAt != null;

    // 1) profiles
    try {
      await _sb.from('profiles').upsert({
        'id': u.id,
        'handle': cleanHandle,
        'role': roleVal,
        'first_name': fn,
        'last_name': ln,
        'email': email,
        if (countryVal.isNotEmpty) 'country': countryVal,
        if (dob != null) 'dob': dob,
        'bio': bioVal,
        if (avatarUrl != null || existing?.avatarUrl != null)
          'avatar_url': avatarUrl ?? existing?.avatarUrl,
        if (coverUrl != null || existing?.coverUrl != null)
          'cover_url': coverUrl ?? existing?.coverUrl,
        if (themeColor != null || existing?.themeColor != null)
          'theme_color': themeColor ?? existing?.themeColor,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('auth profiles upsert: $e');
    }

    // 2) public."User" (social FKs)
    try {
      await _sb.from('User').upsert({
        'id': u.id,
        'name': display.isEmpty ? cleanHandle : display,
        'email': email,
        'handle': cleanHandle,
        'role': roleVal,
        'bio': bioVal,
        'isVerified': verified,
        'verificationStatus': verified ? 'verified' : 'none',
        if (countryVal.isNotEmpty) 'currentCountry': countryVal,
        if (countryVal.isNotEmpty) 'countryOfOrigin': countryVal,
        if (dob != null) 'dateOfBirth': dob,
        'avatarInitials': initials.isEmpty ? 'SS' : initials,
        if (avatarUrl != null || existing?.avatarUrl != null)
          'avatarUrl': avatarUrl ?? existing?.avatarUrl,
        if (coverUrl != null || existing?.coverUrl != null)
          'coverUrl': coverUrl ?? existing?.coverUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('auth User upsert: $e');
    }
  }

  /// Backward-compatible alias.
  Future<void> ensureUserRow() => syncIdentity();

  Future<void> sendPasswordReset(String emailOrHandle) async {
    final email = await _resolveEmail(emailOrHandle);
    await _sb.auth.resetPasswordForEmail(email);
  }

  /// In-app password change (user must be signed in).
  Future<void> changePassword({
    required String newPassword,
  }) async {
    final u = _sb.auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    if (newPassword.trim().length < 6) {
      throw StateError('Password must be at least 6 characters');
    }
    await _sb.auth.updateUser(UserAttributes(password: newPassword.trim()));
  }

  /// Resend signup confirmation email.
  Future<void> resendConfirmation(String emailOrHandle) async {
    final email = await _resolveEmail(emailOrHandle);
    await _sb.auth.resend(type: OtpType.signup, email: email);
  }

  /// Result: session present, or needs email confirmation.
  Future<RegisterResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String handle,
    required String country,
    required DateTime dob,
    required String password,
  }) async {
    final cleanHandle = handle.trim().toLowerCase().replaceAll('@', '');
    if (cleanHandle.length < 3) {
      throw StateError('Handle must be at least 3 characters');
    }

    final takenProfile = await _sb
        .from('profiles')
        .select('id')
        .eq('handle', cleanHandle)
        .maybeSingle();
    if (takenProfile != null) {
      throw StateError('That handle is already taken');
    }
    try {
      final takenUser = await _sb
          .from('User')
          .select('id')
          .eq('handle', cleanHandle)
          .maybeSingle();
      if (takenUser != null) {
        throw StateError('That handle is already taken');
      }
    } catch (e) {
      if (e.toString().contains('taken')) rethrow;
      debugPrint('auth handle check User: $e');
    }

    final dobIso = dob.toIso8601String().split('T').first;
    final res = await _sb.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'handle': cleanHandle,
        'role': 'fan',
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'country': country,
        'dob': dobIso,
      },
    );
    final user = res.user;
    if (user == null) {
      throw StateError('Register failed');
    }

    // Prefer session path so RLS allows inserts.
    if (res.session != null) {
      await syncIdentity(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        handle: cleanHandle,
        country: country,
        dobIso: dobIso,
        role: 'fan',
        bio: '',
      );
      return RegisterResult.authenticated;
    }

    // No session (email confirm required) — best-effort identity write may fail RLS.
    try {
      await _sb.from('profiles').upsert({
        'id': user.id,
        'handle': cleanHandle,
        'role': 'fan',
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim().toLowerCase(),
        'country': country,
        'dob': dobIso,
        'bio': '',
      });
    } catch (e) {
      debugPrint('auth register profiles pre-confirm: $e');
    }
    return RegisterResult.needsEmailConfirmation;
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final email = await _resolveEmail(identifier);
    final res = await _sb.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) {
      throw StateError('Login failed');
    }
    await syncIdentity();
  }

  Future<UserProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String handle,
    required String country,
    required DateTime dob,
    String bio = '',
    String? avatarUrl,
    String? coverUrl,
    String? themeColor,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final cleanHandle = handle.trim().toLowerCase().replaceAll('@', '');
    final clash = await _sb
        .from('profiles')
        .select('id')
        .eq('handle', cleanHandle)
        .neq('id', user.id)
        .maybeSingle();
    if (clash != null) {
      throw StateError('That handle is already taken');
    }
    try {
      final clashU = await _sb
          .from('User')
          .select('id')
          .eq('handle', cleanHandle)
          .neq('id', user.id)
          .maybeSingle();
      if (clashU != null) {
        throw StateError('That handle is already taken');
      }
    } catch (e) {
      if (e.toString().contains('taken')) rethrow;
    }

    final dobIso = dob.toIso8601String().split('T').first;
    await syncIdentity(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      handle: cleanHandle,
      country: country,
      dobIso: dobIso,
      bio: bio.trim(),
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      themeColor: themeColor,
    );

    // Keep Auth metadata aligned
    try {
      await _sb.auth.updateUser(
        UserAttributes(
          data: {
            'handle': cleanHandle,
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'country': country,
            'dob': dobIso,
          },
        ),
      );
    } catch (e) {
      debugPrint('auth metadata update: $e');
    }

    final profile = await _profileById(user.id);
    if (profile == null) {
      throw StateError('Profile missing after update');
    }
    return profile;
  }

  Future<String> _resolveEmail(String identifier) async {
    final raw = identifier.trim();
    if (raw.contains('@') && raw.contains('.') && !raw.startsWith('@')) {
      return raw.toLowerCase();
    }
    final handle = raw.toLowerCase().replaceAll('@', '');
    try {
      final row = await _sb
          .from('profiles')
          .select('email')
          .eq('handle', handle)
          .maybeSingle();
      final email = row?['email'] as String?;
      if (email != null && email.contains('@')) return email.toLowerCase();
    } catch (e) {
      debugPrint('auth resolve profiles: $e');
    }
    try {
      final row = await _sb
          .from('User')
          .select('email')
          .eq('handle', handle)
          .maybeSingle();
      final email = row?['email'] as String?;
      if (email != null && email.contains('@')) return email.toLowerCase();
    } catch (e) {
      debugPrint('auth resolve User: $e');
    }
    throw StateError('Unknown handle');
  }

  Future<UserProfile?> _profileById(String id) async {
    Map<String, dynamic>? row;
    try {
      final p = await _sb.from('profiles').select().eq('id', id).maybeSingle();
      if (p != null) row = Map<String, dynamic>.from(p);
    } catch (e) {
      debugPrint('auth _profileById profiles: $e');
    }

    Map<String, dynamic>? urow;
    try {
      final u = await _sb.from('User').select().eq('id', id).maybeSingle();
      if (u != null) urow = Map<String, dynamic>.from(u);
    } catch (e) {
      debugPrint('auth _profileById User: $e');
    }

    if (row == null && urow == null) {
      final au = _sb.auth.currentUser;
      if (au == null || au.id != id) return null;
      final meta = au.userMetadata ?? {};
      return UserProfile(
        firstName: meta['first_name'] as String? ?? '',
        lastName: meta['last_name'] as String? ?? '',
        email: au.email ?? '',
        handle: meta['handle'] as String? ?? '',
        country: meta['country'] as String? ?? '',
        dob: DateTime.tryParse(meta['dob'] as String? ?? '') ??
            DateTime(2000, 1, 1),
        role: meta['role'] as String? ?? 'fan',
        isVerified: au.emailConfirmedAt != null,
        createdAt: au.createdAt,
      );
    }

    final first = (row?['first_name'] as String?) ??
        _splitName(urow?['name'] as String?).$1;
    final last = (row?['last_name'] as String?) ??
        _splitName(urow?['name'] as String?).$2;
    final email = (row?['email'] as String?) ??
        (urow?['email'] as String?) ??
        _sb.auth.currentUser?.email ??
        '';
    final handle = (row?['handle'] as String?) ??
        (urow?['handle'] as String?) ??
        '';
    final country = (row?['country'] as String?) ??
        (urow?['currentCountry'] as String?) ??
        '';
    final dobRaw = row?['dob'] ?? urow?['dateOfBirth'];
    final dob = DateTime.tryParse('$dobRaw') ?? DateTime(2000, 1, 1);
    final role =
        (row?['role'] as String?) ?? (urow?['role'] as String?) ?? 'fan';
    final authVerified = _sb.auth.currentUser?.emailConfirmedAt != null;
    final isVerified = authVerified ||
        (urow?['isVerified'] as bool?) == true ||
        (row?['is_verified'] as bool?) == true;

    // Count fields: prefer User table (denormalised), fall back to profiles.
    final postCount = (urow?['postCount'] as int?) ??
        (row?['post_count'] as int?) ??
        0;
    final followerCount = (urow?['followerCount'] as int?) ??
        (row?['follower_count'] as int?) ??
        0;
    final followingCount = (urow?['followingCount'] as int?) ??
        (row?['following_count'] as int?) ??
        0;

    // Created-at: prefer User table, fall back to profiles.
    final createdAtRaw = urow?['createdAt'] ?? row?['created_at'];
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse('$createdAtRaw')
        : null;

    return UserProfile(
      firstName: first,
      lastName: last,
      email: email,
      handle: handle,
      country: country,
      dob: dob,
      role: role,
      avatarUrl: (row?['avatar_url'] as String?) ?? (urow?['avatarUrl'] as String?),
      coverUrl: (row?['cover_url'] as String?) ?? (urow?['coverUrl'] as String?),
      isVerified: isVerified,
      themeColor: (row?['theme_color'] as String?) ?? '#168CFF',
      bio: (row?['bio'] as String?) ?? (urow?['bio'] as String?) ?? '',
      createdAt: createdAt,
      postCount: postCount,
      followerCount: followerCount,
      followingCount: followingCount,
    );
  }

  (String, String) _splitName(String? name) {
    if (name == null || name.trim().isEmpty) return ('', '');
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0], '');
    return (parts.first, parts.sublist(1).join(' '));
  }
}

enum RegisterResult { authenticated, needsEmailConfirmation }
