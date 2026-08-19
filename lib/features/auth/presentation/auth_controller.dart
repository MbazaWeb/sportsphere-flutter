import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

// ── Controller ─────────────────────────────────────────────────────────────────

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _hydrate();
    return const AuthState();
  }

  // ── Hydrate from stored token on app start ─────────────────────────────────
  Future<void> _hydrate() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.currentToken();
    final user = token == null ? null : await repo.currentProfile();
    state = AuthState(
      status: token == null ? AuthStatus.guest : AuthStatus.authenticated,
      token: token,
      user: user,
    );
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String identifier, // email or handle
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.login(
        identifier: identifier,
        password: password,
      );
      final token = await repo.currentToken();
      final user = await repo.currentProfile();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
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
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref.read(authRepositoryProvider).register(
            firstName: firstName,
            lastName: lastName,
            email: email,
            handle: handle,
            country: country,
            dob: dob,
            password: password,
          );
      final token = await ref.read(authRepositoryProvider).currentToken();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: UserProfile(
          firstName: firstName,
          lastName: lastName,
          email: email,
          handle: handle,
          country: country,
          dob: dob,
        ),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
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

  // ── Error helper ───────────────────────────────────────────────────────────
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Incorrect username or password.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'No internet connection. Check your network.';
    }
    if (msg.contains('handle') || msg.contains('taken')) {
      return 'That handle is already taken. Try another.';
    }
    if (msg.contains('email')) {
      return 'An account with this email already exists.';
    }
    return 'Something went wrong. Please try again.';
  }
}
