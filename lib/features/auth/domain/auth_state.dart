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
    this.coverUrl,
    this.isVerified = false,
    this.themeColor = '#168CFF',
    this.fanBadges = const [],
    this.bio = '',
    this.createdAt,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
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
  final String? coverUrl;
  final bool isVerified;
  final String themeColor;
  final List<String> fanBadges;
  final String bio;

  /// When the user account was created.
  final DateTime? createdAt;

  /// Number of posts authored by this user.
  final int postCount;

  /// Number of users following this user.
  final int followerCount;

  /// Number of users this user is following.
  final int followingCount;

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
