import 'package:flutter/material.dart';
import '../../../shared/org_profile_view.dart';
import '../../../shared/shop_tab.dart';
import '../../../../core/theme/colors.dart';

// Business profile — same Sportlights/About tabs as Org,
// with a Shop tab powered by buildBusinessShop().
// TODO: when the full business profile model is defined, wire it in here.

class BusinessProfileView extends StatelessWidget {
  const BusinessProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return OrgProfileView(
      profile: OrgProfileModel(
        name: 'Business Name',
        handle: 'businesshandle',
        roleName: 'Business',
        roleColor: const Color(0xFFFFB900),
        accentColor: const Color(0xFFFFB900),
        postCount: 520,
        fanCount: 44000,
        followingCount: 32,
        bio: 'Official SportSphere business page. Products, services and sports partnerships.',
        location: 'Dar es Salaam, Tanzania',
        joinedDate: DateTime(2024, 3, 1),
        isVerified: true,
        aboutFields: const [
          PersonAboutField(
            icon: Icons.storefront_rounded,
            iconColor: SportSphereColors.electricBlue,
            label: 'Type',
            value: 'Business',
          ),
          PersonAboutField(
            icon: Icons.place_rounded,
            iconColor: SportSphereColors.sportOrange,
            label: 'Location',
            value: 'Tanzania',
          ),
          PersonAboutField(
            icon: Icons.language_rounded,
            iconColor: SportSphereColors.sportGreen,
            label: 'Website',
            value: 'www.example.com',
          ),
        ],
      ),
    );
  }
}
