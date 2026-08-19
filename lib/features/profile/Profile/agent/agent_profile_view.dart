import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class AgentProfileView extends StatelessWidget {
  final String handle;
  const AgentProfileView({super.key, this.handle = 'agent'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('agent', handle));
  }
}
