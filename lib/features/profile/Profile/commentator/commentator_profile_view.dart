import 'package:flutter/material.dart';

import '../../data/role_mocks.dart';
import '../../templates/role_profile_shell.dart';

class CommentatorProfileView extends StatelessWidget {
  final String handle;
  const CommentatorProfileView({super.key, this.handle = 'commentator'});

  @override
  Widget build(BuildContext context) {
    return RoleProfileShell(profile: roleProfileFor('commentator', handle));
  }
}
