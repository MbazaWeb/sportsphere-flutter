/// Public runtime config only. Never put service-role or DB passwords here.
class AppEnv {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sportsphere.app',
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vqyfybuloyqahgoagmzd.supabase.co',
  );

  /// Anon / publishable key (safe in the client with RLS).
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxeWZ5YnVsb3lxYWhnb2FnbXpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwMjE3OTgsImV4cCI6MjEwMjU5Nzc5OH0.oddZU-z2x_svFeWgSA-bvCLncCsxRF3r1LCC4Xiexx8',
  );

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);
}
