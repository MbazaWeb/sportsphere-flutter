import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FCM device token registration via VPS API — no Supabase dependency.
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
    if (token.isEmpty) return;
    final prefs    = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_access_token');
    if (authToken == null) return;

    try {
      await _postToVps(
        path:      '/v1/fcm/register',
        authToken: authToken,
        body:      {'token': token, 'platform': platform},
      );
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }

  static Future<void> _postToVps({
    required String path,
    required String authToken,
    required Map<String, dynamic> body,
  }) async {
    const base = String.fromEnvironment('API_BASE_URL',
        defaultValue: 'https://playifysport.fun');
    final uri    = Uri.parse('$base$path');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $authToken');
      req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.drain<void>();
    } finally {
      client.close();
    }
  }
}
