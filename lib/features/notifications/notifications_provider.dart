// lib/features/notifications/notifications_provider.dart
// All notification ops via VPS API — no Supabase dependency.
//
// Riverpod 3.x: `StateNotifier`/`StateNotifierProvider` were removed.
// This file now uses `Notifier`/`NotifierProvider`. The polling timer is
// cleaned up via `ref.onDispose` (no `dispose()` override needed).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/vps_repository.dart';
import '../auth/presentation/auth_controller.dart';

// ── Notification type enum ───────────────────────────────────────────────────
//
// Used by the shell notifications screen (`lib/features/shell/parts/
// notifications.dart`) to bucket notifications into tabs (Social / Sports /
// Messages) and to pick the right icon for each tile.
enum NotificationType {
  like,
  comment,
  follow,
  mention,
  repost,
  sports,
  message,
}

// ── Typed notification item ──────────────────────────────────────────────────
//
// The VPS API returns notifications as `Map<String, dynamic>` rows. The UI
// layer (notifications.dart tile) needs typed field access (`.type`,
// `.title`, `.subtitle`, `.time`, `.id`, `.unread`), so we wrap each row
// in a [NotificationItem] with a parsed type + pre-formatted relative time.
class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
  });

  /// Build a [NotificationItem] from a VPS notification row.
  ///
  /// Tolerates both camelCase (`createdAt`, `userId`) and snake_case
  /// (`created_at`, `user_id`) keys, and several synonyms for the `type`
  /// field (`share` → [NotificationType.repost], `dm` → [NotificationType.message]).
  factory NotificationItem.fromMap(Map<String, dynamic> m) {
    return NotificationItem(
      id:       (m['id'] ?? '').toString(),
      type:     _parseType(m['type'] ?? m['kind']),
      title:    (m['title'] ?? m['body'] ?? m['message'] ?? '').toString(),
      subtitle: (m['body'] ?? m['message'] ?? m['preview'] ?? '').toString(),
      time:     _formatTime(m['createdAt'] ?? m['created_at']),
      unread:   m['read'] != true,
    );
  }

  static NotificationType _parseType(dynamic t) {
    switch (t?.toString().toLowerCase()) {
      case 'like':
      case 'post_like':
        return NotificationType.like;
      case 'comment':
      case 'post_comment':
        return NotificationType.comment;
      case 'follow':
      case 'new_follower':
        return NotificationType.follow;
      case 'mention':
      case 'mentioned':
        return NotificationType.mention;
      case 'repost':
      case 'share':
      case 'post_share':
        return NotificationType.repost;
      case 'message':
      case 'dm':
      case 'direct_message':
        return NotificationType.message;
      case 'sports':
      case 'sport':
      case 'match':
      case 'fixture':
      case 'kickoff':
        return NotificationType.sports;
      default:
        return NotificationType.sports;
    }
  }

  static String _formatTime(dynamic t) {
    final dt = DateTime.tryParse(t?.toString() ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── State ──────────────────────────────────────────────────────────────────
class NotificationState {
  const NotificationState({
    this.notifications = const [],
    this.unreadCount   = 0,
    this.isLoading     = false,
  });

  /// Raw notification rows from the VPS API (`Map<String, dynamic>`).
  final List<Map<String, dynamic>> notifications;
  final int                        unreadCount;
  final bool                       isLoading;

  /// Typed view of [notifications] for the UI layer.
  ///
  /// Re-built on every access; if this becomes a hot path, cache the
  /// result. For typical notification list sizes (<100 items) the cost
  /// is negligible.
  List<NotificationItem> get items =>
      notifications.map(NotificationItem.fromMap).toList();

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) => NotificationState(
    notifications: notifications ?? this.notifications,
    unreadCount:   unreadCount   ?? this.unreadCount,
    isLoading:     isLoading     ?? this.isLoading,
  );
}

// ── Notifier (Riverpod 3.x — extends Notifier, not StateNotifier) ───────────
class NotificationsNotifier extends Notifier<NotificationState> {
  static final _vps = const VpsRepository();
  Timer? _pollTimer;

  @override
  NotificationState build() {
    // Defer start() until after build() returns — Riverpod initialises
    // `state` to the value returned by build(), so accessing `state`
    // inside load() (called from start()) before build() returns would
    // throw. The microtask runs after build() has returned and `state`
    // is initialised. The `ref.mounted` guard handles the case where the
    // provider was disposed between build() returning and the microtask
    // firing (e.g. fast nav away from the notifications screen).
    Future.microtask(() {
      if (!ref.mounted) return;
      // Only poll if user is logged in
      final auth = ref.read(authControllerProvider);
      if (auth.status == AuthStatus.authenticated) start();
    });
    ref.onDispose(stop);
    return const NotificationState();
  }

  /// Begin polling the VPS for new notifications every 30s.
  void start() {
    load();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  /// Stop polling (called automatically when the provider is disposed).
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load({int limit = 50}) async {
    // Skip if not logged in — avoids 401 on app start
    final auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) return;
    state = state.copyWith(isLoading: true);
    try {
      final items = await _vps.getNotifications(limit: limit);
      final unread = items.where((n) => n['read'] != true).length;
      state = state.copyWith(notifications: items, unreadCount: unread, isLoading: false);
    } catch (e) {
      debugPrint('[NOTIF] load failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _vps.markRead(id);
      final updated = state.notifications.map((n) =>
        n['id'] == id ? {...n, 'read': true} : n,
      ).toList();
      final unread = updated.where((n) => n['read'] != true).length;
      state = state.copyWith(notifications: updated, unreadCount: unread);
    } catch (e) {
      debugPrint('[NOTIF] markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _vps.markAllRead();
      final updated = state.notifications.map((n) => {...n, 'read': true}).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (e) {
      debugPrint('[NOTIF] markAllRead failed: $e');
    }
  }
}

// ── Providers ───────────────────────────────────────────────────────────────
//
// Riverpod 3.x: `StateNotifierProvider` was removed. Use `NotifierProvider`
// with a `Notifier` subclass + `.new` constructor reference.
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationState>(
  NotificationsNotifier.new,
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
