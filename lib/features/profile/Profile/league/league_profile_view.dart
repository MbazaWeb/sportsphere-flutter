import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../../core/theme/colors.dart';

class LeagueProfileView extends StatelessWidget {
  const LeagueProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'League Name',
        handle: 'leaguehandle',
        roleName: 'League',
        roleColor: const Color(0xFFFFD700),
        accentColor: const Color(0xFFFFD700),
        postCount: 340,
        fanCount: 24000,
        followingCount: 85,
        bio: 'Official Playify League page.',
        location: 'Tanzania',
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.corporate_fare_rounded,
            iconColor: PlayifyColors.electricBlue,
            label: 'Type',
            value: 'League',
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
