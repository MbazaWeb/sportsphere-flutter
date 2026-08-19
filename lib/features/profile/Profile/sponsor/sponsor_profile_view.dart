import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class SponsorProfileView extends StatelessWidget {
  const SponsorProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sponsor Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Sponsor'),
          ],
        ),
      ),
    );
  }
}
