part of '../app_shell.dart';

// Fix #9: _Header is now a ConsumerWidget so it can read notificationsProvider
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).unreadCount;
    final badgeText = unread > 0 ? (unread > 99 ? '99+' : '$unread') : null;
    final isAuthenticated = ref.watch(authControllerProvider).isAuthenticated;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          // Logo
          Expanded(
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/playify_icon.png',
                    height: 36,
                    width: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Playify',
                    style: TextStyle(
                      color: PlayifyColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Semantics(
            label: 'Search',
            button: true,
            child: _HeaderButton(
              icon: Icons.search_rounded,
              onTap: () => _showSearch(context),
            ),
          ),

          // Notifications — hidden for guests
          if (isAuthenticated) ...[
            const SizedBox(width: 8),
            Semantics(
              label: 'Notifications${unread > 0 ? ', $unread unread' : ''}',
              button: true,
              child: _HeaderButton(
                icon: Icons.notifications_none_rounded,
                badge: badgeText,
                onTap: () => _showNotifications(context),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'Messages',
              button: true,
              child: _HeaderButton(
                icon: Icons.mail_outline_rounded,
                badge: null,
                onTap: () => _showMessages(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _showSearch(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => const _FullScreenSearch(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static void _showNotifications(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => const _NotificationsScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static void _showMessages(
    BuildContext context, {
    String? peerId,
    String? peerName,
    String? peerHandle,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PlayifyColors.transparent,
      barrierColor: PlayifyColors.black.withValues(alpha: 0.58),
      builder: (_) => _MessageSheet(
        initialPeerId: peerId,
        initialPeerName: peerName,
        initialPeerHandle: peerHandle,
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PlayifyColors.surface.withValues(alpha: 0.72),
              border: Border.all(
                color: PlayifyColors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: PlayifyColors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: PlayifyColors.white,
              size: 21,
            ),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: PlayifyColors.electricBlue,
                ),
                child: Center(
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: PlayifyColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
