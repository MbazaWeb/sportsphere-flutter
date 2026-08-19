import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class CommunityProfileView extends StatelessWidget {
  final String handle;
  const CommunityProfileView({super.key, this.handle = 'community'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('community', handle));
  }
}
