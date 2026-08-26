import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/local_notification_service.dart';

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
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;

  @override
  NotificationsState build() {
    ref.onDispose(() {
      _channel?.unsubscribe();
      _authSub?.cancel();
    });
    Future.microtask(() async {
      await LocalNotificationService.instance.init();
      await load();
      _bindAuth();
      await _subscribeRealtime();
    });
    return const NotificationsState(items: [], loading: true);
  }

  void _bindAuth() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      load();
      _subscribeRealtime();
    });
  }

  Future<void> _subscribeRealtime() async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    await _channel?.unsubscribe();
    _channel = null;
    if (uid == null) return;

    _channel = sb
        .channel('notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Notification',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'userId',
            value: uid,
          ),
          callback: (payload) {
            final m = payload.newRecord;
            final item = NotificationItem(
              id: m['id']?.toString() ?? '',
              type: _typeOf(m['type']?.toString()),
              title: (m['title'] as String?) ??
                  (m['body'] as String?) ??
                  'Notification',
              subtitle: (m['body'] as String?) ?? '',
              time: 'now',
              unread: true,
            );
            final next = [item, ...state.items];
            // de-dupe by id
            final seen = <String>{};
            final unique = <NotificationItem>[];
            for (final n in next) {
              if (n.id.isEmpty || seen.add(n.id)) unique.add(n);
            }
            state = state.copyWith(items: unique.take(50).toList());
            unawaited(LocalNotificationService.instance.show(
              title: item.title,
              body: item.subtitle.isEmpty ? 'Open Playify' : item.subtitle,
              payload: item.id,
            ));
            if (kDebugMode) {
              debugPrint('Realtime notification: ${item.title}');
            }
          },
        )
        .subscribe();
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
          title:
              (m['title'] as String?) ?? (m['body'] as String?) ?? 'Notification',
          subtitle: (m['body'] as String?) ?? '',
          time: _age(m['createdAt']?.toString()),
          unread:
              (m['isRead'] as bool?) != true && (m['read'] as bool?) != true,
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
      case 'follow_activity':
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
