import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class MediaBroadcastProfileView extends StatelessWidget {
  final String handle;
  const MediaBroadcastProfileView({super.key, this.handle = 'media_broadcast'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('media_broadcast', handle));
  }
}
