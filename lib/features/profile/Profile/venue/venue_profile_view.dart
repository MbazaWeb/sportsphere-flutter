import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class VenueProfileView extends StatelessWidget {
  final String handle;
  const VenueProfileView({super.key, this.handle = 'venue'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('venue', handle));
  }
}
