import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class PlayerProfileView extends StatelessWidget {
  const PlayerProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Player Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Player'),
          ],
        ),
      ),
    );
  }
}
