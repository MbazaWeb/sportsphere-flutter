import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class AnalystProfileView extends StatelessWidget {
  const AnalystProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Analyst Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Analyst'),
          ],
        ),
      ),
    );
  }
}
