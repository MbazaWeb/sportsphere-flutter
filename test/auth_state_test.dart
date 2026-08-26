import 'package:flutter_test/flutter_test.dart';
import 'package:playify/features/auth/domain/auth_state.dart';

void main() {
  group('AuthState', () {
    test('defaults to unknown status', () {
      const state = AuthState();
      expect(state.status, AuthStatus.unknown);
      expect(state.isAuthenticated, false);
      expect(state.isGuest, false);
      expect(state.token, null);
      expect(state.user, null);
      expect(state.isLoading, false);
      expect(state.errorMessage, null);
    });

    test('isAuthenticated true when status is authenticated', () {
      const state = AuthState(status: AuthStatus.authenticated);
      expect(state.isAuthenticated, true);
      expect(state.isGuest, false);
    });

    test('isGuest true when status is guest', () {
      const state = AuthState(status: AuthStatus.guest);
      expect(state.isGuest, true);
      expect(state.isAuthenticated, false);
    });

    test('copyWith preserves unset fields', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        token: 'tok',
        isLoading: false,
      );
      final next = state.copyWith(isLoading: true);
      expect(next.status, AuthStatus.authenticated);
      expect(next.token, 'tok');
      expect(next.isLoading, true);
    });

    test('copyWith does NOT clear errorMessage when not passed', () {
      final state = const AuthState().copyWith(errorMessage: 'oops');
      expect(state.errorMessage, 'oops');
      // Another copyWith without errorMessage must preserve it
      final next = state.copyWith(isLoading: true);
      expect(next.errorMessage, 'oops');
    });

    test('clearError sets errorMessage to null', () {
      final state = const AuthState().copyWith(errorMessage: 'oops');
      final cleared = state.clearError();
      expect(cleared.errorMessage, null);
    });
  });

  group('UserProfile', () {
    final profile = UserProfile(
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@example.com',
      handle: 'johndoe',
      country: 'Tanzania',
      dob: DateTime(1995, 6, 15),
      joinedDate: DateTime(2024, 3, 1),
    );

    test('displayName concatenates first and last name', () {
      expect(profile.displayName, 'John Doe');
    });

    test('atHandle prepends @', () {
      expect(profile.atHandle, '@johndoe');
    });

    test('role defaults to fan', () {
      expect(profile.role, 'fan');
    });

    test('isVerified defaults to false', () {
      expect(profile.isVerified, false);
    });

    test('postCount defaults to 0', () {
      expect(profile.postCount, 0);
    });
  });
}
