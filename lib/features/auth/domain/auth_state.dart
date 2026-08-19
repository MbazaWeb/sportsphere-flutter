// ── User profile (what we know after login/register) ──────────────────────────

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.handle,
    required this.country,
    required this.dob,
    this.role = 'fan',
    this.avatarUrl,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String handle;
  final String country;
  final DateTime dob;

  /// 'fan' by default. Future: 'player', 'coach', 'team', etc. via "Become Pro"
  final String role;
  final String? avatarUrl;

  String get displayName => '$firstName $lastName';
  String get atHandle => '@$handle';
}

// ── Auth status ────────────────────────────────────────────────────────────────

enum AuthStatus { unknown, guest, authenticated }

// ── Auth state ─────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.token,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? token;
  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.guest;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    UserProfile? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  AuthState clearError() => copyWith(errorMessage: null);
}
