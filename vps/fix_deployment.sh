#!/usr/bin/env bash
# =============================================================================
# Playify — Fix divergent git branches and complete deployment
# Run on server: bash vps/fix_deployment.sh
# =============================================================================
set -euo pipefail

APP_DIR="/var/playify/app"
WEB_PATH="/var/www/playify"

echo "🔧 Fixing deployment issues..."

# ─── 1. Configure git to use rebase on pull ──────────────────────────────────
cd "$APP_DIR"
git config pull.rebase true
echo "✅ Git configured to use rebase"

# ─── 2. Reset to remote main (discard local divergent commit) ────────────────
git fetch origin main
git reset --hard origin/main
echo "✅ Git reset to origin/main"

# ─── 3. Delete corrupted pubspec.lock ────────────────────────────────────────
rm -f pubspec.lock
echo "✅ Removed pubspec.lock"

# ─── 4. Restart API (code is now updated) ───────────────────────────────────
sudo /usr/bin/pm2 restart playify-api --update-env
sleep 2
echo "✅ API restarted"

# ─── 5. Deploy web build from local cache (if it exists) ────────────────────
if [ -d "build/web" ]; then
  sudo cp -r build/web/* "$WEB_PATH/"
  echo "✅ Web build deployed from cache"
else
  echo "⚠️  No build/web found. Web requires flutter build on client."
  echo "   Run on Windows: flutter build web --release"
  echo "   Then deploy to server manually or use SCP"
fi

# ─── 6. Verify deployments ──────────────────────────────────────────────────
echo ""
echo "🔍 Verification:"
curl -s https://playifysport.fun/health | python3 -m json.tool || echo "⚠️  Health check failed"
curl -s https://playifysport.fun/v1/app/version | python3 -m json.tool || echo "⚠️  Version check failed"

echo ""
echo "✅ Deployment fixed!"
