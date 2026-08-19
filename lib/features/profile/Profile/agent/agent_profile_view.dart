import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class AgentProfileView extends StatelessWidget {
  const AgentProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Agent Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Agent'),
          ],
        ),
      ),
    );
  }
}
