// lib/features/notifications/notifications_provider.dart
// All notification ops via VPS API — no Supabase dependency.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/vps_repository.dart';

// ── State ──────────────────────────────────────────────────────────────────
class NotificationState {
  const NotificationState({
    this.notifications = const [],
    this.unreadCount   = 0,
    this.isLoading     = false,
  });
  final List<Map<String, dynamic>> notifications;
  final int                        unreadCount;
  final bool                       isLoading;

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

// ── Notifier ────────────────────────────────────────────────────────────────
class NotificationsNotifier extends StateNotifier<NotificationState> {
  NotificationsNotifier() : super(const NotificationState());

  static final _vps = const VpsRepository();
  Timer? _pollTimer;

  void start() {
    load();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load({int limit = 50}) async {
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

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ── Providers ───────────────────────────────────────────────────────────────
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationState>(
  (ref) => NotificationsNotifier()..start(),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
