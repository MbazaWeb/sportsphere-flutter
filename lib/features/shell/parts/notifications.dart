part of '../app_shell.dart';

class _NotificationsScreen extends StatefulWidget {
  const _NotificationsScreen();

  @override
  State<_NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<_NotificationsScreen> {
  int _tab = 0;

  final List<String> _tabs = const [
    'All',
    'Social',
    'Sports',
    'Messages',
  ];

  final List<_NotificationData> _notifications = [
    _NotificationData(
      type: _NotificationType.like,
      title: 'Clatous Chama liked your post',
      subtitle: 'What. A. Game!',
      time: '2m',
      unread: true,
    ),
    _NotificationData(
      type: _NotificationType.comment,
      title: 'Ali Kingu commented on your post',
      subtitle: 'Great football analysis.',
      time: '8m',
      unread: true,
    ),
    _NotificationData(
      type: _NotificationType.follow,
      title: 'SportSphere Fan started following you',
      subtitle: 'Fan',
      time: '18m',
      unread: true,
    ),
    _NotificationData(
      type: _NotificationType.mention,
      title: 'Young Africans mentioned you',
      subtitle: 'in a community discussion',
      time: '32m',
      unread: false,
    ),
    _NotificationData(
      type: _NotificationType.repost,
      title: 'Man City reposted your post',
      subtitle: 'Three points away from home.',
      time: '1h',
      unread: false,
    ),
    _NotificationData(
      type: _NotificationType.sports,
      title: 'Match started',
      subtitle: 'Simba SC vs Young Africans',
      time: '2h',
      unread: false,
    ),
    _NotificationData(
      type: _NotificationType.message,
      title: 'Clatous Chama sent you a message',
      subtitle: 'Are you watching the match?',
      time: '3h',
      unread: true,
    ),
    _NotificationData(
      type: _NotificationType.message,
      title: 'SportSphere Fan sent you a message',
      subtitle: 'I agree with your prediction.',
      time: '4h',
      unread: false,
    ),
  ];

  List<_NotificationData> get _visibleNotifications {
    if (_tab == 0) {
      return _notifications;
    }

    final type = _tab == 1
        ? {
            _NotificationType.like,
            _NotificationType.comment,
            _NotificationType.follow,
            _NotificationType.mention,
            _NotificationType.repost,
          }
        : _tab == 2
            ? {
                _NotificationType.sports,
              }
            : {
                _NotificationType.message,
              };

    return _notifications.where((item) => type.contains(item.type)).toList();
  }

  int get _unreadCount =>
      _notifications.where((item) => item.unread).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: SportSphereColors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: SportSphereColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          for (final notification in _notifications) {
                            notification.unread = false;
                          }
                        });
                      },
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          color: SportSphereColors.electricBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final active = _tab == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _tab = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? SportSphereColors.electricBlue
                                .withValues(alpha: 0.14)
                            : SportSphereColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: active
                              ? SportSphereColors.electricBlue
                                  .withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          color: active
                              ? SportSphereColors.electricBlue
                              : SportSphereColors.muted,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _visibleNotifications.isEmpty
                  ? const _NotificationsEmpty()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        10,
                        16,
                        40,
                      ),
                      itemCount: _visibleNotifications.length,
                      itemBuilder: (_, index) {
                        final item = _visibleNotifications[index];

                        return _NotificationTile(
                          notification: item,
                          onTap: () {
                            if (item.unread) {
                              setState(() {
                                item.unread = false;
                              });
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotificationType {
  like,
  comment,
  follow,
  mention,
  repost,
  sports,
  message,
}

class _NotificationData {
  final _NotificationType type;
  final String title;
  final String subtitle;
  final String time;
  bool unread;

  _NotificationData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
  });
}

class _NotificationTile extends StatelessWidget {
  final _NotificationData notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData get _icon {
    switch (notification.type) {
      case _NotificationType.like:
        return Icons.favorite_rounded;
      case _NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case _NotificationType.follow:
        return Icons.person_add_rounded;
      case _NotificationType.mention:
        return Icons.alternate_email_rounded;
      case _NotificationType.repost:
        return Icons.repeat_rounded;
      case _NotificationType.sports:
        return Icons.sports_soccer_rounded;
      case _NotificationType.message:
        return Icons.mail_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.unread
              ? SportSphereColors.electricBlue.withValues(alpha: 0.075)
              : SportSphereColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.unread
                ? SportSphereColors.electricBlue.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.055),
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
                color: SportSphereColors.electricBlue
                    .withValues(alpha: 0.10),
                border: Border.all(
                  color: SportSphereColors.electricBlue
                      .withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                _icon,
                color: SportSphereColors.electricBlue,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: notification.unread
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SportSphereColors.muted,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    notification.time,
                    style: TextStyle(
                      color: SportSphereColors.muted
                          .withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(
                  left: 8,
                  top: 6,
                ),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SportSphereColors.electricBlue,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

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
              color: SportSphereColors.electricBlue
                  .withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications here',
              style: TextStyle(
                color: SportSphereColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'New activity from your community will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SportSphereColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
