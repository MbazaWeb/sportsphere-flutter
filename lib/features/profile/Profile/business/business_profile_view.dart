import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class BusinessProfileView extends StatelessWidget {
  final String handle;
  const BusinessProfileView({super.key, this.handle = 'business'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('business', handle));
  }
}
