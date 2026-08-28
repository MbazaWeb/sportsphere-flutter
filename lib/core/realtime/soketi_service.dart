// lib/core/realtime/soketi_service.dart
// Soketi WebSocket client — replaces Supabase Realtime.
// Soketi is Pusher-protocol compatible — uses pusher_channels_flutter.
//
// Channel conventions:
//   public:matches          — live score updates (no auth)
//   public:feed             — trending posts (no auth)
//   private:user-{userId}   — personal notifications (auth required)
//   private:chat-{threadId} — DM thread (auth required)

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../app/config/env.dart';

class SoketiService {
  SoketiService._();
  static final SoketiService instance = SoketiService._();

  PusherChannelsFlutter? _pusher;
  bool _initialized = false;
  bool _connected   = false;
  final Map<String, PusherChannel> _channels = {};

  final _matchUpdates  = StreamController<Map<String, dynamic>>.broadcast();
  final _feedUpdates   = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _messages      = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get matchUpdates  => _matchUpdates.stream;
  Stream<Map<String, dynamic>> get feedUpdates   => _feedUpdates.stream;
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;
  Stream<Map<String, dynamic>> get messages      => _messages.stream;
  bool get isConnected => _connected;

  Future<void> init({required String userId, required String accessToken}) async {
    if (_initialized) {
      await _subscribePrivate(userId);
      return;
    }
    try {
      _pusher = PusherChannelsFlutter.getInstance();
      await _pusher!.init(
        apiKey:  'playify-app-key',
        cluster: 'mt1',
        useTLS:  true,
        // #FIX-AUTH — authEndpoint/authParams are pusher-js only: the
        // Android/iOS SDKs ignore them (and authParams expects
        // Map<String, Map<String, String>>, which made the Bearer header
        // a compile error). onAuthorizer is the cross-platform hook —
        // we perform the channel-auth POST ourselves and attach the
        // user's JWT, returning the VPS-signed auth map to the SDK.
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
          try {
            final res = await Dio(BaseOptions(
              connectTimeout: AppEnv.connectTimeout,
              receiveTimeout: AppEnv.receiveTimeout,
            )).post<Map<String, dynamic>>(
              '${AppEnv.apiBaseUrl}/v1/realtime/auth',
              data: 'socket_id=${Uri.encodeQueryComponent(socketId)}'
                    '&channel_name=${Uri.encodeQueryComponent(channelName)}',
              options: Options(headers: <String, String>{
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': 'Bearer $accessToken',
              }),
            );
            final data = res.data;
            if (data == null) return <String, dynamic>{};
            return Map<String, dynamic>.from(data);
          } catch (e) {
            debugPrint('[Soketi] authorize $channelName failed: $e');
            return <String, dynamic>{};
          }
        },
        onConnectionStateChange: (cur, prev) {
          _connected = cur == 'CONNECTED';
          debugPrint('[Soketi] $prev → $cur');
        },
        onError: (msg, code, e) => debugPrint('[Soketi] Error $code: $msg'),
        onEvent: (_) {},
      );
      await _pusher!.connect();
      _initialized = true;
      await _subscribePublic();
      await _subscribePrivate(userId);
    } catch (e) {
      debugPrint('[Soketi] init failed (polling fallback active): $e');
    }
  }

  Future<void> _subscribePublic() async {
    await _sub('public:matches', {
      'match.updated': _matchUpdates.add,
      'score.updated': _matchUpdates.add,
    });
    await _sub('public:feed', {
      'post.created':  _feedUpdates.add,
    });
  }

  Future<void> _subscribePrivate(String userId) async {
    if (userId.isEmpty) return;
    await _sub('private:user-$userId', {
      'notification':    _notifications.add,
      'message.received':_messages.add,
      'follow.new':      (d) => _notifications.add({...d, 'type': 'follow'}),
      'post.liked':      (d) => _notifications.add({...d, 'type': 'like'}),
      'post.commented':  (d) => _notifications.add({...d, 'type': 'comment'}),
    });
  }

  Future<void> _sub(String name, Map<String, void Function(Map<String,dynamic>)> handlers) async {
    if (_pusher == null || _channels.containsKey(name)) return;
    try {
      final ch = await _pusher!.subscribe(
        channelName: name,
        onEvent: (e) {
          final h = handlers[e.eventName];
          if (h == null || e.data == null) return;
          try {
            h(e.data is Map ? Map<String,dynamic>.from(e.data as Map) : {'raw': e.data});
          } catch (_) {}
        },
      );
      _channels[name] = ch;
    } catch (e) {
      debugPrint('[Soketi] sub $name failed: $e');
    }
  }

  Future<void> disconnect() async {
    try { await _pusher?.disconnect(); } catch (_) {}
    _channels.clear();
    _initialized = false;
    _connected   = false;
  }

  void dispose() {
    _matchUpdates.close();
    _feedUpdates.close();
    _notifications.close();
    _messages.close();
  }
}
