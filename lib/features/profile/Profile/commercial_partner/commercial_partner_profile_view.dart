import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class CommercialPartnerProfileView extends StatelessWidget {
  final String handle;
  const CommercialPartnerProfileView({super.key, this.handle = 'commercial_partner'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('commercial_partner', handle));
  }
}
