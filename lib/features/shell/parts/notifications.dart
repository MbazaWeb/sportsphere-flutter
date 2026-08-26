part of '../app_shell.dart';

class _NotificationsScreen extends ConsumerStatefulWidget {
  const _NotificationsScreen();

  @override
  ConsumerState<_NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<_NotificationsScreen> {
  int _tab = 0;

  static const _tabs = ['All', 'Social', 'Sports', 'Messages'];

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);
    final notifNotifier = ref.read(notificationsProvider.notifier);
    final all = notifState.items;

    final visible = _tab == 0
        ? all
        : all.where((n) {
            if (_tab == 1) {
              return {
                NotificationType.like,
                NotificationType.comment,
                NotificationType.follow,
                NotificationType.mention,
                NotificationType.repost,
              }.contains(n.type);
            }
            if (_tab == 2) return n.type == NotificationType.sports;
            return n.type == NotificationType.message;
          }).toList();

    return Scaffold(
      backgroundColor: PlayifyColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: PlayifyColors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (notifState.unreadCount > 0)
                    Semantics(
                      label: 'Mark all notifications as read',
                      button: true,
                      child: GestureDetector(
                        onTap: notifNotifier.markAllRead,
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: PlayifyColors.electricBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Tab bar
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = _tab == i;
                  return Semantics(
                    label: '${_tabs[i]} notifications tab',
                    selected: active,
                    button: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? PlayifyColors.electricBlue
                                  .withValues(alpha: 0.14)
                              : PlayifyColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: active
                                ? PlayifyColors.electricBlue
                                    .withValues(alpha: 0.45)
                                : PlayifyColors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            color: active
                                ? PlayifyColors.electricBlue
                                : PlayifyColors.muted,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: visible.isEmpty
                  ? _NotificationsEmpty()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(16, 10, 16, 40),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _NotificationTile(
                        item: visible[i],
                        onTap: () =>
                            notifNotifier.markRead(visible[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile ───────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  IconData get _icon {
    switch (item.type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.follow:
        return Icons.person_add_rounded;
      case NotificationType.mention:
        return Icons.alternate_email_rounded;
      case NotificationType.repost:
        return Icons.repeat_rounded;
      case NotificationType.sports:
        return Icons.sports_soccer_rounded;
      case NotificationType.message:
        return Icons.mail_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.title,
      hint: item.unread ? 'Unread' : 'Read',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.unread
                ? PlayifyColors.electricBlue
                    .withValues(alpha: 0.075)
                : PlayifyColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.unread
                  ? PlayifyColors.electricBlue
                      .withValues(alpha: 0.16)
                  : PlayifyColors.white.withValues(alpha: 0.055),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PlayifyColors.electricBlue
                      .withValues(alpha: 0.10),
                  border: Border.all(
                    color: PlayifyColors.electricBlue
                        .withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  _icon,
                  color: PlayifyColors.electricBlue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: item.unread
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayifyColors.muted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.time,
                      style: TextStyle(
                        color: PlayifyColors.muted
                            .withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.unread)
                Container(
                  width: 8,
                  height: 8,
                  margin:
                      const EdgeInsets.only(left: 8, top: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PlayifyColors.electricBlue,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _NotificationsEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 58,
              color:
                  PlayifyColors.electricBlue.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications here',
              style: TextStyle(
                color: PlayifyColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'New activity from your community will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PlayifyColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
