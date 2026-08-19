import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class SupportStaffProfileView extends StatelessWidget {
  final String handle;
  const SupportStaffProfileView({super.key, this.handle = 'support_staff'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('support_staff', handle));
  }
}
