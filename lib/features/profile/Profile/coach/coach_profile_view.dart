import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class CoachProfileView extends StatelessWidget {
  final String handle;
  const CoachProfileView({super.key, this.handle = 'coach'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('coach', handle));
  }
}
