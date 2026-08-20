import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart' show SportSphereApp;
import 'app/config/env.dart';
import 'core/notifications/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.level = kDebugMode ? Level.debug : Level.off;

  if (!AppEnv.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );

  // Drop stale / cross-project JWTs that cause REST 401 on profiles.
  await _ensureValidSession();
  await LocalNotificationService.instance.init();

  runApp(const ProviderScope(child: SportSphereApp()));
}

Future<void> _ensureValidSession() async {
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) return;
  try {
    // Validates access token against Auth API (not only local storage).
    await client.auth.getUser();
  } catch (_) {
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_soccer, color: Color(0xFFD4AF37), size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Missing configuration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SUPABASE_URL and SUPABASE_ANON_KEY must be set.\n\n'
                  'Use the JWT anon key (starts with eyJ...), not only the sb_publishable_ key.\n\n'
                  'flutter run -d chrome \\\n'
                  '  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=eyJ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF999999), fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
