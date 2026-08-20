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

  Future<UserProfile?> currentProfile() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    return _profileById(user.id);
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
    final row = await _sb.from('profiles').select('email').eq('handle', handle).maybeSingle();
    final email = row?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw StateError('Unknown handle');
    }
    return email;
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
    } catch (_) {}
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
