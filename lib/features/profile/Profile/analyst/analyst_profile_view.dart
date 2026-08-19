import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class AnalystProfileView extends StatelessWidget {
  final String handle;
  const AnalystProfileView({super.key, this.handle = 'analyst'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('analyst', handle));
  }
}
