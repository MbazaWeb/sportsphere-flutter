/// Playify brand constants
const kAppName = 'Playify';
const kAppTagline = 'Your world of sport';

const kOfficialHandle = 'playify';
const kOfficialLegacyHandles = {
  'playify',
  'playify_official',
  'playify_app',
  'playifyofficial', // no-underscore variant (squatter-safe)
  'sportsphere',
  'sportsphere_official',
  'sportsphere_app',
};

const kOfficialAvatarUrl = ''; // prefer local asset
const kOfficialAvatarAsset = 'assets/images/playify_icon.png';
const kAppBallAsset = 'assets/images/playify_ball.png';
const kAppLogoAsset = 'assets/images/playify_logo.png';
const kAppHeaderLogoAsset = 'assets/images/playify_header_logo.png';

bool isOfficialHandle(String? handle) {
  final h = (handle ?? '').replaceAll('@', '').trim().toLowerCase();
  return kOfficialLegacyHandles.contains(h);
}
