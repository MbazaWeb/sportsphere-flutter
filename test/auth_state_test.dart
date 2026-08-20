import 'package:flutter_test/flutter_test.dart';
import 'package:sportsphere_app/features/auth/domain/auth_state.dart';

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

    test('copyWith can clear errorMessage explicitly', () {
      final state = const AuthState().copyWith(errorMessage: 'oops');
      expect(state.errorMessage, 'oops');
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

    test('count fields default to zero', () {
      expect(profile.postCount, 0);
      expect(profile.followerCount, 0);
      expect(profile.followingCount, 0);
    });

    test('createdAt defaults to null', () {
      expect(profile.createdAt, null);
    });

    test('count fields accept non-zero values', () {
      final p = UserProfile(
        firstName: 'Jane',
        lastName: 'Smith',
        email: 'jane@example.com',
        handle: 'janesmith',
        country: 'Kenya',
        dob: DateTime(1990, 1, 1),
        postCount: 42,
        followerCount: 150,
        followingCount: 80,
        createdAt: DateTime(2024, 3, 15, 10, 30),
      );
      expect(p.postCount, 42);
      expect(p.followerCount, 150);
      expect(p.followingCount, 80);
      expect(p.createdAt, DateTime(2024, 3, 15, 10, 30));
    });
  });
}
