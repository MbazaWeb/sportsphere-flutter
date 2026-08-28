import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../../core/theme/colors.dart';

class VenueProfileView extends StatelessWidget {
  const VenueProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'Venue Name',
        handle: 'venuehandle',
        roleName: 'Venue',
        roleColor: const Color(0xFF76D42B),
        accentColor: const Color(0xFF76D42B),
        postCount: 340,
        fanCount: 24000,
        followingCount: 85,
        bio: 'Official Playify Venue page.',
        location: 'Tanzania',
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.corporate_fare_rounded,
            iconColor: PlayifyColors.electricBlue,
            label: 'Type',
            value: 'Venue',
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
