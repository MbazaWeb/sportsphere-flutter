import 'dart:ui';
import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/admin/app_admin.dart';
import '../../core/data/social_repository.dart';
import '../../core/data/commerce_repository.dart';
import '../../core/data/messaging_repository.dart';
import '../../core/widgets/glass_container.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/notifications/notifications_provider.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/profile/presentation/profile_loader.dart';
import '../home/widgets/sportlights_tab.dart';
import '../home/news/news_tab.dart';
import '../scores/presentation/pages/scores_page.dart';
import '../shop/models/shop_models.dart';
import '../shop/presentation/shop_tab.dart';
import '../../core/utils/friendly_error.dart';
import 'nav_provider.dart';

part 'parts/home_screen.dart';
part 'parts/search_fullscreen.dart';
part 'parts/header.dart';
part 'parts/notifications.dart';
part 'parts/search_sheets.dart';
part 'parts/feed_widgets.dart';
part 'parts/create_screen.dart';
part 'parts/profile_screen.dart';
part 'parts/bottom_nav.dart';

class SportSphereShell extends ConsumerStatefulWidget {
  const SportSphereShell({super.key});

  @override
  ConsumerState<SportSphereShell> createState() => _SportSphereShellState();
}

class _SportSphereShellState extends ConsumerState<SportSphereShell> {
  // Local index tracks the user's manual tab taps. We then reconcile with
  // shellTabProvider (set externally by Spotlight "View Match" buttons etc.)
  // in build() — if shellTabProvider differs from _index, we let it win and
  // sync _index to it.
  int _index = 0;
  int _lastSyncedTab = 0;

  void goHome() {
    if (!mounted) return;
    setState(() => _index = 0);
  }

  // FIX #10: Not static const — _CreateScreen owns AnimationControllers
  // and must not be const-constructed in a static list.
  final _guestScreens = const <Widget>[
    _HomeScreen(),
    ScoresPage(),
  ];

  final _authScreens = const <Widget>[
    _HomeScreen(),
    ScoresPage(),
    _CreateScreen(),
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isGuest = auth.isGuest || auth.status == AuthStatus.unknown;

    // Reconcile with the externally-set shellTabProvider. If a widget set
    // shellTabProvider to e.g. 1 (Scores), switch to that tab once.
    final requestedTab = ref.watch(shellTabProvider);
    if (requestedTab != _lastSyncedTab) {
      _index = requestedTab;
      _lastSyncedTab = requestedTab;
    }

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
          // Keep shellTabProvider in sync so external code reading it
          // sees the current tab.
          ref.read(shellTabProvider.notifier).set(index);
          _lastSyncedTab = index;
        },
      ),
    );
  }
}
