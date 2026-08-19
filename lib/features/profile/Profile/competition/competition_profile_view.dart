import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class CompetitionProfileView extends StatelessWidget {
  const CompetitionProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Competition Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Competition'),
          ],
        ),
      ),
    );
  }
}
