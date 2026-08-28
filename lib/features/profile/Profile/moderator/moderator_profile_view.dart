import 'package:flutter/material.dart';
import '../../../shared/person_profile_view.dart';
import '../../../../core/theme/colors.dart';

class ModeratorProfileView extends StatelessWidget {
  const ModeratorProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonProfileView(
      profile: PersonProfileModel(
        name: 'Moderator Name',
        handle: 'moderatorhandle',
        roleName: 'Moderator',
        roleColor: const Color(0xFF76D42B),
        accentColor: const Color(0xFF76D42B),
        postCount: 124,
        followerCount: 8400,
        followingCount: 210,
        hasFanOption: false,
        bio: 'Professional Moderator on Playify.',
        location: 'Dar es Salaam, Tanzania',
        joinedDate: DateTime(2024, 6, 1),
        isVerified: false,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.work_outline_rounded,
            iconColor: PlayifyColors.electricBlue,
            label: 'Role',
            value: 'Moderator',
          ),
          PersonAboutField(
            icon: Icons.sports_soccer_rounded,
            iconColor: PlayifyColors.sportGreen,
            label: 'Sport',
            value: 'Football',
          ),
          PersonAboutField(
            icon: Icons.place_rounded,
            iconColor: PlayifyColors.sportOrange,
            label: 'Location',
            value: 'Tanzania',
          ),
        ],
      ),
    );
  }
}
