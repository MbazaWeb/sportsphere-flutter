import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_state.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required TokenStore tokens,
    FlutterSecureStorage? profileStorage,
  })  : _api = api,
        _tokens = tokens,
        _profileStorage = profileStorage ?? const FlutterSecureStorage();

  final ApiClient _api;
  final TokenStore _tokens;
  final FlutterSecureStorage _profileStorage;

  static const _profileKey = 'ss_user_profile';

  Future<String?> currentToken() => _tokens.read();

  Future<void> signOut() async {
    await _tokens.clear();
    await _profileStorage.delete(key: _profileKey);
  }

  // ── Load / save cached profile (fix #3) ───────────────────────────────────

  Future<UserProfile?> loadCachedProfile() async {
    try {
      final raw = await _profileStorage.read(key: _profileKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _profileFromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final map = {
      'firstName': profile.firstName,
      'lastName': profile.lastName,
      'email': profile.email,
      'handle': profile.handle,
      'country': profile.country,
      'dob': profile.dob.toIso8601String(),
      'joinedDate': profile.joinedDate.toIso8601String(),
      'role': profile.role,
    };
    await _profileStorage.write(key: _profileKey, value: jsonEncode(map));
  }

  UserProfile _profileFromMap(Map<String, dynamic> map) {
    return UserProfile(
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      email: map['email'] as String,
      handle: map['handle'] as String,
      country: map['country'] as String,
      dob: DateTime.parse(map['dob'] as String),
      joinedDate: DateTime.parse(map['joinedDate'] as String),
      role: (map['role'] as String?) ?? 'fan',
    );
  }

  // ── Login — returns UserProfile (fix #2) ─────────────────────────────────

  Future<UserProfile> login({
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

    final data = response.data;
    final token = data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Login response missing token');
    }
    await _tokens.write(token);

    // Parse user from response, or fall back to minimal profile from identifier
    final userData = data?['user'] as Map<String, dynamic>?;
    final profile = userData != null
        ? _profileFromMap(userData)
        : UserProfile(
            firstName: identifier.contains('@') ? identifier : identifier,
            lastName: '',
            email: identifier.contains('@') ? identifier : '',
            handle: identifier.replaceAll('@', ''),
            country: '',
            dob: DateTime(1990),
            joinedDate: DateTime.now(),
          );

    await _saveProfile(profile);
    return profile;
  }

  // ── Register — returns UserProfile ────────────────────────────────────────

  Future<UserProfile> register({
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

    final profile = UserProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      handle: handle,
      country: country,
      dob: dob,
      joinedDate: DateTime.now(),
    );
    await _saveProfile(profile);
    return profile;
  }
}
