import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class LeagueProfileView extends StatelessWidget {
  const LeagueProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('League Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'League'),
          ],
        ),
      ),
    );
  }
}
