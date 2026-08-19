import 'package:dio/dio.dart';

typedef TokenReader = Future<String?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._readToken);

  final TokenReader _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
