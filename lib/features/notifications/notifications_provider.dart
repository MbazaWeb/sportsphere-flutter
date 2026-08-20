import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NotificationType { like, comment, follow, mention, repost, sports, message }

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final String time;
  bool unread;

  NotificationItem copyWith({bool? unread}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        time: time,
        unread: unread ?? this.unread,
      );
}

class NotificationsState {
  const NotificationsState({required this.items, this.loading = false});
  final List<NotificationItem> items;
  final bool loading;

  int get unreadCount => items.where((n) => n.unread).length;

  NotificationsState copyWith({List<NotificationItem>? items, bool? loading}) =>
      NotificationsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
      );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    Future.microtask(load);
    return const NotificationsState(items: [], loading: true);
  }

  Future<void> load() async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) {
      state = const NotificationsState(items: []);
      return;
    }
    try {
      final rows = await sb
          .from('Notification')
          .select()
          .eq('userId', uid)
          .order('createdAt', ascending: false)
          .limit(50);
      final items = <NotificationItem>[];
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        items.add(NotificationItem(
          id: m['id']?.toString() ?? '',
          type: _typeOf(m['type']?.toString()),
          title: (m['title'] as String?) ?? (m['body'] as String?) ?? 'Notification',
          subtitle: (m['body'] as String?) ?? '',
          time: _age(m['createdAt']?.toString()),
          unread: (m['isRead'] as bool?) != true && (m['read'] as bool?) != true,
        ));
      }
      state = NotificationsState(items: items);
    } catch (_) {
      state = const NotificationsState(items: []);
    }
  }

  void markRead(String id) {
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(unread: false) : n)
          .toList(),
    );
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      Supabase.instance.client
          .from('Notification')
          .update({'isRead': true})
          .eq('id', id);
    } catch (_) {}
  }

  void markAllRead() {
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(unread: false)).toList(),
    );
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      Supabase.instance.client
          .from('Notification')
          .update({'isRead': true})
          .eq('userId', uid);
    } catch (_) {}
  }

  static NotificationType _typeOf(String? t) {
    switch ((t ?? '').toLowerCase()) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'mention':
        return NotificationType.mention;
      case 'repost':
      case 'share':
        return NotificationType.repost;
      case 'message':
        return NotificationType.message;
      default:
        return NotificationType.sports;
    }
  }

  static String _age(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);
