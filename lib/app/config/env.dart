/// Compile-time / runtime API configuration.
/// Override with: flutter run --dart-define=API_BASE_URL=https://api.example.com
class AppEnv {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sportsphere.app',
  );

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);
}
