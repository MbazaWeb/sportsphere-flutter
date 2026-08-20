import '../presentation/profile_loader.dart';
import '../templates/role_profile_model.dart';

/// Legacy name — now loads from Supabase via [ProfileLoader].
@Deprecated('Use ProfileLoader.loadRoleProfile')
Future<RoleProfileModel> roleProfileFor(String role, String handle) {
  return ProfileLoader.loadRoleProfile(role, handle);
}
