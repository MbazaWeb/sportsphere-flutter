import 'package:flutter/material.dart';

import '../../shop/models/shop_models.dart';
import '../shared/profile_widgets.dart';

class AboutField {
  const AboutField(this.label, this.value);
  final String label;
  final String value;
}

class RoleMember {
  const RoleMember({
    required this.name,
    required this.handle,
    required this.subtitle,
    this.route,
  });
  final String name;
  final String handle;
  final String subtitle;
  final String? route;
}

class RoleStat {
  const RoleStat(this.value, this.label);
  final String value;
  final String label;
}

enum RoleShape { person, org, commerce }

class RoleProfileModel {
  const RoleProfileModel({
    required this.displayName,
    required this.handle,
    required this.roleLabel,
    required this.accent,
    required this.subtitle,
    required this.bio,
    required this.headerStats,
    required this.aboutFields,
    this.location = '',
    this.sport = 'Football',
    this.isVerified = true,
    this.isOwnProfile = false,
    this.coverIcon = Icons.person_rounded,
    this.members = const [],
    this.membersTitle = 'Members',
    this.statsRows = const [],
    this.posts = const [],
    this.shop,
    this.shape = RoleShape.person,
  });

  final String displayName;
  final String handle;
  final String roleLabel;
  final Color accent;
  final String subtitle;
  final String bio;
  final String location;
  final String sport;
  final bool isVerified;
  final bool isOwnProfile;
  final IconData coverIcon;
  final List<RoleStat> headerStats;
  final List<AboutField> aboutFields;
  final List<RoleMember> members;
  final String membersTitle;
  final List<AboutField> statsRows;
  final List<ProfilePost> posts;
  final ShopCatalog? shop;
  final RoleShape shape;

  String get atHandle => '@$handle';
}
