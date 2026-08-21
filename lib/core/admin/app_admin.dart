import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/auth_state.dart';
import '../branding.dart';

/// In-app admin: SportSphere Official account + explicit admin role.
class AppAdmin {
  AppAdmin._();

  /// Original official account UID
  static const _officialId = '2920d9ac-a8f8-4fd9-abbf-071bd3335fb9';

  /// sportsphere.app@sportsphere.com — primary admin / app access account
  static const _adminAppId = 'df104a87-bc0f-421a-a066-06b9d0e48d01';

  /// All UIDs that are unconditionally admin
  static const _adminUids = {_officialId, _adminAppId};

  static bool isAdminUser(UserProfile? user) {
    if (user == null) return false;
    // Check by email first (most reliable without an id field)
    if (user.email == 'sportsphere.app@sportsphere.com') return true;
    final handle = user.handle.replaceAll('@', '').toLowerCase();
    if (handle == kOfficialHandle ||
        handle == 'sportsphere' ||
        handle == 'sportsphere_official' ||
        handle == 'sportsphere_app') return true;
    if (user.role.toLowerCase() == 'admin') return true;
    return false;
  }

  static bool get isSessionAdmin {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return false;
    if (_adminUids.contains(u.id)) return true;
    final meta = u.userMetadata ?? {};
    final handle = '${meta['handle'] ?? ''}'.toLowerCase().replaceAll('@', '');
    if (handle == kOfficialHandle ||
        handle == 'sportsphere' ||
        handle == 'sportsphere_app') return true;
    final role = '${meta['role'] ?? ''}'.toLowerCase();
    if (role == 'admin') return true;
    return false;
  }

  /// Resolves admin from profiles/User when metadata is incomplete.
  static Future<bool> resolveIsAdmin() async {
    if (isSessionAdmin) return true;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    if (_adminUids.contains(uid)) return true;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('handle,role')
          .eq('id', uid)
          .maybeSingle();
      final handle = '${row?['handle'] ?? ''}'.toLowerCase();
      final role = '${row?['role'] ?? ''}'.toLowerCase();
      if (handle == kOfficialHandle ||
          handle == 'sportsphere' ||
          handle == 'sportsphere_app') return true;
      if (role == 'admin') return true;
    } catch (_) {}
    try {
      final row = await Supabase.instance.client
          .from('User')
          .select('handle,role')
          .eq('id', uid)
          .maybeSingle();
      final handle = '${row?['handle'] ?? ''}'.toLowerCase();
      final role = '${row?['role'] ?? ''}'.toLowerCase();
      if (handle == kOfficialHandle ||
          handle == 'sportsphere' ||
          handle == 'sportsphere_app') return true;
      if (role == 'admin') return true;
    } catch (_) {}
    return false;
  }
}
