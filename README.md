# SportSphere

A sports network for fans, players, teams, media, and the business side of the game.
Dark UI. Live scores. Communities. Shop.

## Stack

- Flutter 3 / Dart 3.8
- Riverpod 3
- go_router 17
- Dio + flutter_secure_storage
- Supabase (auth + database)
- Package id: `com.sportsphere.sportsphere_app`

## Environment variables

Secrets are passed as **compile-time constants** via `--dart-define` — they are
never stored in files bundled with the app.

```
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

> **Never** add `.env` back to `pubspec.yaml` assets. Bundled `.env` files
> are readable by anyone who unpacks the APK.

For VS Code, add a `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "SportSphere",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://your-project.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your-anon-key"
      ]
    }
  ]
}
```

## Run

```
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## What it is today

Flutter client (Android / iOS / web) with:

- Animated splash, then the main shell
- Home feed tabs: Spotlights, Trending, Community, E-Shop
- Scores (Ligi Kuu Bara 2026/27 fixture calendar — 240 matches)
- Full profiles: 22 roles across Fan, Player, Team, and more
- Club shop: merch, tickets, membership, donate + mock checkout
- Admin console is web-only (not in this client)

Auth, feed APIs, and live payments are scaffolded — backend wiring in progress.

## Project layout

```
lib/
  main.dart                  # entry point — reads dart-define constants
  splash_screen.dart
  app/                       # app widget, router
  app/config/env.dart        # dart-define constant accessors (no dotenv)
  core/network/              # Dio client, errors, auth header interceptor
  core/storage/              # secure token store (Keystore / Secure Enclave)
  features/auth/             # Supabase auth repository + Riverpod controller
  features/shell/            # tab shell (parts/ for screens)
  features/scores/           # Ligi Kuu Bara fixture calendar + live detection
  features/profile/          # 22 role profile views
  features/shop/             # e-shop UI + checkout flow
```

## Account roles

Fan, player, coach, team, league, competition, official, scout, agent,
support staff, academy, venue, journalist, commentator, analyst, creator,
moderator, organization, sponsor, commercial partner, media/broadcast, business.

## Release signing (Android)

1. Generate an upload keystore (see `android/key.properties.example`).
2. Copy to `android/key.properties` and fill in values.
3. `key.properties` and `*.jks` are gitignored — do not commit them.

For release builds:

```
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## CI

GitHub Actions runs on every push to `main` and `develop`:

- `flutter analyze` (lint + type check)
- `flutter test`
- Android debug APK build

See `.github/workflows/ci.yml`.

## Security

See [SECURITY.md](SECURITY.md) for our vulnerability reporting policy.
