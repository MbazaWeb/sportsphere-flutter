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

  /// Login with email or handle + password.
  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: <String, dynamic>{
        'identifier': identifier,
        'password': password,
      },
    );
    final token = response.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Login response missing token');
    }
    await _tokens.write(token);
  }

  /// Register a new fan account.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String handle,
    required String country,
    required DateTime dob,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      data: <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'handle': handle,
        'country': country,
        'dob': dob.toIso8601String().split('T').first,
        'role': 'fan',
      },
    );
    final token = response.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Register response missing token');
    }
    await _tokens.write(token);
  }
}
