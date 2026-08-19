import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class TeamProfileView extends StatelessWidget {
  const TeamProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Team Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Team'),
          ],
        ),
      ),
    );
  }
}
