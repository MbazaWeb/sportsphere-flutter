import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class AcademyProfileView extends StatelessWidget {
  const AcademyProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Academy Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Academy'),
          ],
        ),
      ),
    );
  }
}
