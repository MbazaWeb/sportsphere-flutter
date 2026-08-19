import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'https://api.sportsphere.app';

  static String get supabaseUrl => dotenv.maybeGet('SUPABASE_URL') ?? '';

  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY') ??
      dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY') ??
      '';

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);
}
