import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class CommunityProfileView extends StatelessWidget {
  const CommunityProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Community Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Community'),
          ],
        ),
      ),
    );
  }
}
