import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return const AuthState(status: AuthStatus.unknown, isLoading: true);
  }

  Future<void> _bootstrap() async {
    try {
      final session = _repo.currentSession;
      if (session == null) {
        state = const AuthState(status: AuthStatus.guest);
        return;
      }
      await _repo.syncIdentity();
      final user = await _repo.currentProfile();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: session.accessToken,
        user: user,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.guest);
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.login(identifier: identifier, password: password);
      final session = _repo.currentSession;
      final user = await _repo.currentProfile();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: session?.accessToken,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.guest,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  /// Returns true if fully signed in; false if needs email confirm or error.
  /// Check [state.errorMessage] — if it starts with CONFIRM: treat as soft success.
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
      final result = await _repo.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        handle: handle,
        country: country,
        dob: dob,
        password: password,
      );
      if (result == RegisterResult.needsEmailConfirmation) {
        state = AuthState(
          status: AuthStatus.guest,
          errorMessage:
              'CONFIRM: We sent a verification link to $email. Confirm, then log in.',
        );
        return false;
      }
      final session = _repo.currentSession;
      final user = await _repo.currentProfile();
      state = AuthState(
        status: AuthStatus.authenticated,
        token: session?.accessToken,
        user: user ??
            UserProfile(
              firstName: firstName,
              lastName: lastName,
              email: email,
              handle: handle,
              country: country,
              dob: dob,
            ),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.guest,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> updateProfile({
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
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.updateProfile(
        firstName: firstName,
        lastName: lastName,
        handle: handle,
        country: country,
        dob: dob,
        bio: bio,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
        themeColor: themeColor,
      );
      state = state.copyWith(
        isLoading: false,
        user: user,
        status: AuthStatus.authenticated,
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

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.guest);
  }

  void clearError() => state = state.clearError();

  Future<String?> sendPasswordReset(String identifier) async {
    try {
      await _repo.sendPasswordReset(identifier);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> changePassword(String newPassword) async {
    try {
      await _repo.changePassword(newPassword: newPassword);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> resendConfirmation(String emailOrHandle) async {
    try {
      await _repo.resendConfirmation(emailOrHandle);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('confirm:')) {
      return e.toString().replaceFirst('StateError: ', '');
    }
    if (msg.contains('invalid login') ||
        msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect username or password.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'No internet connection. Check your network.';
    }
    if (msg.contains('handle') || msg.contains('taken')) {
      return 'That handle is already taken. Try another.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('email')) {
      return 'Check your email address and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
