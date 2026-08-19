import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class JournalistProfileView extends StatelessWidget {
  final String handle;
  const JournalistProfileView({super.key, this.handle = 'journalist'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('journalist', handle));
  }
}
