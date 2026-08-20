import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../../../core/theme/colors.dart';

class CompetitionProfileView extends StatelessWidget {
  const CompetitionProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'Competition Name',
        handle: 'competitionhandle',
        roleName: 'Competition',
        roleColor: const Color(0xFFFFD700),
        accentColor: const Color(0xFFFFD700),
        postCount: 340,
        fanCount: 24000,
        followingCount: 85,
        bio: 'Official SportSphere Competition page.',
        location: 'Tanzania',
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.corporate_fare_rounded,
            iconColor: SportSphereColors.electricBlue,
            label: 'Type',
            value: 'Competition',
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
            label: 'Country',
            value: 'Tanzania',
          ),
        ],
      ),
    );
  }
}
