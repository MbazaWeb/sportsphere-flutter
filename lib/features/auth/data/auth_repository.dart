import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_state.dart';

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
    } catch (_) {
      // Local cleanup must still complete if the remote sign-out is unavailable.
    }
  }

  Future<UserProfile?> currentProfile() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    try {
      return await _profileById(user.id);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('401') || msg.contains('jwt') || msg.contains('unauthorized')) {
        await clearLocalSession();
        return null;
      }
      rethrow;
    }
  }

  /// Ensures public."User" exists for social graphs (idempotent).
  Future<void> ensureUserRow() async {
    final u = _sb.auth.currentUser;
    if (u == null) return;
    final existing = await _sb.from('User').select('id').eq('id', u.id).maybeSingle();
    if (existing != null) return;
    final p = await _profileById(u.id);
    final handle = (p?.handle.isNotEmpty == true)
        ? p!.handle
        : (u.userMetadata?['handle'] as String?) ?? u.id.substring(0, 8);
    final name = p != null
        ? '${p.firstName} ${p.lastName}'.trim()
        : (u.userMetadata?['first_name'] as String?) ?? handle;
    try {
      await _sb.from('User').upsert({
        'id': u.id,
        'name': name.isEmpty ? handle : name,
        'email': (u.email ?? p?.email ?? '${u.id}@users.local').toLowerCase(),
        'handle': handle.replaceAll('@', '').toLowerCase(),
        'role': p?.role ?? 'fan',
        'bio': p?.bio ?? '',
        'avatarUrl': p?.avatarUrl,
        'coverUrl': p?.coverUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) { debugPrint("auth: $e"); }
  }

  Future<void> sendPasswordReset(String emailOrHandle) async {
    final email = await _resolveEmail(emailOrHandle);
    await _sb.auth.resetPasswordForEmail(
      email,
      redirectTo: null,
    );
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
    await ensureUserRow();
    if (res.session == null) {
      throw StateError('Login failed');
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String handle,
    required String country,
    required DateTime dob,
    required String password,
  }) async {
    final cleanHandle = handle.trim().toLowerCase().replaceAll('@', '');
    final taken = await _sb.from('profiles').select('id').eq('handle', cleanHandle).maybeSingle();
    if (taken != null) {
      throw StateError('That handle is already taken');
    }
    final dobIso = dob.toIso8601String().split('T').first;
    final res = await _sb.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'handle': cleanHandle,
        'role': 'fan',
        'first_name': firstName,
        'last_name': lastName,
        'country': country,
        'dob': dobIso,
      },
    );
    final user = res.user;
    if (user == null) {
      throw StateError('Register failed');
    }
    await _sb.from('profiles').upsert({
      'id': user.id,
      'handle': cleanHandle,
      'role': 'fan',
      'first_name': firstName,
      'last_name': lastName,
      'email': email.trim(),
      'country': country,
      'dob': dobIso,
      'bio': '',
    });
    // Dual-write public."User" so social FKs (Follow/Post/fans) work for new accounts.
    final display = (firstName.trim() + ' ' + lastName.trim()).trim();
    final initials = (
      (firstName.isNotEmpty ? firstName[0] : '') +
      (lastName.isNotEmpty ? lastName[0] : '')
    ).toUpperCase();
    try {
      await _sb.from('User').upsert({
        'id': user.id,
        'name': display.isEmpty ? cleanHandle : display,
        'email': email.trim().toLowerCase(),
        'handle': cleanHandle,
        'role': 'fan',
        'bio': '',
        'currentCountry': country,
        'countryOfOrigin': country,
        'dateOfBirth': dobIso,
        'avatarInitials': initials.isEmpty ? 'SS' : initials,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Session may be null before email confirm — retry on first login.
    }
    if (res.session == null) {
      throw StateError('Confirm your email, then log in.');
    }
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
    final clash = await _sb.from('profiles').select('id').eq('handle', cleanHandle).neq('id', user.id).maybeSingle();
    if (clash != null) {
      throw StateError('That handle is already taken');
    }
    final patch = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'handle': cleanHandle,
      'country': country,
      'dob': dob.toIso8601String().split('T').first,
      'bio': bio.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (coverUrl != null) patch['cover_url'] = coverUrl;
    if (themeColor != null) patch['theme_color'] = themeColor;
    await _sb.from('profiles').update(patch).eq('id', user.id);
    try {
      final displayName = ('${firstName.trim()} ${lastName.trim()}').trim();
      await _sb.from('User').update({
        'name': displayName.isEmpty ? cleanHandle : displayName,
        'handle': cleanHandle,
        'bio': bio.trim(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
        'currentCountry': country,
        'dateOfBirth': dob.toIso8601String().split('T').first,
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (_) {
      await ensureUserRow();
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
      final row = await _sb.from('profiles').select('email').eq('handle', handle).maybeSingle();
      final email = row?['email'] as String?;
      if (email == null || email.isEmpty) {
        throw StateError('Unknown handle');
      }
      return email;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('401') || msg.contains('jwt') || msg.contains('unauthorized')) {
        await clearLocalSession();
        final row = await _sb.from('profiles').select('email').eq('handle', handle).maybeSingle();
        final email = row?['email'] as String?;
        if (email == null || email.isEmpty) {
          throw StateError('Unknown handle');
        }
        return email;
      }
      rethrow;
    }
  }

  Future<UserProfile?> _profileById(String id) async {
    final row = await _sb.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final authUser = _sb.auth.currentUser;
    final emailOk = authUser?.emailConfirmedAt != null;
    final verified = (row['is_verified'] as bool?) == true || emailOk == true;
    List<String> badges = const [];
    try {
      final fanRows = await _sb.from('fans').select('target_id').eq('fan_id', id);
      final tids = [for (final r in fanRows as List) (r as Map)['target_id']?.toString()].whereType<String>().toList();
      if (tids.isNotEmpty) {
        final teams = await _sb.from('Team').select('name,accountUserId').inFilter('accountUserId', tids);
        badges = [
          for (final t in teams as List)
            '${((t as Map)['name'] as String? ?? 'Team').replaceAll(RegExp(r'\s+(SC|FC)$'), '')} Fan'
        ];
      }
    } catch (e) { debugPrint("auth: $e"); }
    return UserProfile(
      firstName: (row['first_name'] as String?) ?? '',
      lastName: (row['last_name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      handle: (row['handle'] as String?) ?? '',
      country: (row['country'] as String?) ?? 'Tanzania',
      dob: _parseDob(row['dob']),
      role: (row['role'] as String?) ?? 'fan',
      avatarUrl: row['avatar_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      isVerified: verified,
      themeColor: (row['theme_color'] as String?) ?? '#168CFF',
      fanBadges: badges,
      bio: (row['bio'] as String?) ?? '',
    );
  }

  DateTime _parseDob(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime(1995, 1, 1);
    }
    return DateTime(1995, 1, 1);
  }
}
