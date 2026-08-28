// ignore_for_file: do_not_use_environment

/// Environment configuration from --dart-define compile-time constants.
class AppEnv {
  const AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://playifysport.fun',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  static String get environmentName {
    if (apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1')) {
      return 'development';
    }
    if (apiBaseUrl.contains('staging')) return 'staging';
    return 'production';
  }
}
