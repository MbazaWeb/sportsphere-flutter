enum AuthStatus { unknown, guest, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.token,
  });

  final AuthStatus status;
  final String? token;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, String? token}) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
    );
  }
}
