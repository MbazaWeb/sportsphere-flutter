import 'package:flutter/material.dart';

import '../../presentation/profile_loader.dart';
import '../../templates/role_profile_shell.dart';

class ScoutProfileView extends StatelessWidget {
  final String handle;
  const ScoutProfileView({super.key, this.handle = 'scout'});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ProfileLoader.loadRoleProfile('scout', handle),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Profile not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        return RoleProfileShell(profile: snap.data!);
      },
    );
  }
}
