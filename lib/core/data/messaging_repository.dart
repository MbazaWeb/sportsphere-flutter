// lib/core/data/messaging_repository.dart
// All messaging via VPS API (/v1/social/messages) — no Supabase dependency.
// Realtime is handled by polling (Soketi integration can be added later).

import 'package:flutter/foundation.dart';
import '../../core/data/vps_repository.dart';

/// No-op realtime channel returned by [MessagingRepository.subscribeThread].
///
/// Supabase realtime is being removed; the VPS websocket (Soketi) migration
/// is not yet deployed. Until then, callers should poll
/// [MessagingRepository.threadWith] periodically (every ~10s) to pick up new
/// messages. This stub keeps the call-site signature stable so the eventual
/// Soketi migration only needs to swap the body of `subscribeThread`.
class NoopRealtimeChannel {
  NoopRealtimeChannel();
  void subscribe() {}
  void unsubscribe() {}
}

class PeerProfile {
  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;

  const PeerProfile({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
  });

  String get display => name.trim().isNotEmpty ? name : '@$handle';
  String get atHandle => handle.isEmpty ? '' : '@$handle';
}

class MessagingRepository {
  static final _vps = const VpsRepository();

  Future<Map<String, PeerProfile>> resolvePeers(Iterable<String> ids) async {
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};
    final out = <String, PeerProfile>{};
    try {
      final res = await _vps.post<Map<String, dynamic>>(
        '/v1/social/profiles/batch',
        data: {'ids': unique},
      );
      final users = (res.data?['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final u in users) {
        final id = '${u['id']}';
        final fn = (u['first_name'] ?? u['firstName'] ?? '') as String;
        final ln = (u['last_name']  ?? u['lastName']  ?? '') as String;
        out[id] = PeerProfile(
          id: id,
          name: '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (u['name'] as String? ?? ''),
          handle: (u['handle'] as String?)?.trim() ?? '',
          avatarUrl: (u['avatar_url'] ?? u['avatarUrl']) as String?,
        );
      }
    } catch (e) {
      debugPrint('resolvePeers: $e');
    }
    for (final id in unique) {
      out.putIfAbsent(
        id,
        () => PeerProfile(id: id, name: 'User', handle: id.substring(0, 8)),
      );
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/social/messages');
      return ((res.data?['conversations']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('listConversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> threadWith(String peerId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/social/messages/$peerId');
      return ((res.data?['messages']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('threadWith: $e');
      return [];
    }
  }

  Future<void> send(String receiverId, String content) async {
    if (content.trim().isEmpty) throw StateError('Empty message');
    await _vps.post<void>('/v1/social/messages', data: {
      'receiverId': receiverId,
      'content':    content.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final query = q.trim().replaceAll('@', '');
    if (query.length < 2) return [];
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/social/search', query: {'q': query, 'limit': 20},
      );
      return ((res.data?['results']) as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((r) => r['_kind'] == 'user' || r['role'] == 'fan')
          .toList();
    } catch (e) {
      debugPrint('searchUsers: $e');
      return [];
    }
  }

  /// Subscribe to realtime updates for a thread with [peerId].
  ///
  /// **STUB** — Supabase realtime is being removed and the VPS websocket
  /// (Soketi) migration is not yet deployed. The returned
  /// [NoopRealtimeChannel] does nothing; [onInsert] will never fire.
  /// Callers should poll [threadWith] periodically (every ~10s) until the
  /// Soketi integration lands. The signature is stable so the eventual
  /// migration only needs to swap the body of this method.
  ///
  /// Returns `dynamic` (rather than [NoopRealtimeChannel]) so call sites
  /// that still type their channel variable as the legacy
  /// `RealtimeChannel?` (from `package:supabase_flutter`) compile without
  /// an explicit cast — once the Soketi migration lands, this return type
  /// can be tightened to whatever channel type the websocket client exposes.
  dynamic subscribeThread({
    required String peerId,
    required void Function(Map<String, dynamic> row) onInsert,
  }) {
    debugPrint('[MSG] subscribeThread: realtime disabled (peerId=$peerId) — '
        'poll threadWith() until Soketi migration lands');
    return NoopRealtimeChannel();
  }
}
