import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playify/core/network/api_client.dart';
import 'package:playify/core/network/api_exception.dart';

// ApiClient wraps Dio for non-Supabase REST calls.
// readToken is optional — defaults to reading Supabase.auth.currentSession.
// Tests inject a mock Dio and an explicit readToken to stay offline.
void main() {
  group('ApiClient', () {
    late ApiClient client;

    setUp(() {
      final mockDio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  statusMessage: 'Unauthorized',
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      // Inject explicit token reader so test doesn't need Supabase initialised
      client = ApiClient(readToken: () async => 'test-token', dio: mockDio);
    });

    test('wraps 401 DioException as ApiException with statusCode 401', () {
      expect(
        () => client.get<dynamic>('/protected'),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );
    });

    test('ApiException toString includes status code', () {
      const ex = ApiException(message: 'fail', statusCode: 404);
      expect(ex.toString(), contains('404'));
    });
  });
}
