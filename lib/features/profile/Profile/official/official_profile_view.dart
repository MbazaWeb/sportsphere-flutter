import 'package:flutter/material.dart';
import '../../../shared/person_profile_view.dart';
import '../../../../../core/theme/colors.dart';

/// Special treatment for the official SportSphere admin account.
/// - Name fixed to "SportSphere"
/// - Badge "Official" (not Fan/Admin)
/// - No "Fan of" section
/// - No country shown
/// - Verified gold tick always on
/// - "My Sports" shows all sports unlocked
class OfficialProfileView extends StatelessWidget {
  const OfficialProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonProfileView(
      profile: PersonProfileModel(
        name: 'SportSphere',
        handle: 'sportsphere',
        roleName: 'Official',
        roleColor: const Color(0xFFFFD700),
        accentColor: const Color(0xFFFFD700),
        postCount: 0,
        followerCount: 0,
        followingCount: 0,
        hasFanOption: false,
        bio: 'Official SportSphere account. Platform news, live scores and verified content.',
        location: '', // no country shown for admin
        joinedDate: DateTime(2024, 1, 1),
        isVerified: true, // always gold tick
        aboutFields: const [
          PersonAboutField(
            icon: Icons.verified_rounded,
            iconColor: Color(0xFFFFD700),
            label: 'Badge',
            value: 'Official',
          ),
          PersonAboutField(
            icon: Icons.sports_rounded,
            iconColor: SportSphereColors.sportGreen,
            label: 'My Sports',
            value: 'All Sports',
          ),
          PersonAboutField(
            icon: Icons.public_rounded,
            iconColor: SportSphereColors.electricBlue,
            label: 'Platform',
            value: 'SportSphere Global',
          ),
        ],
      ),
    );
  }
}
