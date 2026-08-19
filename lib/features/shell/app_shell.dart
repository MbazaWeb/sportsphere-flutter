import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/glass_container.dart';
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

class SportSphereShell extends StatefulWidget {
  const SportSphereShell({super.key});

  @override
  State<SportSphereShell> createState() => _SportSphereShellState();
}

class _SportSphereShellState extends State<SportSphereShell> {
  int _index = 0;

  final List<Widget> _screens = const [
    _HomeScreen(),
    ScoresPage(),
    _CreateScreen(),
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: _index,
        onChanged: (index) {
          setState(() {
            _index = index;
          });
        },
      ),
    );
  }
}

