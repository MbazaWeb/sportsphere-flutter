import '../../features/auth/domain/auth_state.dart';
import '../data/vps_supabase_compat.dart';

/// In-app admin: Playify Official account + explicit admin role.
/// Fully migrated to VPS — no direct Supabase calls.
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

  /// Synchronous check — uses cached user from VpsSupabaseCompat.
  static bool get isSessionAdmin {
    final u = VpsSupabaseCompat.client.auth.currentUser;
    if (u == null) return false;
    if (_adminUids.contains(u.id)) return true;
    // Role-based check requires async fetch — use resolveIsAdmin() for
    // the authoritative answer. This sync getter returns false if the
    // cached user doesn't have a role (which is always, since the shim
    // only stores id). Callers should use resolveIsAdmin() after login.
    return false;
  }

  /// Resolves admin from VPS — queries profile via VpsRepository.
  static Future<bool> resolveIsAdmin() async {
    final uid = VpsSupabaseCompat.client.auth.currentUser?.id;
    if (uid == null) return false;
    if (_adminUids.contains(uid)) return true;

    try {
      final profile = await VpsSupabaseCompat.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      final role = '${profile?['role'] ?? ''}'.toLowerCase();
      if (role == 'admin' ||
          role == 'official' ||
          role == 'organization' ||
          role == 'moderator') {
        return true;
      }
    } catch (_) {}

    try {
      final user = await VpsSupabaseCompat.client
          .from('User')
          .select()
          .eq('id', uid)
          .maybeSingle();
      final role = '${user?['role'] ?? ''}'.toLowerCase();
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
