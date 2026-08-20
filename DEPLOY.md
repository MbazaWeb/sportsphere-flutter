# SportSphere deployment

## Supabase (already used by the app)

```bash
npx supabase link --project-ref fffqjbrethogesgghjsn
npx supabase db push
npx supabase functions deploy ai-assistant
npx supabase secrets set ANTHROPIC_API_KEY=*** DEEPSEEK_API_KEY=***
```

Never put AI keys in the Flutter APK or public GitHub.

## Admin console (Vite)

```bash
cd admin
npm install
npm run build
# serve dist/ with nginx or:
npx serve -s dist -l 4173
```

SSH example (password provided privately):

```bash
ssh deploy@104.152.50.173
# rsync admin/dist to /var/www/sportsphere-admin
```

## Flutter Android Play Store release

1. Create a keystore (once):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. `android/key.properties` (gitignored):

```
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=../upload-keystore.jks
```

3. Build app bundle:

```bash
flutter pub get
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Output: `build/app/outputs/bundle/release/app-release.aab`

4. Play Console: create app → Production/Internal testing → upload AAB → complete store listing, content rating, privacy policy URL.

5. Optional APK for testers:

```bash
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Security note

Rotate any API keys that were pasted in chat. Treat them as compromised until rotated.
