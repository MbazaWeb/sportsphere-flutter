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

    // Read role from profiles table — not from metadata which may be stale
    return _profileFromDb(user);
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

    // Read role from profiles table — trigger should have created the row
    return _profileFromDb(user);
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

    // Read live counts from the real tables instead of stale cached columns
    int postCount = 0;
    int followerCount = 0;
    int followingCount = 0;
    try {
      final counts = await Future.wait([
        _supabase.from('Post').select('id').eq('authorId', userId).then((r) => (r as List).length),
        _supabase.from('Follow').select('id').eq('followingId', userId).then((r) => (r as List).length),
        _supabase.from('Follow').select('id').eq('followerId', userId).then((r) => (r as List).length),
      ]);
      postCount = counts[0];
      followerCount = counts[1];
      followingCount = counts[2];
    } catch (_) {
      // Fall back to cached values if live query fails
      postCount = response['post_count'] ?? 0;
      followerCount = response['follower_count'] ?? 0;
      followingCount = response['following_count'] ?? 0;
    }

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
      postCount: postCount,
      followerCount: followerCount,
      followingCount: followingCount,
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

  /// Always reads role from profiles table (source of truth).
  /// Falls back to metadata if DB read fails.
  Future<UserProfile> _profileFromDb(User user) async {
    try {
      final r = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return UserProfile(
        firstName: r['first_name'] ?? '',
        lastName: r['last_name'] ?? '',
        email: user.email ?? '',
        handle: r['handle'] ?? '',
        country: r['country'] ?? '',
        dob: DateTime.tryParse(r['dob'] ?? '') ?? DateTime.now(),
        joinedDate: DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now(),
        role: r['role'] ?? 'fan',
        avatarUrl: r['avatar_url'],
        coverUrl: r['cover_url'],
        isVerified: r['is_verified'] ?? false,
        themeColor: r['theme_color'] ?? '#168CFF',
        bio: r['bio'] ?? '',
        createdAt: DateTime.tryParse(r['created_at'] ?? ''),
        postCount: r['post_count'] ?? 0,
        followerCount: r['follower_count'] ?? 0,
        followingCount: r['following_count'] ?? 0,
      );
    } catch (_) {
      return _userFromSupabase(user);
    }
  }
}
