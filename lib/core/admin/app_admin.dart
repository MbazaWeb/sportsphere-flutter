import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/auth_state.dart';
import '../branding.dart';

/// In-app admin: SportSphere Official (and explicit admin role).
class AppAdmin {
  AppAdmin._();

  static const officialId = '2920d9ac-a8f8-4fd9-abbf-071bd3335fb9';

  static bool isAdminUser(UserProfile? user) {
    if (user == null) return false;
    final handle = user.handle.replaceAll('@', '').toLowerCase();
    if (handle == kOfficialHandle ||
        handle == 'sportsphere' ||
        handle == 'sportsphere_official') {
      return true;
    }
    if (user.role.toLowerCase() == 'admin') return true;
    return false;
  }

  static bool get isSessionAdmin {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return false;
    if (u.id == officialId) return true;
    final meta = u.userMetadata ?? {};
    final handle = '${meta['handle'] ?? ''}'.toLowerCase().replaceAll('@', '');
    if (handle == kOfficialHandle || handle == 'sportsphere') return true;
    final role = '${meta['role'] ?? ''}'.toLowerCase();
    if (role == 'admin') return true;
    return false;
  }

  /// Resolves admin from profiles/User when metadata is incomplete.
  static Future<bool> resolveIsAdmin() async {
    if (isSessionAdmin) return true;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    if (uid == officialId) return true;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('handle,role')
          .eq('id', uid)
          .maybeSingle();
      final handle = '${row?['handle'] ?? ''}'.toLowerCase();
      final role = '${row?['role'] ?? ''}'.toLowerCase();
      if (handle == kOfficialHandle || handle == 'sportsphere') return true;
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
      if (handle == kOfficialHandle || handle == 'sportsphere') return true;
      if (role == 'admin') return true;
    } catch (_) {}
    return false;
  }
}
