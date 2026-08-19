import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class FanProfileView extends StatelessWidget {
  const FanProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Fan Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Fan'),
          ],
        ),
      ),
    );
  }
}
