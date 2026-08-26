part of '../app_shell.dart';

// ── Auth-aware bottom navigation ───────────────────────────────────────────────
//
// Guest  → Home | Scores | [ Log In button ]
// Auth   → Home | Scores | + (FAB) | Profile

class _BottomNavigation extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool isGuest;

  const _BottomNavigation({
    required this.currentIndex,
    required this.onChanged,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xEE061321),
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: PlayifyColors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: PlayifyColors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: isGuest
                  ? _GuestNav(
                      currentIndex: currentIndex,
                      onChanged: onChanged,
                    )
                  : _AuthNav(
                      currentIndex: currentIndex,
                      onChanged: onChanged,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Guest nav: Home | Scores | Log In ──────────────────────────────────────────

class _GuestNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _GuestNav({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          active: currentIndex == 0,
          onTap: () => onChanged(0),
        ),
        _NavItem(
          icon: Icons.sports_score_rounded,
          label: 'Scores',
          active: currentIndex == 1,
          onTap: () => onChanged(1),
        ),
        // Log In CTA
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () => context.push('/login'),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      PlayifyColors.electricBlue,
                      Color(0xFF0066DD),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PlayifyColors.electricBlue
                          .withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded, color: PlayifyColors.white, size: 18),
                    SizedBox(width: 7),
                    Text(
                      'Log In',
                      style: TextStyle(
                        color: PlayifyColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Authenticated nav: Home | Scores | + | Profile ────────────────────────────

class _AuthNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _AuthNav({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          active: currentIndex == 0,
          onTap: () => onChanged(0),
        ),
        _NavItem(
          icon: Icons.sports_score_rounded,
          label: 'Scores',
          active: currentIndex == 1,
          onTap: () => onChanged(1),
        ),
        // FAB
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () => onChanged(2),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      PlayifyColors.electricBlue,
                      Color(0xFF0077D4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PlayifyColors.electricBlue
                          .withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: PlayifyColors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
        _NavItem(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          active: currentIndex == 3,
          onTap: () => onChanged(3),
        ),
      ],
    );
  }
}

// ── Shared nav item ────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active
                  ? PlayifyColors.electricBlue
                  : PlayifyColors.muted,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? PlayifyColors.electricBlue
                    : PlayifyColors.muted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
