import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart' show SportSphereApp;
import 'app/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence logger in release builds — never leak logs to production console
  Logger.level = kDebugMode ? Level.debug : Level.off;

  if (!AppEnv.isConfigured) {
    // Show a clear error screen instead of a cryptic crash
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const ProviderScope(child: SportSphereApp()));
}

/// Shown when --dart-define vars are missing (e.g. bare `flutter run` with no defines).
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
                  'Run with:\n'
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_URL=https://... \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=...',
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
