import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class AcademyProfileView extends StatelessWidget {
  final String handle;
  const AcademyProfileView({super.key, this.handle = 'academy'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('academy', handle));
  }
}
