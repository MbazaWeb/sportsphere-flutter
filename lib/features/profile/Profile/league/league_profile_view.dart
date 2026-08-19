import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class LeagueProfileView extends StatelessWidget {
  final String handle;
  const LeagueProfileView({super.key, this.handle = 'league'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('league', handle));
  }
}
