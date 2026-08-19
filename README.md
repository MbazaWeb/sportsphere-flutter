# SportSphere

A sports network for fans, players, teams, media, and the business side of the game.
Dark UI. Live scores. Communities. Shop.

## What it is today

Flutter client (Android / iOS / web) with:

- Animated splash, then the main shell
- Home feed tabs: Spotlights, Trending, Community, E-Shop
- Scores (mock match data)
- Full profiles: Fan, Player, Team
- 20 remaining roles via 3 templates (person / org / commerce)
- Club shop: merch, tickets, membership, donate + mock checkout
- Admin console is web-only (not in this client)

Auth, feed APIs, and live payments are still scaffolded.

## Stack

- Flutter 3 / Dart 3.8
- Riverpod
- go_router
- Dio + flutter_secure_storage
- Package id: `com.sportsphere.sportsphere_app`

## Run

```bash
flutter pub get
flutter run
```

Point the API at a local or staging backend:

```bash
flutter run --dart-define=API_BASE_URL=https://api.sportsphere.app
```

## Project layout

```
lib/
  main.dart                 # single entry
  splash_screen.dart
  app/                      # app widget, router, env
  core/network/             # Dio client, errors, auth header
  core/storage/             # secure token store
  features/auth/            # repository + Riverpod controller
  features/shell/           # tab shell (parts/ for screens)
  features/scores/
  features/profile/
```

## Account roles (profile stubs)

Fan, player, coach, team, league, competition, official, scout, agent,
support staff, academy, venue, journalist, commentator, analyst, creator,
moderator, organization, sponsor, commercial partner, media/broadcast, business.

## Release signing (Android)

1. Generate an upload keystore (see `android/key.properties.example`).
2. Copy `android/key.properties.example` to `android/key.properties`.
3. `key.properties` and `*.jks` are gitignored. Do not commit them.

Until `key.properties` exists, `flutter run --release` still falls back to the debug keystore so local testing works.

## Sharing source

Do not zip `build/` or `.dart_tool/` (Chrome profile + caches).

```powershell
powershell -ExecutionPolicy Bypass -File .\fix_sportsphere.ps1
```

That writes `sportsphere_app-src.zip` next to the project folder.

Or:

```bash
git archive -o sportsphere_app-src.zip HEAD
```
