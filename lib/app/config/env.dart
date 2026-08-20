// ignore_for_file: do_not_use_environment

/// Environment configuration resolved from --dart-define compile-time constants.
///
/// Build with:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key \
///     --dart-define=API_BASE_URL=https://api.sportsphere.app
///
/// For development:
///   flutter run \
///     --dart-define=SUPABASE_URL=http://localhost:54321 \
///     --dart-define=SUPABASE_ANON_KEY=dev-anon-key \
///     --dart-define=API_BASE_URL=http://localhost:3000
///
/// Never bundle .env files as Flutter assets — they are embedded in the APK
/// in plaintext and trivially extracted. dart-define values are compiled in.
///
/// **IMPORTANT:** Always check [AppEnv.isConfigured] before using any values.
/// If false, show a user-friendly error screen indicating missing configuration.
class AppEnv {
  const AppEnv._();

  // ============================================================
  // REQUIRED CONFIGURATION (No defaults - must be provided)
  // ============================================================

  /// Supabase URL - MUST be provided via --dart-define
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase Anon Key - MUST be provided via --dart-define
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ============================================================
  // OPTIONAL CONFIGURATION (With sensible defaults)
  // ============================================================

  /// API Base URL - Provide via --dart-define to override default
  /// Defaults to production endpoint
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sportsphere.app',
  );

  // ============================================================
  // NETWORK TIMEOUTS (Hardcoded - not environment specific)
  // ============================================================

  /// Connection timeout for HTTP requests
  static const Duration connectTimeout = Duration(seconds: 20);

  /// Receive timeout for HTTP requests
  static const Duration receiveTimeout = Duration(seconds: 20);

  // ============================================================
  // VALIDATION
  // ============================================================

  /// Returns true if all required vars were provided at compile time.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Returns a human-readable error message if configuration is missing.
  static String? get configurationError {
    if (isConfigured) return null;

    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');

    return 'Missing required environment variables: ${missing.join(', ')}.\n'
        'Please provide them using --dart-define at build time.\n'
        'Example: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...';
  }

  /// Returns the current environment name (useful for logging/tracking)
  static String get environmentName {
    if (apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1')) {
      return 'development';
    }
    if (apiBaseUrl.contains('staging')) {
      return 'staging';
    }
    return 'production';
  }
}