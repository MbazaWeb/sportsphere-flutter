import 'package:flutter/material.dart';
import '../../../shared/person_profile_view.dart';
import '../../../../../core/theme/colors.dart';

class CoachProfileView extends StatelessWidget {
  const CoachProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonProfileView(
      profile: PersonProfileModel(
        name: 'Coach Name',
        handle: 'coachhandle',
        roleName: 'Coach',
        roleColor: const Color(0xFF9B6DFF),
        accentColor: const Color(0xFF9B6DFF),
        postCount: 124,
        followerCount: 8400,
        followingCount: 210,
        hasFanOption: true,
        bio: 'Professional Coach on SportSphere.',
        location: 'Dar es Salaam, Tanzania',
        joinedDate: DateTime(2024, 6, 1),
        isVerified: false,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.work_outline_rounded,
            iconColor: SportSphereColors.electricBlue,
            label: 'Role',
            value: 'Coach',
          ),
          PersonAboutField(
            icon: Icons.sports_soccer_rounded,
            iconColor: SportSphereColors.sportGreen,
            label: 'Sport',
            value: 'Football',
          ),
          PersonAboutField(
            icon: Icons.place_rounded,
            iconColor: SportSphereColors.sportOrange,
            label: 'Location',
            value: 'Tanzania',
          ),
        ],
      ),
    );
  }
}
