// ignore_for_file: do_not_use_environment

/// Environment configuration from --dart-define compile-time constants.
///
/// Prefer the **JWT anon key** (starts with `eyJ...`) for SUPABASE_ANON_KEY.
/// A publishable key (`sb_publishable_...`) is accepted as a fallback alias.
class AppEnv {
  const AppEnv._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _anon = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String _publishable = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Resolved client key: JWT anon preferred, then publishable.
  static String get supabaseAnonKey =>
      _anon.isNotEmpty ? _anon : _publishable;

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.playify.app',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String? get configurationError {
    if (isConfigured) return null;
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) {
      missing.add('SUPABASE_ANON_KEY (or SUPABASE_PUBLISHABLE_KEY)');
    }
    return 'Missing required environment variables: ${missing.join(', ')}.\n'
        'Example: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=eyJ...';
  }

  static String get environmentName {
    if (apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1')) {
      return 'development';
    }
    if (apiBaseUrl.contains('staging')) return 'staging';
    return 'production';
  }
}
