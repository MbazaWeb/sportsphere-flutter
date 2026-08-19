import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class BusinessProfileView extends StatelessWidget {
  const BusinessProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Business Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Business'),
          ],
        ),
      ),
    );
  }
}
