import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM device token registration.
///
/// Requires `firebase_core` and `firebase_messaging` packages plus
/// platform config files (google-services.json / GoogleService-Info.plist).
/// Edge Function `send-fcm` delivers using `FCM_SERVER_KEY` + `device_tokens`.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  bool _initialized = false;

  Future<void> initAndRegister() async {
    if (kIsWeb || _initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS / Android 13+)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Foreground presentation
      messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get and register token
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await registerToken(token, platform: Platform.isIOS ? 'ios' : 'android');
        debugPrint('FCM: token registered');
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        registerToken(newToken, platform: Platform.isIOS ? 'ios' : 'android');
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground: ${message.notification?.title}');
        // The notifications_provider already handles in-app display
        // via Supabase realtime. This ensures foreground FCM is logged.
      });

      _initialized = true;
      debugPrint('FCM: initialized successfully');
    } catch (e) {
      debugPrint('FCM init error (config may be missing): $e');
    }
  }

  Future<void> registerToken(String token, {String platform = 'android'}) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || token.isEmpty) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FCM register: $e');
    }
  }
}
