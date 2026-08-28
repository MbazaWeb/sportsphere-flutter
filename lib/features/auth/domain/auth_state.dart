// ── User profile (what we know after login/register) ──────────────────────────

class UserProfile {
  const UserProfile({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.handle,
    required this.country,
    required this.dob,
    required this.joinedDate,
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

  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String handle;
  final String country;
  final DateTime dob;

  /// When the user joined Playify (distinct from dob).
  final DateTime joinedDate;

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

  String get displayName => '\$firstName \$lastName';
  String get atHandle => '@\$handle';

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? handle,
    String? country,
    DateTime? dob,
    DateTime? joinedDate,
    String? role,
    String? avatarUrl,
    String? coverUrl,
    bool? isVerified,
    String? themeColor,
    List<String>? fanBadges,
    String? bio,
    DateTime? createdAt,
    int? postCount,
    int? followerCount,
    int? followingCount,
  }) => UserProfile(
    id:             id            ?? this.id,
    firstName:      firstName     ?? this.firstName,
    lastName:       lastName      ?? this.lastName,
    email:          email         ?? this.email,
    handle:         handle        ?? this.handle,
    country:        country       ?? this.country,
    dob:            dob           ?? this.dob,
    joinedDate:     joinedDate    ?? this.joinedDate,
    role:           role          ?? this.role,
    avatarUrl:      avatarUrl     ?? this.avatarUrl,
    coverUrl:       coverUrl      ?? this.coverUrl,
    isVerified:     isVerified    ?? this.isVerified,
    themeColor:     themeColor    ?? this.themeColor,
    fanBadges:      fanBadges     ?? this.fanBadges,
    bio:            bio           ?? this.bio,
    createdAt:      createdAt     ?? this.createdAt,
    postCount:      postCount     ?? this.postCount,
    followerCount:  followerCount ?? this.followerCount,
    followingCount: followingCount?? this.followingCount,
  );
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

  // FIX #1: Use a sentinel to distinguish "not passed" from "pass null".
  // Callers that want to clear errorMessage must call clearError() explicitly.
  AuthState copyWith({
    AuthStatus? status,
    String? token,
    UserProfile? user,
    bool? isLoading,
    Object? errorMessage = _keep,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _keep)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  AuthState clearError() => AuthState(
        status: status,
        token: token,
        user: user,
        isLoading: isLoading,
        errorMessage: null,
      );
}

// Sentinel value so copyWith can distinguish "not provided" from null.
const Object _keep = Object();
