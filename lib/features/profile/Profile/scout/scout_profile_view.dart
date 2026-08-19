import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class ScoutProfileView extends StatelessWidget {
  const ScoutProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Scout Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Scout'),
          ],
        ),
      ),
    );
  }
}
