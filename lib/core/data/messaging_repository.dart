import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingRepository {
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> listConversations() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _sb
          .from('Message')
          .select()
          .or('senderId.eq.$uid,receiverId.eq.$uid')
          .order('createdAt', ascending: false)
          .limit(100);
      final list = [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
      // Collapse to latest per peer
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final m in list) {
        final peer = m['senderId'] == uid ? m['receiverId'] : m['senderId'];
        final key = '$peer';
        if (seen.add(key)) {
          out.add({...m, 'peerId': peer});
        }
      }
      return out;
    } catch (e) {
      debugPrint('listConversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> threadWith(String peerId) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _sb
          .from('Message')
          .select()
          .or('and(senderId.eq.$uid,receiverId.eq.$peerId),and(senderId.eq.$peerId,receiverId.eq.$uid)')
          .order('createdAt', ascending: true)
          .limit(200);
      return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
    } catch (e) {
      debugPrint('threadWith: $e');
      return [];
    }
  }

  Future<void> send(String receiverId, String content) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to message');
    if (content.trim().isEmpty) throw StateError('Empty message');
    await _sb.from('Message').insert({
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
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
      debugPrint('msg notify: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    if (q.trim().isEmpty) return [];
    try {
      final rows = await _sb
          .from('User')
          .select('id,name,handle,avatarUrl')
          .or('handle.ilike.%${q.trim()}%,name.ilike.%${q.trim()}%')
          .limit(20);
      return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
    } catch (e) {
      debugPrint('searchUsers: $e');
      return [];
    }
  }
}
