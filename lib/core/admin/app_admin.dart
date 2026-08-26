import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/auth_state.dart';

/// In-app admin: Playify Official account + explicit admin role.
class AppAdmin {
  AppAdmin._();

  /// Original official account UID
  static const _officialId = '2920d9ac-a8f8-4fd9-abbf-071bd3335fb9';

  /// playify.app@playify.com — primary admin / app access account
  static const _adminAppId = 'df104a87-bc0f-421a-a066-06b9d0e48d01';

  /// All UIDs that are unconditionally admin
  static const _adminUids = {_officialId, _adminAppId};

  static bool isAdminUser(UserProfile? user) {
    if (user == null) return false;
    // Email-based check is safe — Supabase auth verifies emails before they
    // become usable. Handle-based check was removed because handles can be
    // squat (anyone who registers with handle='playify_app' was being treated
    // as admin, see scan issue #9.10).
    if (user.email == 'playify.app@playify.com' ||
        user.email == 'playify@playify.com') {
      return true;
    }
    final role = user.role.toLowerCase();
    if (role == 'admin' ||
        role == 'official' ||
        role == 'organization' ||
        role == 'moderator') {
      return true;
    }
    return false;
  }

  static bool get isSessionAdmin {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return false;
    if (_adminUids.contains(u.id)) return true;
    final em = (u.email ?? '').toLowerCase();
    if (em == 'playify@playify.com' ||
        em == 'playify.app@playify.com') {
      return true;
    }
    // Handle-based check intentionally removed (#9.10): handles can be squat.
    // Role is the source of truth and is set explicitly by the database.
    final meta = u.userMetadata ?? {};
    final role = '${meta['role'] ?? ''}'.toLowerCase();
    if (role == 'admin' ||
        role == 'official' ||
        role == 'organization' ||
        role == 'moderator') {
      return true;
    }
    return false;
  }

  /// Resolves admin from profiles/User when metadata is incomplete.
  static Future<bool> resolveIsAdmin() async {
    if (isSessionAdmin) return true;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    if (_adminUids.contains(uid)) return true;
    // Handle-based check intentionally removed (#9.10): handles can be squat.
    // Role is the source of truth and is set explicitly by the database.
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('handle,role')
          .eq('id', uid)
          .maybeSingle();
      final role = '${row?['role'] ?? ''}'.toLowerCase();
      if (role == 'admin' ||
          role == 'official' ||
          role == 'organization' ||
          role == 'moderator') {
        return true;
      }
    } catch (_) {}
    try {
      final row = await Supabase.instance.client
          .from('User')
          .select('handle,role')
          .eq('id', uid)
          .maybeSingle();
      final role = '${row?['role'] ?? ''}'.toLowerCase();
      if (role == 'admin' ||
          role == 'official' ||
          role == 'organization' ||
          role == 'moderator') {
        return true;
      }
    } catch (_) {}
    return false;
  }
}
