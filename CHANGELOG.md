# Changelog

## [1.0.1] — 2026-08-20

### Security
- **Critical fix**: Removed `.env` and `.env.example` from `pubspec.yaml` assets.
  Secrets were previously bundled inside the APK in plaintext. Now uses
  `--dart-define` compile-time constants instead (`flutter_dotenv` removed).
- Logger is silenced in release builds (`Logger.level = Level.off`) to prevent
  info leakage to the system console.

### Added
- GitHub Actions CI workflow (`.github/workflows/ci.yml`):
  lint → test → Android debug APK build on every push to `main`/`develop`
- `SECURITY.md` with vulnerability reporting policy
- `CHANGELOG.md` (this file)
- `.vscode/launch.json.example` for local dev setup

### Changed
- `AppEnv` now uses `String.fromEnvironment()` compile-time constants;
  `flutter_dotenv` dependency removed
- `analysis_options.yaml`: strict lint rules enabled (`avoid_print`,
  `prefer_single_quotes`, `always_declare_return_types`, `avoid_dynamic_calls`,
  `prefer_const_constructors`, `use_super_parameters`)
- `main.dart`: shows a clear configuration-missing screen instead of crashing
  when `--dart-define` vars are absent
- `pubspec.yaml`: version bumped to `1.0.1+2`, `equatable` promoted to direct
  dependency, `flutter_dotenv` removed
- Tests: `scores_repository_test.dart` fixed — removed assertions that depended
  on the current wall-clock date (getLive/getResults were non-deterministic)
- `README.md`: updated with dart-define run instructions, removed dotenv references

## [1.0.0] — 2026-07-01

### Added
- Initial project: animated splash, tab shell, 22-role profile system
- Ligi Kuu Bara 2026/27 fixture calendar (240 matches, 30 rounds)
- Supabase auth repository with PKCE flow
- E-shop UI + mock checkout
- flutter_secure_storage token store
