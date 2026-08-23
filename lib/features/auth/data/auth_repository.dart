import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/auth_state.dart';

class AuthRepository {
  const AuthRepository();

  // Get the Supabase client instance
  SupabaseClient get _supabase => Supabase.instance.client;

  // For C6 — also expose a stable alias for tests / clarity.
  SupabaseClient get _sb => _supabase;

  // ── Session check ──────────────────────────────────────────────────────────
  bool get hasSession => _supabase.auth.currentSession != null;

  Session? get currentSession => _supabase.auth.currentSession;

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    // Resolve handle to email: only use identifier as-is if it contains @
    // Otherwise treat as handle and resolve via profiles table
    String email = identifier.trim().toLowerCase();
    if (!email.contains('@')) {
      // It's a handle — look up the email
      final handle = email.replaceAll('@', '');
      try {
        final row = await _supabase.from('profiles')
            .select('email').eq('handle', handle).maybeSingle();
        if (row != null && (row['email'] as String?)?.isNotEmpty == true) {
          email = row['email'] as String;
        }
      } catch (_) {}
    }
    final response = await _supabase.auth.signInWithPassword(
      email: email,
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
    // C1 — Defence in depth: the controller already rejects empty passwords,
    // but enforce it at the repository boundary too so a future caller can
    // never bypass it. NEVER fall back to a hardcoded password.
    if (password.isEmpty) {
      throw ArgumentError('Password is required');
    }

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'handle': handle,
        'country': country,
        'dob': dob.toIso8601String(),
        'avatar_url': 'assets/images/Playify_logo.png', // default Playify avatar
        'role': 'fan',
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
        _supabase.from('Post').select('id').eq('userId', userId).then((r) => (r as List).length),
        _supabase.from('Follow').select('id').eq('followingId', userId).then((r) => (r as List).length),
        _supabase.from('Follow').select('id').eq('followerId', userId).then((r) => (r as List).length),
      ]);
      postCount = counts[0];
      followerCount = counts[1];
      followingCount = counts[2];
    } catch (e) {
      // Fall back to cached values if live query fails
      // Note: profiles has follower_count/following_count but NOT post_count
      debugPrint('[hydrateProfile] live counts failed, using cached: $e');
      postCount = 0;
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
      avatarUrl: response['avatar_url'] ?? 'assets/images/Playify_logo.png',
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
  //
  // C7 — PRIVILEGE ESCALATION FIX
  // The previous signature accepted a raw `Map<String, dynamic>` from any
  // caller, which meant a compromised / buggy caller could write to ANY
  // column on `profiles` — including `role`, `is_verified`, `email`, etc.
  // We now accept only whitelisted named parameters and build the patch
  // map internally. Unknown / privileged columns can never reach the DB.
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
    final session = currentSession;
    if (session == null) return null;

    // Defence in depth: the userId MUST match the authenticated session.
    // Without this, a caller could pass another user's id and update their
    // profile (RLS should also block this, but never trust the client).
    if (userId != session.user.id) {
      throw StateError(
        'updateProfile: userId does not match authenticated session',
      );
    }

    // Build the profiles patch from whitelisted named params only.
    final patch = <String, dynamic>{};
    if (firstName != null) patch['first_name'] = firstName;
    if (lastName != null) patch['last_name'] = lastName;
    if (handle != null) patch['handle'] = handle;
    if (country != null) patch['country'] = country;
    if (bio != null) patch['bio'] = bio;
    if (dateOfBirth != null) patch['dob'] = dateOfBirth.toIso8601String();
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (coverUrl != null) patch['cover_url'] = coverUrl;
    if (themeColor != null) patch['theme_color'] = themeColor;

    if (patch.isEmpty) {
      // Nothing to update — just return the current profile.
      return hydrateProfile();
    }

    // Update profiles table (snake_case columns).
    await _supabase.from('profiles').update(patch).eq('id', userId);

    // Also update the legacy User table (PascalCase columns) so they stay
    // in sync. Built from the SAME whitelisted values — never from caller
    // input — so the privilege boundary holds on both writes.
    final userPatch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (firstName != null || lastName != null) {
      // Reconstruct the full name from new + existing values.
      final newFirst = firstName ?? '';
      final newLast = lastName ?? '';
      userPatch['name'] = '$newFirst $newLast'.trim();
    }
    if (handle != null) userPatch['handle'] = handle;
    if (bio != null) userPatch['bio'] = bio;
    if (country != null) userPatch['currentCountry'] = country;
    if (avatarUrl != null) userPatch['avatarUrl'] = avatarUrl;
    if (coverUrl != null) userPatch['coverUrl'] = coverUrl;

    try {
      await _supabase.from('User').update(userPatch).eq('id', userId);
    } catch (e) {
      debugPrint('[updateProfile] User table sync failed: $e');
    }

    return hydrateProfile();
  }

  // ── Change password ────────────────────────────────────────────────────────
  //
  // C6 — CURRENT PASSWORD VERIFICATION
  // The previous implementation accepted `currentPassword` as a parameter
  // but silently ignored it, jumping straight to `updateUser(password:)`.
  // That meant anyone holding a live session token (e.g. on a shared
  // device, or via a leaked token) could change the password without
  // proving they knew the current one. We now re-authenticate with the
  // current password BEFORE issuing the update. A wrong current password
  // throws [AuthException] from supabase_flutter, which the controller
  // surfaces via friendlyError().
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw ArgumentError('Current password is required');
    }
    if (newPassword.isEmpty) {
      throw ArgumentError('New password is required');
    }

    final currentEmail = _sb.auth.currentUser?.email;
    if (currentEmail == null) {
      throw StateError('Not signed in');
    }

    // Re-authenticate to prove the caller knows the current password.
    // signInWithPassword validates against Supabase Auth, so even a
    // stolen access token alone cannot pass this check.
    final session = await _sb.auth.signInWithPassword(
      email: currentEmail,
      password: currentPassword,
    );
    if (session.user == null) {
      throw AuthException('Current password is incorrect');
    }

    // Re-authentication succeeded — safe to update to the new password.
    await _sb.auth.updateUser(UserAttributes(password: newPassword));
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
        avatarUrl: r['avatar_url'] ?? 'assets/images/Playify_logo.png',
        coverUrl: r['cover_url'],
        isVerified: r['is_verified'] ?? false,
        themeColor: r['theme_color'] ?? '#168CFF',
        bio: r['bio'] ?? '',
        createdAt: DateTime.tryParse(r['created_at'] ?? ''),
        postCount: 0, // live count fetched separately in hydrateProfile
        followerCount: r['follower_count'] ?? 0,
        followingCount: r['following_count'] ?? 0,
      );
    } catch (e) {
      debugPrint('[_profileFromDb] fell back to metadata: $e');
      return _userFromSupabase(user);
    }
  }
}
