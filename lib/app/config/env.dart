// ignore_for_file: do_not_use_environment

/// Environment configuration resolved from --dart-define compile-time constants.
///
/// Build with:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key
///
/// Never bundle .env files as Flutter assets — they are embedded in the APK
/// in plaintext and trivially extracted. dart-define values are compiled in.
class AppEnv {
  const AppEnv._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sportsphere.app',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Returns true if all required vars were provided at compile time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
