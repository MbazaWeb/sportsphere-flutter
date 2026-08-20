import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  Future<Map<String, PeerProfile>> resolvePeers(Iterable<String> ids) async {
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};
    final out = <String, PeerProfile>{};

    try {
      final rows = await _sb
          .from('User')
          .select('id, name, handle, avatarUrl')
          .inFilter('id', unique);
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = '${m['id']}';
        out[id] = PeerProfile(
          id: id,
          name: (m['name'] as String?)?.trim() ?? '',
          handle: (m['handle'] as String?)?.trim() ?? '',
          avatarUrl: m['avatarUrl'] as String?,
        );
      }
    } catch (e) {
      debugPrint('resolvePeers User: $e');
    }

    final missing = unique.where((id) => !out.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      try {
        final rows = await _sb
            .from('profiles')
            .select('id, first_name, last_name, handle, avatar_url')
            .inFilter('id', missing);
        for (final r in rows as List) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = '${m['id']}';
          final fn = (m['first_name'] as String?) ?? '';
          final ln = (m['last_name'] as String?) ?? '';
          final name = '$fn $ln'.trim();
          out[id] = PeerProfile(
            id: id,
            name: name,
            handle: (m['handle'] as String?)?.trim() ?? '',
            avatarUrl: m['avatar_url'] as String?,
          );
        }
      } catch (e) {
        debugPrint('resolvePeers profiles: $e');
      }
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
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _sb
          .from('Message')
          .select()
          .or('senderId.eq.$uid,receiverId.eq.$uid')
          .order('createdAt', ascending: false)
          .limit(200);
      final list = [
        for (final r in rows as List) Map<String, dynamic>.from(r as Map)
      ];
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final m in list) {
        final peer = m['senderId'] == uid ? m['receiverId'] : m['senderId'];
        final key = '$peer';
        if (seen.add(key)) {
          out.add({...m, 'peerId': peer});
        }
      }
      final peers = await resolvePeers(out.map((e) => '${e['peerId']}'));
      return [
        for (final m in out)
          {
            ...m,
            'peer': peers['${m['peerId']}'],
            'peerName': peers['${m['peerId']}']?.display ?? '${m['peerId']}',
            'peerHandle': peers['${m['peerId']}']?.handle ?? '',
            'peerAvatar': peers['${m['peerId']}']?.avatarUrl,
          }
      ];
    } catch (e) {
      debugPrint('listConversations: $e');
      return [];
    }
  }

  /// Safer than nested or/and PostgREST filters.
  Future<List<Map<String, dynamic>>> threadWith(String peerId) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final a = await _sb
          .from('Message')
          .select()
          .eq('senderId', uid)
          .eq('receiverId', peerId)
          .order('createdAt', ascending: true)
          .limit(200);
      final b = await _sb
          .from('Message')
          .select()
          .eq('senderId', peerId)
          .eq('receiverId', uid)
          .order('createdAt', ascending: true)
          .limit(200);
      final merged = <Map<String, dynamic>>[
        for (final r in a as List) Map<String, dynamic>.from(r as Map),
        for (final r in b as List) Map<String, dynamic>.from(r as Map),
      ];
      merged.sort((x, y) {
        final tx = DateTime.tryParse('${x['createdAt']}') ?? DateTime(1970);
        final ty = DateTime.tryParse('${y['createdAt']}') ?? DateTime(1970);
        return tx.compareTo(ty);
      });
      // mark incoming as read
      try {
        await _sb
            .from('Message')
            .update({'isRead': true})
            .eq('senderId', peerId)
            .eq('receiverId', uid)
            .eq('isRead', false);
      } catch (e) {
        debugPrint('markRead: $e');
      }
      return merged;
    } catch (e) {
      debugPrint('threadWith: $e');
      return [];
    }
  }

  /// Realtime channel for a 1:1 thread (both directions).
  RealtimeChannel subscribeThread({
    required String peerId,
    required void Function(Map<String, dynamic> row) onInsert,
  }) {
    final uid = _uid ?? '';
    final channel = _sb.channel('dm-$uid-$peerId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Message',
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final s = '${row['senderId']}';
            final r = '${row['receiverId']}';
            final mine = (s == uid && r == peerId) || (s == peerId && r == uid);
            if (mine) onInsert(row);
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> send(String receiverId, String content) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to message');
    if (content.trim().isEmpty) throw StateError('Empty message');
    await _sb.from('Message').insert({
      'senderId': uid,
      'receiverId': receiverId,
      'content': content.trim(),
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    try {
      await _sb.rpc('create_notification', params: {
        'p_user_id': receiverId,
        'p_type': 'message',
        'p_title': 'New message',
        'p_body': content.length > 60 ? '${content.substring(0, 60)}…' : content,
        'p_actor_id': uid,
        'p_reference_id': null,
        'p_target_id': uid,
        'p_target_type': 'user',
      });
    } catch (e) {
      debugPrint('notify message: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final query = q.trim().replaceAll('@', '');
    if (query.length < 2) return [];
    try {
      final rows = await _sb
          .from('User')
          .select('id, name, handle, avatarUrl')
          .or('handle.ilike.%$query%,name.ilike.%$query%')
          .limit(20);
      return [
        for (final r in rows as List) Map<String, dynamic>.from(r as Map)
      ];
    } catch (e) {
      debugPrint('searchUsers: $e');
      return [];
    }
  }
}
