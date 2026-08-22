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
              height: 52,
              child: Image.asset(
                'assets/images/playify_header_logo.png',
                alignment: Alignment.centerLeft,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Text(
                    'SPORT SPHERE',
                    style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  );
                },
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

  static void _showMessages(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.transparent,
      barrierColor: SportSphereColors.black.withValues(alpha: 0.58),
      builder: (_) => const _MessageSheet(),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

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
              color: SportSphereColors.surface.withValues(alpha: 0.72),
              border: Border.all(
                color: SportSphereColors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: SportSphereColors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: SportSphereColors.white,
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
                  color: SportSphereColors.electricBlue,
                ),
                child: Center(
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: SportSphereColors.white,
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
