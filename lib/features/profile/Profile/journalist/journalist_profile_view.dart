import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class JournalistProfileView extends StatelessWidget {
  const JournalistProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Journalist Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Journalist'),
          ],
        ),
      ),
    );
  }
}
