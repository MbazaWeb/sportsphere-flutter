/// Playify brand constants (user-facing name of the app).
const kAppName = 'Playify';
const kAppTagline = 'Your world of sport';

const kOfficialHandle = 'playify';
/// Legacy handles still treated as official/admin.
const kOfficialLegacyHandles = {
  'playify',
  'playify_official',
  'playify_app',
  'sportsphere',
  'sportsphere_official',
  'sportsphere_app',
};

const kOfficialAvatarUrl =
    'https://fffqjbrethogesgghjsn.supabase.co/storage/v1/object/public/avatars/official/playify.png';
const kOfficialAvatarAsset = 'assets/images/playify_icon.png';
const kAppBallAsset = 'assets/images/playify_ball.png';
const kAppLogoAsset = 'assets/images/playify_logo.png';
const kAppHeaderLogoAsset = 'assets/images/playify_header_logo.png';

bool isOfficialHandle(String? handle) {
  final h = (handle ?? '').replaceAll('@', '').trim().toLowerCase();
  return kOfficialLegacyHandles.contains(h);
}
