import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// FCM device token registration.
/// Registers tokens via VPS API (POST /v1/fcm/register) with Supabase fallback.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  bool _initialized = false;
  StreamSubscription<String>?        _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;

  Future<void> initAndRegister() async {
    if (kIsWeb || _initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      ).timeout(const Duration(seconds: 10));

      messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      final token = await messaging.getToken().timeout(const Duration(seconds: 10));
      if (token != null && token.isNotEmpty) {
        await registerToken(token, platform: platform);
        debugPrint('FCM: token registered');
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((t) => registerToken(t, platform: platform));

      _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('FCM foreground: ${msg.notification?.title}');
      });

      _initialized = true;
      debugPrint('FCM: initialized');
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel(); _tokenRefreshSub = null;
    _onMessageSub?.cancel();   _onMessageSub   = null;
    _initialized = false;
  }

  Future<void> registerToken(String token, {String platform = 'android'}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || token.isEmpty) return;

    // Try VPS API first
    try {
      await _postToVps(
        path:    '/v1/fcm/register',
        token:   session.accessToken,
        body:    {'token': token, 'platform': platform},
      );
      return;
    } catch (e) {
      debugPrint('FCM VPS register failed, using Supabase fallback: $e');
    }

    // Fallback: direct Supabase upsert
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id':    session.user.id,
        'token':      token,
        'platform':   platform,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FCM fallback also failed: $e');
    }
  }

  /// Lightweight HTTP POST to VPS — no Dio dependency here
  static Future<void> _postToVps({
    required String path,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    const base = String.fromEnvironment('API_BASE_URL',
        defaultValue: 'https://api.playify.app');
    final uri = Uri.parse('$base$path');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');
      req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.drain<void>();
    } finally {
      client.close();
    }
  }
}
