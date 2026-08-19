import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class SponsorProfileView extends StatelessWidget {
  final String handle;
  const SponsorProfileView({super.key, this.handle = 'sponsor'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('sponsor', handle));
  }
}
