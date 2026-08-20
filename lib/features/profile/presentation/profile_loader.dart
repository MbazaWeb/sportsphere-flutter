import 'package:flutter/material.dart';

import '../Profile/fan/fan_profile_view.dart';
import '../Profile/player/player_profile_view.dart';
import '../Profile/team/team_profile_view.dart';
import '../../../../features/profile/data/team_profile_lookup.dart';
import '../../../../features/profile/data/role_mocks.dart';
import '../../../../features/profile/templates/role_profile_model.dart';

/// Centralized profile loading - separates data fetching from routing
class ProfileLoader {
  const ProfileLoader._();

  static FanProfileModel loadFanProfile(String handle) {
    // TODO: Replace with actual API call
    // For now, return mock or default
    return handle == mockOwnFanProfile.handle
        ? mockOwnFanProfile
        : FanProfileModel(
            firstName: handle,
            lastName: '',
            handle: handle,
            fanOf: 'SportSphere',
            fanOfAccent: const Color(0xFF009DFF),
            bio: '',
            sport: 'Football',
            location: '',
            joinedDate: DateTime.now(),
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
          );
  }

  static PlayerProfileModel loadPlayerProfile(String handle) {
    // TODO: Replace with actual API call
    return handle == mockClatousChama.handle
        ? mockClatousChama
        : PlayerProfileModel(
            firstName: handle,
            lastName: '',
            handle: handle,
            fullName: handle,
            position: 'Forward',
            nationality: 'Unknown',
            dob: DateTime(1995),
            heightCm: 175,
            preferredFoot: 'Right',
            currentClub: 'Unknown',
            currentLeague: 'Unknown',
            squadNumber: 0,
            contractStatus: 'Active',
            accentColor: const Color(0xFF009DFF),
            postCount: 0,
            fanCount: 0,
            followerCount: 0,
            followingCount: 0,
            career: const [],
            seasonStats: const [],
            allTimeGoals: 0,
            allTimeAssists: 0,
            allTimeAppearances: 0,
            allTimeMinutes: 0,
            allTimeYellowCards: 0,
            allTimeRedCards: 0,
          );
  }

  static TeamProfileModel loadTeamProfile(String handle) {
    // TODO: Replace with actual API call
    return handle == mockSimbaSC.handle ? mockSimbaSC : mockSimbaSC;
  }

  static RoleProfileModel loadRoleProfile(String role, String handle) {
    // TODO: Replace with actual API call
    return roleProfileFor(role, handle);
  }
}