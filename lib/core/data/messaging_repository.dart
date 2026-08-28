// lib/core/data/messaging_repository.dart
// All messaging via VPS API (/v1/social/messages) — no Supabase dependency.
// Realtime is handled by polling (Soketi integration can be added later).

import 'package:flutter/foundation.dart';
import '../../core/data/vps_repository.dart';

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
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/social/users/batch',
        query: {'ids': unique.join(',')},
      );
      final users = (res.data?['users'] as List? ?? []).cast<Map<String, dynamic>>();
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
      final res = await _vps.get<Map<String, dynamic>>('/v1/social/conversations');
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
}
