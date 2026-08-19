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
    final res = await _sb.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'handle': cleanHandle,
        'role': 'fan',
        'first_name': firstName,
        'last_name': lastName,
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
    });
  }

  Future<String> _resolveEmail(String identifier) async {
    final raw = identifier.trim();
    if (raw.contains('@') && raw.contains('.') && !raw.startsWith('@')) {
      return raw.toLowerCase();
    }
    final handle = raw.toLowerCase().replaceAll('@', '');
    final row = await _sb
        .from('profiles')
        .select('email')
        .eq('handle', handle)
        .maybeSingle();
    final email = row?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw StateError('Unknown handle');
    }
    return email;
  }

  Future<UserProfile?> _profileById(String id) async {
    final row = await _sb.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return UserProfile(
      firstName: (row['first_name'] as String?) ?? '',
      lastName: (row['last_name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      handle: (row['handle'] as String?) ?? '',
      country: (row['country'] as String?) ?? 'Tanzania',
      dob: DateTime(1995, 1, 1),
      role: (row['role'] as String?) ?? 'fan',
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
