import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/env.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApiClient — Dio wrapper for REST endpoints outside Supabase.
//
// The token reader now pulls from Supabase.instance.client.auth.currentSession
// so the Bearer header always carries the current Supabase JWT.
// ─────────────────────────────────────────────────────────────────────────────

String? _supabaseToken() =>
    Supabase.instance.client.auth.currentSession?.accessToken;

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
    // Use Supabase token by default; allow injection for tests.
    _dio.interceptors
        .add(AuthInterceptor(readToken ?? () async => _supabaseToken()));
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
