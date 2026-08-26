import 'package:flutter/material.dart';
import '../../../shared/person_profile_view.dart';
import '../../../../../core/theme/colors.dart';

class AnalystProfileView extends StatelessWidget {
  const AnalystProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonProfileView(
      profile: PersonProfileModel(
        name: 'Analyst Name',
        handle: 'analysthandle',
        roleName: 'Analyst',
        roleColor: const Color(0xFF168CFF),
        accentColor: const Color(0xFF168CFF),
        postCount: 124,
        followerCount: 8400,
        followingCount: 210,
        hasFanOption: false,
        bio: 'Professional Analyst on Playify.',
        location: 'Dar es Salaam, Tanzania',
        joinedDate: DateTime(2024, 6, 1),
        isVerified: false,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.work_outline_rounded,
            iconColor: PlayifyColors.electricBlue,
            label: 'Role',
            value: 'Analyst',
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
