import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/config/env.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApiClient — Dio wrapper for VPS REST endpoints.
// JWT is stored in SharedPreferences by AuthRepository after login.
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> _localToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_access_token');
}

class ApiClient {
  ApiClient({
    TokenReader? readToken,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppEnv.apiBaseUrl,
                connectTimeout: AppEnv.connectTimeout,
                receiveTimeout: AppEnv.receiveTimeout,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors
        .add(AuthInterceptor(readToken ?? () async => _localToken()));
    if (kDebugMode) {
      _dio.interceptors
          .add(LogInterceptor(requestBody: false, responseBody: false));
    }
  }

  final Dio _dio;

  Dio get raw => _dio;

  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? query}) =>
      _guard(() => _dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _guard(() => _dio.post<T>(path, data: data));

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _guard(() => _dio.put<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _guard(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> delete<T>(String path) =>
      _guard(() => _dio.delete<T>(path));

  Future<Response<T>> upload<T>(String path, FormData form) =>
      _guard(() => _dio.post<T>(path, data: form,
          options: Options(
            headers: {'Content-Type': 'multipart/form-data'},
            receiveTimeout: const Duration(minutes: 5),
            sendTimeout: const Duration(minutes: 5),
          )));

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Check for PASSWORD_NOT_SET from migrated users
        final body = e.response?.data;
        final code = body is Map ? body['code'] as String? : null;
        final msg  = body is Map ? body['error'] as String? : null;
        if (code == 'PASSWORD_NOT_SET') {
          throw ApiException(
            message: msg ?? 'Please reset your password to continue.',
            statusCode: 401,
            code: 'PASSWORD_NOT_SET',
          );
        }
        throw ApiException(
          message: 'Session expired. Please log in again.',
          statusCode: 401,
          cause: e,
        );
      }
      throw ApiException(
        message: e.message ?? 'Network request failed',
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }
  }
}
