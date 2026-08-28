import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../../core/theme/colors.dart';

class MediaBroadcastProfileView extends StatelessWidget {
  const MediaBroadcastProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'Media Name',
        handle: 'media_broadcasthandle',
        roleName: 'Media',
        roleColor: const Color(0xFFFF3B61),
        accentColor: const Color(0xFFFF3B61),
        postCount: 340,
        fanCount: 24000,
        followingCount: 85,
        bio: 'Official Playify Media page.',
        location: 'Tanzania',
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.corporate_fare_rounded,
            iconColor: PlayifyColors.electricBlue,
            label: 'Type',
            value: 'Media',
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
