import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../../../core/utils/friendly_error.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

/// The single auth repository — no Dio, no TokenStore needed.
final authRepositoryProvider = Provider<AuthRepository>((_) => const AuthRepository());

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

// ══════════════════════════════════════════════════════════════════════════════
// AUTH CONTROLLER
// ══════════════════════════════════════════════════════════════════════════════
//
// All auth flows now go through Supabase (via AuthRepository).
// Supabase persists the session automatically — _hydrate() just reads it.
// The Riverpod state (AuthState / UserProfile) is the single source of truth
// for the UI; Supabase.instance.client is the source of truth for tokens.

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.read(authRepositoryProvider);

    // Fresh install / signed out: resolve immediately so the router never
    // stays in `unknown` (which pins every route to the splash).
    if (!repo.hasSession) {
      return const AuthState(status: AuthStatus.guest);
    }

    // Has a persisted session: start as unknown (splash holds) while the
    // profile hydrates asynchronously.
    //
    // M1 — Defer _hydrate() to a post-frame callback so any state mutation
    // happens AFTER the current build phase completes. Calling it
    // fire-and-forget inside build() could mutate `state` while a widget
    // tree is mid-build, triggering a setState-during-build assertion.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Guard: the provider may have been disposed between the build() call
      // and the post-frame callback firing (e.g. fast nav). Bail out silently.
      if (ref.mounted) {
        _hydrate();
      }
    });
    return const AuthState();
  }

  // ── Hydrate: read persisted Supabase session on app start ─────────────────
  Future<void> _hydrate() async {
    final repo = ref.read(authRepositoryProvider);

    if (!repo.hasSession) {
      state = const AuthState(status: AuthStatus.guest);
      return;
    }

    try {
      final profile = await repo.hydrateProfile();
      state = AuthState(
        status: profile != null
            ? AuthStatus.authenticated
            : AuthStatus.guest,
        // Use access token from Supabase session for any Dio calls
        token: repo.currentSession?.accessToken,
        user: profile,
      );
    } on AuthException catch (e) {
      // AuthException means Supabase Auth confirmed the session is invalid.
      // ONLY in this case do we clear the local session.
      debugPrint('[AUTH] _hydrate: AuthException — clearing session: ${e.message}');
      try {
        await repo.signOutLocal();
      } catch (_) {}
      state = const AuthState(status: AuthStatus.guest);
    } catch (e) {
      // Any other error (network, RLS, DB schema) does NOT mean the session
      // is invalid. Become a guest for now but do NOT destroy the session
      // — the user may be able to retry.
      debugPrint('[AUTH] _hydrate: non-auth error, becoming guest without signOut: $e');
      state = const AuthState(status: AuthStatus.guest);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      final user = await ref.read(authRepositoryProvider).login(
            identifier: identifier,
            password: password,
          );
      state = AuthState(
        status: AuthStatus.authenticated,
        token: ref.read(authRepositoryProvider).currentSession?.accessToken,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
      return false;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  ///
  /// C1 — A password is ALWAYS required. The previous implementation fell
  /// back to a hardcoded password (`'SportSphere2024!'`) when the caller
  /// passed an empty string, which silently created accounts with a known
  /// password. We now throw [ArgumentError] up front — the UI must collect
  /// and validate a password before calling this.
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String handle,
    required String country,
    required DateTime dob,
    String password = '',
  }) async {
    if (password.isEmpty) {
      debugPrint('[AuthController.register] rejected: empty password');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Password is required',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      final user = await ref.read(authRepositoryProvider).register(
            firstName: firstName,
            lastName: lastName,
            email: email,
            handle: handle,
            country: country,
            dob: dob,
            password: password,
          );
      state = AuthState(
        status: AuthStatus.authenticated,
        token: ref.read(authRepositoryProvider).currentSession?.accessToken,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
      return false;
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.guest);
  }

  // ── Clear error ────────────────────────────────────────────────────────────
  void clearError() => state = state.clearError();

  // ── Token refresh hook (called by ApiClient interceptor if needed) ─────────
  /// Returns the current Supabase access token, refreshing if expired.
  Future<String?> freshToken() async {
    try {
      final session = ref.read(authRepositoryProvider).currentSession;
      if (session == null) return null;
      // Supabase auto-refreshes; just return the current token.
      return session.accessToken;
    } catch (_) {
      return null;
    }
  }

  // -- Send password reset ----------------------------------------------
  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
      return false;
    }
  }

  // -- Resend confirmation ----------------------------------------------
  Future<bool> resendConfirmation(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
      return false;
    }
  }

  // -- Refresh profile --------------------------------------------------
  Future<UserProfile?> refreshProfile() async {
    try {
      final profile = await ref.read(authRepositoryProvider).refreshProfile();
      if (profile != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          token: ref.read(authRepositoryProvider).currentSession?.accessToken,
          user: profile,
        );
      }
      return profile;
    } catch (e) {
      debugPrint('[AuthController.refreshProfile] failed: $e');
      return null;
    }
  }

  // -- Update profile ---------------------------------------------------
  ///
  /// C7 — Now takes whitelisted named params instead of a raw Map. The
  /// underlying [AuthRepository.updateProfile] only writes the explicitly
  /// supported profile columns — callers can no longer smuggle in
  /// `role` / `is_verified` / arbitrary keys.
  Future<bool> updateProfile({
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
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      final repo = ref.read(authRepositoryProvider);
      final userId = repo.currentSession?.user.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Not signed in',
        );
        return false;
      }
      final updated = await repo.updateProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            handle: handle,
            country: country,
            bio: bio,
            dateOfBirth: dateOfBirth,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
            themeColor: themeColor,
          );
      if (updated != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          token: ref.read(authRepositoryProvider).currentSession?.accessToken,
          user: updated,
          isLoading: false,
        );
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
      return false;
    }
  }

  // -- Change password --------------------------------------------------
  ///
  /// C6 — Now requires the current password. [AuthRepository.changePassword]
  /// re-authenticates with the current credentials before updating, so a
  /// stolen session token alone is not enough to take over the account.
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: friendlyError(e),
      );
      return false;
    }
  }
}

// Sentinel — prevents copyWith from clearing errorMessage unintentionally.
// ignore: library_private_types_in_public_api
const Object _keep = Object();
