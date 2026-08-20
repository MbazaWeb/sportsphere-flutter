import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../../../core/theme/colors.dart';

class OrganizationProfileView extends StatelessWidget {
  const OrganizationProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'Organization Name',
        handle: 'organizationhandle',
        roleName: 'Organization',
        roleColor: const Color(0xFF009DFF),
        accentColor: const Color(0xFF009DFF),
        postCount: 340,
        fanCount: 24000,
        followingCount: 85,
        bio: 'Official SportSphere Organization page.',
        location: 'Tanzania',
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.corporate_fare_rounded,
            iconColor: SportSphereColors.electricBlue,
            label: 'Type',
            value: 'Organization',
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
