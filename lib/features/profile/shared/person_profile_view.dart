import 'package:flutter/material.dart';

class PersonProfileView extends StatelessWidget {
  final dynamic profile;
  final List<Widget>? additionalFields;
  
  const PersonProfileView({
    super.key,
    required this.profile,
    this.additionalFields,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: profile['avatarUrl'] != null 
                  ? NetworkImage(profile['avatarUrl']) 
                  : null,
              child: profile['avatarUrl'] == null 
                  ? const Icon(Icons.person, size: 40) 
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile['displayName'] ?? profile['name'] ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile['bio'] ?? '',
              style: const TextStyle(
                color: Color(0xFF8A9BB0),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (additionalFields != null) ...additionalFields!,
          ],
        ),
      ),
    );
  }
}

class PersonProfileModel {
  final String id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final Map<String, dynamic>? extraData;
  final String? handle;
  final String? roleName;
  final Color? roleColor;
  final Color? accentColor;
  final int? postCount;
  final int? followerCount;
  final int? followingCount;
  final bool? hasFanOption;
  final String? location;
  final DateTime? joinedDate;
  final bool? isVerified;
  final List<PersonAboutField>? aboutFields;

  PersonProfileModel({
    this.id = '',
    required this.name,
    this.bio,
    this.avatarUrl,
    this.extraData,
    this.handle,
    this.roleName,
    this.roleColor,
    this.accentColor,
    this.postCount,
    this.followerCount,
    this.followingCount,
    this.hasFanOption,
    this.location,
    this.joinedDate,
    this.isVerified,
    this.aboutFields,
  });
}

class PersonAboutField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const PersonAboutField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? const Color(0xFF168CFF), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A9BB0),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
