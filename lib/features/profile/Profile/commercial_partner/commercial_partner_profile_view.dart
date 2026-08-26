import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../../../core/theme/colors.dart';

class CommercialPartnerProfileView extends StatelessWidget {
  const CommercialPartnerProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'Commercial Partner Name',
        handle: 'commercial_partnerhandle',
        roleName: 'Commercial Partner',
        roleColor: const Color(0xFF009DFF),
        accentColor: const Color(0xFF009DFF),
        postCount: 340,
        fanCount: 24000,
        followingCount: 85,
        bio: 'Official Playify Commercial Partner page.',
        location: 'Tanzania',
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.corporate_fare_rounded,
            iconColor: PlayifyColors.electricBlue,
            label: 'Type',
            value: 'Commercial Partner',
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
            label: 'Country',
            value: 'Tanzania',
          ),
        ],
      ),
    );
  }
}
