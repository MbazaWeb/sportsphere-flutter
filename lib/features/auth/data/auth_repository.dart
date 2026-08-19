import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required TokenStore tokens,
  })  : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  Future<String?> currentToken() => _tokens.read();

  Future<void> saveSession(String token) => _tokens.write(token);

  Future<void> signOut() => _tokens.clear();

  /// Placeholder — wire to POST /auth/login when the backend exists.
  Future<void> login({required String email, required String password}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );
    final token = response.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Login response missing token');
    }
    await _tokens.write(token);
  }
}
