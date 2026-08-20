import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/data/social_repository.dart';
import '../../core/widgets/glass_container.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/notifications/notifications_provider.dart';
import '../../features/profile/Profile/fan/fan_profile_view.dart';
import '../../features/profile/presentation/edit_profile_sheet.dart';
import '../home/widgets/sportlights_tab.dart';
import '../scores/presentation/pages/scores_page.dart';
import '../shop/models/shop_models.dart';
import '../shop/presentation/shop_tab.dart';
import 'media/media_tools.dart';

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
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}
