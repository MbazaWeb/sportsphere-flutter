import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class OrganizationProfileView extends StatelessWidget {
  const OrganizationProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Organization Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Organization'),
          ],
        ),
      ),
    );
  }
}
