#!/usr/bin/env bash
# =============================================================================
# Playify — Server maintenance crons
# Install: bash vps/cron.sh
# =============================================================================
set -euo pipefail

echo "Installing Playify maintenance crons..."

# ── 1. SSL renewal (Let's Encrypt) ────────────────────────────────────────────
# Runs twice daily (standard certbot recommendation)
# Renews only when cert is within 30 days of expiry
cat > /etc/cron.d/playify-ssl << 'SSL'
0 3,15 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx" 2>&1 | logger -t playify-ssl
SSL
chmod 644 /etc/cron.d/playify-ssl
echo "✅ SSL renewal cron — runs at 3am + 3pm daily"

# ── 2. Auto-deploy (git pull every 5 min) ────────────────────────────────────
cat > /etc/cron.d/playify-autodeploy << 'DEPLOY'
*/5 * * * * david cd /var/playify/app && git pull --rebase origin main --quiet 2>/dev/null && cd vps/api && /home/david/.bun/bin/bun install --frozen-lockfile --quiet 2>/dev/null; sudo /usr/bin/pm2 restart playify-api --silent >> /var/playify/logs/autodeploy.log 2>&1
DEPLOY
chmod 644 /etc/cron.d/playify-autodeploy
echo "✅ Auto-deploy cron — every 5 minutes"

# ── 3. PM2 log rotation ────────────────────────────────────────────────────────
cat > /etc/cron.d/playify-logs << 'LOGS'
0 0 * * 0 root /usr/bin/pm2 flush playify-api --silent 2>/dev/null; /usr/bin/pm2 flush playify-soketi --silent 2>/dev/null; truncate -s 0 /var/playify/logs/autodeploy.log
LOGS
chmod 644 /etc/cron.d/playify-logs
echo "✅ Log rotation — every Sunday midnight"

# ── 4. Expired token cleanup ──────────────────────────────────────────────────
ENV_FILE="/var/playify/app/vps/api/.env"
if [ -f "$ENV_FILE" ]; then
  DB_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
  cat > /etc/cron.d/playify-cleanup << CLEANUP
0 4 * * * root psql '$DB_URL' -c "DELETE FROM public.refresh_tokens WHERE expires_at < NOW(); DELETE FROM public.password_resets WHERE expires_at < NOW();" --quiet 2>/dev/null
CLEANUP
  chmod 644 /etc/cron.d/playify-cleanup
  echo "✅ Token cleanup — daily at 4am"
fi

# ── 5. Verify SSL cert ─────────────────────────────────────────────────────────
echo ""
echo "Current SSL cert status:"
certbot certificates 2>/dev/null | grep -E "Domains:|Expiry|VALID" | head -6 || echo "  (run certbot certificates to check)"

echo ""
echo "✅ All crons installed. Active crons:"
ls /etc/cron.d/playify-*
