import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class ModeratorProfileView extends StatelessWidget {
  final String handle;
  const ModeratorProfileView({super.key, this.handle = 'moderator'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('moderator', handle));
  }
}
