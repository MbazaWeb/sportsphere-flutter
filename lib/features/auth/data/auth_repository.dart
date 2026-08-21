import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/auth_state.dart';

class AuthRepository {
  const AuthRepository();

  // Get the Supabase client instance
  SupabaseClient get _supabase => Supabase.instance.client;

  // ── Session check ──────────────────────────────────────────────────────────
  bool get hasSession => _supabase.auth.currentSession != null;

  Session? get currentSession => _supabase.auth.currentSession;

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: identifier,
      password: password,
    );

    final user = response.user;
    if (user == null) throw Exception('Login failed');

    return _userFromSupabase(user);
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
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'handle': handle,
        'country': country,
        'dob': dob.toIso8601String(),
      },
    );

    final user = response.user;
    if (user == null) throw Exception('Registration failed');

    return _userFromSupabase(user);
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ── Hydrate profile ────────────────────────────────────────────────────────
  Future<UserProfile?> hydrateProfile() async {
    final session = currentSession;
    if (session == null) return null;

    final userId = session.user.id;
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return UserProfile(
      firstName: response['first_name'] ?? '',
      lastName: response['last_name'] ?? '',
      email: session.user.email ?? '',
      handle: response['handle'] ?? '',
      country: response['country'] ?? '',
      dob: DateTime.tryParse(response['dob'] ?? '') ?? DateTime.now(),
      joinedDate: DateTime.tryParse(response['created_at'] ?? '') ?? DateTime.now(),
      role: response['role'] ?? 'fan',
      avatarUrl: response['avatar_url'],
      coverUrl: response['cover_url'],
      isVerified: response['is_verified'] ?? false,
      themeColor: response['theme_color'] ?? '#168CFF',
      bio: response['bio'] ?? '',
      createdAt: DateTime.tryParse(response['created_at']),
      postCount: response['post_count'] ?? 0,
      followerCount: response['follower_count'] ?? 0,
      followingCount: response['following_count'] ?? 0,
    );
  }

  // ── Password reset ─────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // ── Resend confirmation ────────────────────────────────────────────────────
  Future<void> resendConfirmation(String email) async {
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  // ── Refresh profile ────────────────────────────────────────────────────────
  Future<UserProfile?> refreshProfile() async {
    final session = currentSession;
    if (session == null) return null;
    return hydrateProfile();
  }

  // ── Update profile ─────────────────────────────────────────────────────────
  Future<UserProfile?> updateProfile(Map<String, dynamic> data) async {
    final session = currentSession;
    if (session == null) return null;

    final userId = session.user.id;
    await _supabase
        .from('profiles')
        .update(data)
        .match({'id': userId});

    return hydrateProfile();
  }

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ── Helper: Convert Supabase user to UserProfile ──────────────────────────
  UserProfile _userFromSupabase(User user) {
    final metadata = user.userMetadata ?? {};

    return UserProfile(
      firstName: metadata['first_name'] ?? '',
      lastName: metadata['last_name'] ?? '',
      email: user.email ?? '',
      handle: metadata['handle'] ?? '',
      country: metadata['country'] ?? '',
      dob: DateTime.tryParse(metadata['dob'] ?? '') ?? DateTime.now(),
      joinedDate: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      role: metadata['role'] ?? 'fan',
      avatarUrl: metadata['avatar_url'],
      coverUrl: metadata['cover_url'],
      isVerified: metadata['is_verified'] ?? false,
      themeColor: metadata['theme_color'] ?? '#168CFF',
      bio: metadata['bio'] ?? '',
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }
}
