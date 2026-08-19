import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

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

// ── State ──────────────────────────────────────────────────────────────────────

class NotificationsState {
  const NotificationsState({required this.items});
  final List<NotificationItem> items;

  int get unreadCount => items.where((n) => n.unread).length;

  NotificationsState copyWith({List<NotificationItem>? items}) =>
      NotificationsState(items: items ?? this.items);
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    return NotificationsState(items: _mockNotifications());
  }

  void markRead(String id) {
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(unread: false) : n)
          .toList(),
    );
  }

  void markAllRead() {
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(unread: false)).toList(),
    );
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);

// ── Mock data ──────────────────────────────────────────────────────────────────

List<NotificationItem> _mockNotifications() => [
      NotificationItem(
        id: 'n1',
        type: NotificationType.like,
        title: 'Clatous Chama liked your post',
        subtitle: 'What. A. Game!',
        time: '2m',
        unread: true,
      ),
      NotificationItem(
        id: 'n2',
        type: NotificationType.comment,
        title: 'Ali Kingu commented on your post',
        subtitle: 'Great football analysis.',
        time: '8m',
        unread: true,
      ),
      NotificationItem(
        id: 'n3',
        type: NotificationType.follow,
        title: 'SportSphere Fan started following you',
        subtitle: 'Fan',
        time: '18m',
        unread: true,
      ),
      NotificationItem(
        id: 'n4',
        type: NotificationType.mention,
        title: 'Young Africans mentioned you',
        subtitle: 'in a community discussion',
        time: '32m',
        unread: false,
      ),
      NotificationItem(
        id: 'n5',
        type: NotificationType.repost,
        title: 'Man City reposted your post',
        subtitle: 'Three points away from home.',
        time: '1h',
        unread: false,
      ),
      NotificationItem(
        id: 'n6',
        type: NotificationType.sports,
        title: 'Match started',
        subtitle: 'Simba SC vs Young Africans',
        time: '2h',
        unread: false,
      ),
      NotificationItem(
        id: 'n7',
        type: NotificationType.message,
        title: 'Clatous Chama sent you a message',
        subtitle: 'Are you watching the match?',
        time: '3h',
        unread: true,
      ),
      NotificationItem(
        id: 'n8',
        type: NotificationType.message,
        title: 'SportSphere Fan sent you a message',
        subtitle: 'I agree with your prediction.',
        time: '4h',
        unread: false,
      ),
    ];
