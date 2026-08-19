import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsphere_app/core/network/api_client.dart';
import 'package:sportsphere_app/core/network/api_exception.dart';

void main() {
  group('ApiClient', () {
    late ApiClient client;

    setUp(() {
      // Inject a mock Dio that immediately throws a 401
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
      client = ApiClient(readToken: () async => 'test-token', dio: mockDio);
    });

    test('wraps 401 DioException as ApiException with status 401', () async {
      expect(
        () => client.get<dynamic>('/protected'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('ApiException toString includes status code', () {
      const ex = ApiException(message: 'fail', statusCode: 404);
      expect(ex.toString(), contains('404'));
    });
  });
}
