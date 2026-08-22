import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

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
    Future<void>(() => _hydrate());
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
    } catch (e) {
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String handle,
    required String country,
    required DateTime dob,
    String password = '',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      final user = await ref.read(authRepositoryProvider).register(
            firstName: firstName,
            lastName: lastName,
            email: email,
            handle: handle,
            country: country,
            dob: dob,
            password: password.isEmpty ? 'SportSphere2024!' : password,
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
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
      return null;
    }
  }

  // -- Update profile ---------------------------------------------------
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      final updated = await ref.read(authRepositoryProvider).updateProfile(data);
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  // -- Change password --------------------------------------------------
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: _keep);
    try {
      await ref.read(authRepositoryProvider).changePassword(currentPassword, newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

// Sentinel — prevents copyWith from clearing errorMessage unintentionally.
// ignore: library_private_types_in_public_api
const Object _keep = Object();
