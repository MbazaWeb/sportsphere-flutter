# Playify deployment

## Server info

- **Server**: deploy@104.152.50.173
- **Domain**: playifysport.fun
- **Web path**: /var/www/playify/
- **APK download**: /var/www/playify/download/Playify.apk

---

## Complete build + deploy sequence

### Prerequisites

- **Windows**: Flutter SDK, Git, SSH client (OpenSSH)
- **Server**: Ubuntu 24.04, Flutter installed OR use pre-built web artifacts

---

### Step 1 — Windows (build APK and Web)

```bash
cd C:\Users\Mbaza\Documents\Playify
git pull origin main
flutter pub get

# Build APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

echo APK: build\app\outputs\flutter-apk\app-release.apk

# Build Web
flutter build web --release \
  --dart-define=SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

echo Web: build\web\
```

### Step 2 — Upload APK to server

```bash
scp build\app\outputs\flutter-apk\app-release.apk deploy@104.152.50.173:/tmp/playify.apk
```

### Step 3a — Upload Web build (from Windows to server)

```bash
# If building on Windows, upload the web build:
scp -r build\web/* deploy@104.152.50.173:/tmp/playify-web/
```

### Step 3b — Server (deploy with git rebase + restart API)

```bash
# SSH to server
ssh deploy@104.152.50.173

# Run the fix script (one-time) to resolve git divergence
sudo bash /var/playify/app/vps/fix_deployment.sh

# OR manually:
cd /var/playify/app
git config pull.rebase true
git fetch origin main
git reset --hard origin/main
rm -f pubspec.lock

# Deploy web (if uploaded)
if [ -d /tmp/playify-web ]; then
  sudo cp -r /tmp/playify-web/* /var/www/playify/
  rm -rf /tmp/playify-web
fi

# Deploy APK
sudo mv /tmp/playify.apk /var/www/playify/downloads/playify.apk
sudo chmod 644 /var/www/playify/downloads/playify.apk

# Restart API
sudo /usr/bin/pm2 restart playify-api --update-env

# Verify
echo "=== Checking API health ==="
curl -s https://playifysport.fun/health | python3 -m json.tool

echo "=== Checking app version endpoint ==="
curl -s https://playifysport.fun/v1/app/version | python3 -m json.tool

echo "=== Checking APK download ==="
curl -I https://playifysport.fun/downloads/playify.apk 2>&1 | grep "HTTP\|Content-Length"

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
