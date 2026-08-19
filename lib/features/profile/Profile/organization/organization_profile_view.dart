import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class OrganizationProfileView extends StatelessWidget {
  final String handle;
  const OrganizationProfileView({super.key, this.handle = 'organization'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('organization', handle));
  }
}
