import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class ScoutProfileView extends StatelessWidget {
  final String handle;
  const ScoutProfileView({super.key, this.handle = 'scout'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('scout', handle));
  }
}
