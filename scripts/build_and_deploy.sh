#!/usr/bin/env bash
# Build Playify web + APK and deploy to server.
# Usage:
#   ./scripts/build_and_deploy.sh           # build + deploy everything
#   ./scripts/build_and_deploy.sh --skip-web
#   ./scripts/build_and_deploy.sh --skip-apk
#   ./scripts/build_and_deploy.sh --skip-server   # build only, no deploy

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

SKIP_WEB=false
SKIP_APK=false
SKIP_SERVER=false
SERVER_HOST="${SERVER_HOST:-95.217.20.12}"
SERVER_USER="${SERVER_USER:-david}"
WEB_PATH="${WEB_PATH:-/var/www/playify}"
APK_PATH="${APK_PATH:-/var/www/playify/downloads}"

for arg in "$@"; do
  case "$arg" in
    --skip-web) SKIP_WEB=true ;;
    --skip-apk) SKIP_APK=true ;;
    --skip-server) SKIP_SERVER=true ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

echo ""
echo "========================================"
echo "  Playify Build & Deploy"
echo "========================================"

# ── 1. Load .env ────────────────────────────────────────────────────────────
ENV_FILE="$PROJECT_ROOT/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: Missing .env file at $ENV_FILE"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env"
  exit 1
fi

echo ""
echo "[1/5] Supabase URL: $SUPABASE_URL"
echo "      Anon Key: ${SUPABASE_ANON_KEY:0:20}..."

# ── 2. Flutter clean + pub get ──────────────────────────────────────────────
echo ""
echo "[2/5] Cleaning + fetching dependencies..."
flutter clean
flutter pub get

# ── 3. Build Web ────────────────────────────────────────────────────────────
if [ "$SKIP_WEB" = false ]; then
  echo ""
  echo "[3/5] Building Web (release)..."
  flutter build web --release --base-href /playify/ \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

  WEB_BUILD="$PROJECT_ROOT/build/web"
  WEB_SIZE=$(du -sh "$WEB_BUILD" | cut -f1)
  echo "      Web build: $WEB_BUILD ($WEB_SIZE)"

  if [ "$SKIP_SERVER" = false ]; then
    echo ""
    echo "      Deploying web to $SERVER_USER@$SERVER_HOST:$WEB_PATH ..."
    ssh "$SERVER_USER@$SERVER_HOST" "sudo mkdir -p $WEB_PATH && sudo chown $SERVER_USER:$SERVER_USER $WEB_PATH"
    rsync -avz --delete -e ssh "$WEB_BUILD/" "$SERVER_USER@$SERVER_HOST:$WEB_PATH/"
    echo "      Web deployed to https://$SERVER_HOST/playify/"
  fi
else
  echo ""
  echo "[3/5] Skipping web build"
fi

# ── 4. Build APK ────────────────────────────────────────────────────────────
if [ "$SKIP_APK" = false ]; then
  echo ""
  echo "[4/5] Building APK (release)..."
  flutter build apk --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

  APK_PATH_LOCAL="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
  APK_SIZE=$(du -h "$APK_PATH_LOCAL" | cut -f1)
  echo "      APK: $APK_PATH_LOCAL ($APK_SIZE)"

  if [ "$SKIP_SERVER" = false ]; then
    echo ""
    echo "      Uploading APK to $SERVER_USER@$SERVER_HOST:$APK_PATH ..."
    ssh "$SERVER_USER@$SERVER_HOST" "sudo mkdir -p $APK_PATH && sudo chown $SERVER_USER:$SERVER_USER $APK_PATH"

    VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}')
    REMOTE_APK="playify-$VERSION.apk"
    scp "$APK_PATH_LOCAL" "$SERVER_USER@$SERVER_HOST:$APK_PATH/$REMOTE_APK"
    ssh "$SERVER_USER@$SERVER_HOST" "cp $APK_PATH/$REMOTE_APK $APK_PATH/playify-latest.apk"

    echo "      APK uploaded: https://$SERVER_HOST/playify/downloads/$REMOTE_APK"
    echo "      Latest APK:   https://$SERVER_HOST/playify/downloads/playify-latest.apk"
  fi
else
  echo ""
  echo "[4/5] Skipping APK build"
fi

# ── 5. Summary ──────────────────────────────────────────────────────────────
echo ""
echo "[5/5] Build & Deploy Complete!"
echo "========================================"
if [ "$SKIP_WEB" = false ]; then
  echo "  Web:  https://$SERVER_HOST/playify/"
fi
if [ "$SKIP_APK" = false ]; then
  VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}')
  echo "  APK:  https://$SERVER_HOST/playify/downloads/playify-$VERSION.apk"
fi
echo "========================================"
echo ""
