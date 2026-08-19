import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class CompetitionProfileView extends StatelessWidget {
  final String handle;
  const CompetitionProfileView({super.key, this.handle = 'competition'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('competition', handle));
  }
}
