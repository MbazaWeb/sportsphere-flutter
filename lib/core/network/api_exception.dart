class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? code;   // e.g. 'PASSWORD_NOT_SET'
  final Object? cause;

  bool get isPasswordNotSet => code == 'PASSWORD_NOT_SET';

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}
