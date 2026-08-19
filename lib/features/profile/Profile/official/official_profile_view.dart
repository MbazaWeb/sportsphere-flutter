import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class OfficialProfileView extends StatelessWidget {
  final String handle;
  const OfficialProfileView({super.key, this.handle = 'official'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('official', handle));
  }
}
