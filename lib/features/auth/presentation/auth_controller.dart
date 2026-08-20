import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(readToken: store.read);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStoreProvider),
  );
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

  // ── FIX #2 & #3: Hydrate restores token AND attempts to fetch stored profile.
  // When the backend is ready, replace _cachedProfile with a GET /auth/me call.
  Future<void> _hydrate() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.currentToken();

    if (token == null) {
      state = const AuthState(status: AuthStatus.guest);
      return;
    }

    // Try to load cached profile from local storage.
    final cached = await repo.loadCachedProfile();
    state = AuthState(
      status: AuthStatus.authenticated,
      token: token,
      user: cached, // null if not cached — profile screen falls back to mock
    );
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
      final token = await ref.read(authRepositoryProvider).currentToken();
      // FIX #2: login() now returns UserProfile so user is never null post-login.
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
          );
      final token = await ref.read(authRepositoryProvider).currentToken();
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

// Re-export sentinel so callers can use it in copyWith(errorMessage: _keep)
// ignore: library_private_types_in_public_api
const Object _keep = Object();
