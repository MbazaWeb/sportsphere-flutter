import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart' show PlayifyApp;
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Non-blocking: Firebase, local notifications, FCM
  unawaited(_initBackgroundServices());

  runApp(const ProviderScope(child: PlayifyApp()));
}

Future<void> _initBackgroundServices() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Firebase init skipped (no config): $e');
    return;
  }
  try {
    await LocalNotificationService.instance
        .init()
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Local notifications init failed: $e');
  }
  await FcmService.instance.initAndRegister();
}
