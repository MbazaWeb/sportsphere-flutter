import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class CreatorProfileView extends StatelessWidget {
  final String handle;
  const CreatorProfileView({super.key, this.handle = 'creator'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('creator', handle));
  }
}
