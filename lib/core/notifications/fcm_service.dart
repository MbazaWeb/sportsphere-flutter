import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM device token registration.
///
/// Full push requires Firebase project + `google-services.json` /
/// `GoogleService-Info.plist` and the packages `firebase_core` +
/// `firebase_messaging`. Until then tokens can still be stored when
/// provided (e.g. from a future native channel). Edge Function
/// `send-fcm` delivers using `FCM_SERVER_KEY` + `device_tokens`.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  Future<void> initAndRegister() async {
    if (kIsWeb) return;
    // Hook: when Firebase is configured, obtain token and call registerToken.
    debugPrint(
      'FCM: add Firebase config then wire FirebaseMessaging.getToken() → registerToken',
    );
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
