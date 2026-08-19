import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class CoachProfileView extends StatelessWidget {
  const CoachProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Coach Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Coach'),
          ],
        ),
      ),
    );
  }
}
