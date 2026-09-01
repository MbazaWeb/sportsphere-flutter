# Playify deployment

## Server info

- **Server**: deploy@104.152.50.173
- **Domain**: playifysport.fun
- **Web path**: /var/www/playify/
- **APK download**: /var/www/playify/download/Playify.apk

---

## Complete build + deploy sequence

### Step 1 — Windows (build APK and Web)

```bash
cd C:\Users\Mbaza\Documents\Playify
git pull origin main
flutter pub get

# Build APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

echo APK built: build\app\outputs\flutter-apk\app-release.apk

# Build Web
flutter build web --release \
  --dart-define=SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

echo Web built: build\web\
```

### Step 2 — Upload APK to server

```bash
scp build\app\outputs\flutter-apk\app-release.apk deploy@104.152.50.173:/tmp/playify.apk
```

### Step 3 — Server (deploy all components)

```bash
# 1. Update app code and restart API
cd /var/playify/app
git stash
git pull origin main
git stash pop 2>/dev/null || true
sudo /usr/bin/pm2 restart playify-api --update-env

# 2. Deploy web build (from uploaded or built on server)
~/flutter/bin/flutter build web --release \
  --dart-define=SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... && \
sudo cp -r build/web/* /var/www/playify/

# 3. Deploy APK to download directory
sudo mv /tmp/playify.apk /var/www/playify/download/Playify.apk
sudo chmod 644 /var/www/playify/download/Playify.apk

# 4. Verify deployments
echo "=== Checking API health ==="
curl -s https://playifysport.fun/health | python3 -m json.tool

echo "=== Checking app version endpoint ==="
curl -s https://playifysport.fun/v1/app/version | python3 -m json.tool

echo "=== Checking APK download ==="
curl -I https://playifysport.fun/download/Playify.apk 2>&1 | grep "HTTP\|Content-Length"

echo "✅ All deployments verified"
```

---

## Supabase setup (one-time)

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

Deploy to server:

```bash
ssh deploy@104.152.50.173
# rsync admin/dist to /var/www/playify-admin
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
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Output: `build/app/outputs/bundle/release/app-release.aab`

4. Play Console: create app → Production/Internal testing → upload AAB → complete store listing, content rating, privacy policy URL.

5. Optional APK for testers:

```bash
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Security note

Rotate any API keys that were pasted in chat. Treat them as compromised until rotated.
