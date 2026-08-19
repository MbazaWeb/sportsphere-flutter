import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../home/widgets/sportlights_tab.dart';
import '../scores/presentation/pages/scores_page.dart';

part 'parts/home_screen.dart';
part 'parts/search_fullscreen.dart';
part 'parts/header.dart';
part 'parts/notifications.dart';
part 'parts/search_sheets.dart';
part 'parts/feed_widgets.dart';
part 'parts/create_screen.dart';
part 'parts/profile_screen.dart';
part 'parts/bottom_nav.dart';

// ── Shell — auth-aware ─────────────────────────────────────────────────────────
//
// Guest  : tabs = [Home, Scores]       nav = Home | Scores | Log In
// Auth   : tabs = [Home, Scores, +, Profile]  nav = Home | Scores | FAB | Profile

class SportSphereShell extends ConsumerStatefulWidget {
  const SportSphereShell({super.key});

  @override
  ConsumerState<SportSphereShell> createState() => _SportSphereShellState();
}

class _SportSphereShellState extends ConsumerState<SportSphereShell> {
  int _index = 0;

  static const _guestScreens = <Widget>[
    _HomeScreen(),
    ScoresPage(),
  ];

  static const _authScreens = <Widget>[
    _HomeScreen(),
    ScoresPage(),
    _CreateScreen(),
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isGuest = auth.isGuest || auth.status == AuthStatus.unknown;

    // Clamp index to valid range when switching between guest/auth mode
    final screens = isGuest ? _guestScreens : _authScreens;
    final safeIndex = _index.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: SportSphereColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: safeIndex,
        isGuest: isGuest,
        onChanged: (index) {
          setState(() => _index = index);
        },
      ),
    );
  }
}
