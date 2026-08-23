import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM device token registration.
///
/// Requires `firebase_core` and `firebase_messaging` packages plus
/// platform config files (google-services.json / GoogleService-Info.plist).
/// Edge Function `send-fcm` delivers via FCM HTTP v1 + `device_tokens`.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  bool _initialized = false;

  // M14 — Hold the StreamSubscription for `onTokenRefresh` so we can cancel
  // it when the service is no longer needed. Without this the listener
  // leaks forever once [initAndRegister] has run.
  StreamSubscription<String>? _tokenRefreshSub;
  // Foreground message stream — also cancelled in [dispose].
  StreamSubscription<RemoteMessage>? _onMessageSub;

  Future<void> initAndRegister() async {
    if (kIsWeb || _initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS / Android 13+)
      await messaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
          .timeout(const Duration(seconds: 10));

      // Foreground presentation
      messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get and register token
      final token = await messaging.getToken().timeout(const Duration(seconds: 10));
      if (token != null && token.isNotEmpty) {
        await registerToken(token, platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
        debugPrint('FCM: token registered');
      }

      // Listen for token refreshes — store the subscription so we can cancel
      // it in [dispose]. Re-registering the same listener on a re-init would
      // create duplicate upserts.
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        registerToken(newToken, platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
      });

      // Handle foreground messages — also tracked for cleanup.
      _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
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

  /// Cancels the `onTokenRefresh` and `onMessage` stream subscriptions.
  ///
  /// Safe to call multiple times. Currently invoked from the app lifecycle
  /// dispose path (e.g. when the user signs out and we want to tear down
  /// FCM before the next session).
  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub?.cancel();
    _onMessageSub = null;
    _initialized = false;
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
