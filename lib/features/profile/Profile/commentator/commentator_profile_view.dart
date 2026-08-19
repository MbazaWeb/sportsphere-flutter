import 'package:flutter/material.dart';
import '../../presentation/widgets/profile_badge.dart';

class CommentatorProfileView extends StatelessWidget {
  const CommentatorProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Commentator Profile'),
            SizedBox(height: 8),
            ProfileBadge(label: 'Commentator'),
          ],
        ),
      ),
    );
  }
}
