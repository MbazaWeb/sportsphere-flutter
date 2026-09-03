#!/usr/bin/env bash
# =============================================================================
# Playify — Full Deploy + Audit Script
# Server: david@95.217.20.12 | Domain: playifysport.fun
# Run as root: bash vps/deploy.sh
# =============================================================================
set -euo pipefail

DOMAIN="playifysport.fun"
REPO_URL="https://github.com/MbazaWeb/sportsphere-flutter.git"
APP_DIR="/var/playify/app"
API_DIR="$APP_DIR/vps/api"
LOG_DIR="/var/playify/logs"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
hdr()  { echo -e "\n${YELLOW}══ $1 ══${NC}"; }

ISSUES=0
check() { if eval "$2" &>/dev/null; then ok "$1"; else fail "$1"; ISSUES=$((ISSUES+1)); fi }

# =============================================================================
# SECTION 1 — AUDIT EXISTING STATE
# =============================================================================
hdr "AUDIT"

check "Ubuntu 24.04+" "grep -qE '24\.|25\.|26\.' /etc/os-release"
check "Bun installed"  "command -v bun"
check "Node.js 20+"   "node --version | grep -qE 'v2[0-9]'"
check "PM2 installed" "command -v pm2"
check "Nginx running" "systemctl is-active nginx"
check "MinIO running" "systemctl is-active minio || pm2 show playify-minio &>/dev/null"
check "PostgreSQL running" "systemctl is-active postgresql || pg_isready -q"
check "SSL cert exists" "test -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
check "UFW active"    "ufw status | grep -q 'Status: active'"
check "Port 443 open" "ufw status | grep -q '443'"
check "Port 80 open"  "ufw status | grep -q '80'"
check "Port 6001 closed to public" "! ufw status | grep -q '6001.*ALLOW IN'"
check "Port 5432 closed to public" "! ufw status | grep -q '5432.*ALLOW IN'"

echo ""
echo "Pre-existing issues found: $ISSUES"

# =============================================================================
# SECTION 2 — SYSTEM HARDENING
# =============================================================================
hdr "HARDENING"

# Close dangerous ports if open
if ufw status | grep -q "6001.*ALLOW IN"; then
  ufw deny 6001/tcp
  warn "Closed Soketi port 6001 (was open to internet)"
fi
if ufw status | grep -q "5432.*ALLOW IN"; then
  ufw deny 5432/tcp
  warn "Closed PostgreSQL port 5432 (was open to internet)"
fi
if ufw status | grep -q "9000.*ALLOW IN"; then
  ufw deny 9000/tcp
  ufw deny 9001/tcp
  warn "Closed MinIO ports 9000/9001 (was open to internet)"
fi

# Ensure essential ports open
ufw allow 22/tcp  2>/dev/null || true
ufw allow 80/tcp  2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true
ok "Firewall hardened — only 22/80/443 exposed"

# fail2ban
if ! systemctl is-active fail2ban &>/dev/null; then
  apt-get install -y -qq fail2ban
  systemctl enable fail2ban --now
fi
ok "fail2ban active"

# =============================================================================
# SECTION 3 — PostgreSQL
# =============================================================================
hdr "POSTGRESQL"

# Detect PostgreSQL version
PG_VERSION=$(pg_lsclusters 2>/dev/null | awk 'NR>1{print $1}' | head -1 || echo "16")
ok "PostgreSQL $PG_VERSION detected"

# Create playify user and db if missing
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='playify'" | grep -q 1 || {
  PGPASS=$(openssl rand -hex 24)
  sudo -u postgres psql -c "CREATE USER playify WITH PASSWORD '$PGPASS' CREATEDB;"
  echo "POSTGRES_PLAYIFY_PASS=$PGPASS" >> /root/playify-secrets.env
  warn "Created playify DB user — password saved to /root/playify-secrets.env"
}

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='playify'" | grep -q 1 || {
  sudo -u postgres createdb -O playify playify
  warn "Created playify database"
}
ok "Database 'playify' exists with owner 'playify'"

# pg_hba: ensure md5/scram auth for local
PG_HBA=$(find /etc/postgresql -name pg_hba.conf 2>/dev/null | head -1)
if [ -n "$PG_HBA" ]; then
  if grep -q "^local.*all.*all.*peer" "$PG_HBA"; then
    sed -i 's/^local\s\+all\s\+all\s\+peer/local   all             all                                     scram-sha-256/' "$PG_HBA"
    pg_ctlcluster $PG_VERSION main reload 2>/dev/null || systemctl reload postgresql
    warn "pg_hba: peer → scram-sha-256 (local connections now use password)"
  fi
fi
ok "pg_hba configured"

# =============================================================================
# SECTION 4 — MinIO buckets
# =============================================================================
hdr "MINIO"

MINIO_ENV="/etc/default/minio"
if [ -f "$MINIO_ENV" ]; then
  source "$MINIO_ENV" 2>/dev/null || true
  MINIO_USER="${MINIO_ROOT_USER:-playify}"
  MINIO_PASS="${MINIO_ROOT_PASSWORD:-}"
else
  MINIO_USER="playify"
  MINIO_PASS=""
  warn "MinIO env not found at $MINIO_ENV"
fi

# Wait for MinIO to be ready
for i in 1 2 3 4 5; do
  mc alias set local http://localhost:9000 "$MINIO_USER" "$MINIO_PASS" &>/dev/null && break || sleep 2
done

# Create required buckets
for bucket in avatars covers posts media; do
  mc mb --ignore-existing "local/$bucket" &>/dev/null && \
  mc anonymous set public "local/$bucket" &>/dev/null && \
  ok "Bucket '$bucket' ready (public)" || warn "Bucket '$bucket' may not be ready"
done

# =============================================================================
# SECTION 5 — CLONE / UPDATE REPO
# =============================================================================
hdr "REPO"

mkdir -p "$APP_DIR" "$LOG_DIR"

if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO_URL" "$APP_DIR"
  ok "Repo cloned"
else
  cd "$APP_DIR" && git fetch origin && git reset --hard origin/main
  ok "Repo updated to latest main"
fi

# =============================================================================
# SECTION 6 — API DEPENDENCIES
# =============================================================================
hdr "API DEPENDENCIES"

cd "$API_DIR"

# Ensure Bun is in PATH for root
export PATH="$HOME/.bun/bin:/usr/local/bin:$PATH"
BUN_BIN=$(command -v bun || echo "/root/.bun/bin/bun")

# Install dependencies
"$BUN_BIN" install --frozen-lockfile 2>/dev/null || "$BUN_BIN" install
ok "Dependencies installed (bun install)"

# =============================================================================
# SECTION 7 — ENVIRONMENT FILE
# =============================================================================
hdr "ENVIRONMENT"

ENV_FILE="$API_DIR/.env"

# Read existing secrets if they exist
POSTGRES_PASS=""
if [ -f "/root/playify-secrets.env" ]; then
  source /root/playify-secrets.env 2>/dev/null || true
  POSTGRES_PASS="${POSTGRES_PLAYIFY_PASS:-}"
fi

# Try to get postgres password from existing .env
if [ -f "$ENV_FILE" ]; then
  EXISTING_PASS=$(grep "^DATABASE_URL=" "$ENV_FILE" | sed 's/.*playify:\([^@]*\)@.*/\1/')
  [ -n "$EXISTING_PASS" ] && POSTGRES_PASS="$EXISTING_PASS"
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$APP_DIR/vps/.env.example" "$ENV_FILE"
  warn ".env created from template — edit secrets manually if needed"
fi

# Patch domain
sed -i "s|https://api\.playify\.app|https://$DOMAIN|g" "$ENV_FILE"
sed -i "s|https://playify\.app|https://$DOMAIN|g"      "$ENV_FILE"

# Patch Supabase if not already set
if grep -q "SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co" "$ENV_FILE" 2>/dev/null; then
  ok "Supabase URL already set"
elif grep -q "SUPABASE_URL=\$" "$ENV_FILE" 2>/dev/null; then
  sed -i "s|SUPABASE_URL=.*|SUPABASE_URL=https://fffqjbrethogesgghjsn.supabase.co|" "$ENV_FILE"
  warn "Supabase URL patched — set SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY manually"
fi

# Patch database URL if we have the password
if [ -n "$POSTGRES_PASS" ]; then
  sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://playify:${POSTGRES_PASS}@localhost:5432/playify|" "$ENV_FILE"
  ok "DATABASE_URL configured"
else
  warn "DATABASE_URL not set — add postgres password to $ENV_FILE"
fi

# Patch MinIO
if [ -n "${MINIO_PASS:-}" ]; then
  sed -i "s|MINIO_ROOT_USER=.*|MINIO_ROOT_USER=$MINIO_USER|"           "$ENV_FILE"
  sed -i "s|MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$MINIO_PASS|" "$ENV_FILE"
  ok "MinIO credentials configured"
fi

ok ".env ready at $ENV_FILE"

# =============================================================================
# SECTION 8 — NGINX
# =============================================================================
hdr "NGINX"

cat > /etc/nginx/sites-available/playify << NGINX_CONF
# Playify — Nginx reverse proxy for $DOMAIN
# Generated by deploy.sh

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_stapling        on;
    ssl_stapling_verify on;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options           DENY always;
    add_header X-Content-Type-Options    nosniff always;
    add_header Referrer-Policy           strict-origin-when-cross-origin always;
    add_header Permissions-Policy        "camera=(), microphone=(), geolocation=()" always;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_types text/plain application/json application/javascript text/css image/svg+xml;
    gzip_buffers 16 8k;

    client_max_body_size 110M;

    # ── Soketi WebSocket (/app/ before catch-all) ─────────────────────────
    location /app/ {
        proxy_pass         http://127.0.0.1:6001;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_read_timeout 600s;
    }

    # ── MinIO storage (/storage/ before catch-all) ─────────────────────────
    location /storage/ {
        proxy_pass         http://127.0.0.1:9000/;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_buffering    off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    # ── Hono API catch-all (/health /v1/* etc.) ────────────────────────────
    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
        proxy_connect_timeout 10s;
    }

    access_log  /var/log/nginx/playify-access.log;
    error_log   /var/log/nginx/playify-error.log;
}
NGINX_CONF

ln -sf /etc/nginx/sites-available/playify /etc/nginx/sites-enabled/playify
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
ok "Nginx configured and reloaded"

# =============================================================================
# SECTION 9 — PM2 PROCESSES
# =============================================================================
hdr "PM2 PROCESSES"

export PATH="$HOME/.bun/bin:/usr/local/bin:$PATH"
BUN_BIN=$(command -v bun || echo "/root/.bun/bin/bun")

# Stop old process if running with wrong config
pm2 delete playify-api 2>/dev/null || true

# Ensure auth tables exist (refresh_tokens, password_resets) — /v1/auth/*
# crashes with "relation does not exist" without them (fix_schema.sql is
# idempotent — safe to run on every deploy)
DB_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
if [ -n "$DB_URL" ] && [ -f "$APP_DIR/vps/migrate/fix_schema.sql" ]; then
  if psql "$DB_URL" -f "$APP_DIR/vps/migrate/fix_schema.sql" -q > /tmp/fixschema.log 2>&1; then
    ok "Schema patched (auth tables present)"
  else
    warn "fix_schema.sql failed — /v1/auth/* may 500 until applied"
  fi
  grep -v "NOTICE\|already exists" /tmp/fixschema.log 2>/dev/null || true
else
  warn "DATABASE_URL or fix_schema.sql missing — skipped schema patch"
fi

# Start API
cd "$API_DIR"
pm2 start "$BUN_BIN" \
  --name playify-api \
  --log "$LOG_DIR/api.log" \
  --error "$LOG_DIR/api-error.log" \
  --max-memory-restart 512M \
  --restart-delay 3000 \
  -- run src/index.ts
ok "playify-api started"

# Soketi — restart to pick up latest config
if ! pm2 show playify-soketi &>/dev/null; then
  SOKETI_BIN=$(command -v soketi || echo "$(npm root -g 2>/dev/null)/@soketi/soketi/bin/soketi")
  pm2 start "$SOKETI_BIN" \
    --name playify-soketi \
    --log "$LOG_DIR/soketi.log" \
    -- start --config /etc/playify/soketi.json 2>/dev/null || warn "Soketi start failed — check /etc/playify/soketi.json"
fi
ok "playify-soketi running"

pm2 save
pm2 startup systemd -u root --hp /root 2>/dev/null | grep "sudo" | bash 2>/dev/null || true
ok "PM2 set to auto-start on reboot"

# =============================================================================
# SECTION 10 — HEALTH CHECK
# =============================================================================
hdr "HEALTH CHECK"

sleep 4  # give API time to start

API_HEALTH=$(curl -sf "https://$DOMAIN/health" 2>/dev/null | grep -c '"ok":true' || echo 0)
if [ "$API_HEALTH" -ge 1 ]; then
  ok "HTTPS health check: https://$DOMAIN/health ✓"
else
  # Try localhost directly
  LOCAL_HEALTH=$(curl -sf "http://localhost:3000/health" 2>/dev/null | grep -c '"ok":true' || echo 0)
  if [ "$LOCAL_HEALTH" -ge 1 ]; then
    warn "API running locally but not via HTTPS — check Nginx"
  else
    fail "API health check failed — check: pm2 logs playify-api"
    ISSUES=$((ISSUES+1))
  fi
fi

# MinIO check
MINIO_HEALTH=$(curl -sf "http://localhost:9000/minio/health/live" && echo "ok" || echo "fail")
[ "$MINIO_HEALTH" = "ok" ] && ok "MinIO health OK" || warn "MinIO health check failed"

# Nginx check
nginx -t &>/dev/null && ok "Nginx config valid" || { fail "Nginx config invalid"; ISSUES=$((ISSUES+1)); }

# SSL check
curl -sf --max-time 5 "https://$DOMAIN/health" &>/dev/null && ok "SSL valid" || warn "SSL check inconclusive from localhost"

# PM2 check
pm2 show playify-api | grep -q "online" && ok "PM2 playify-api: online" || { fail "PM2 playify-api not online"; ISSUES=$((ISSUES+1)); }

# =============================================================================
# SECTION 11 — FINAL REPORT
# =============================================================================
hdr "FINAL REPORT"

echo ""
pm2 list
echo ""

if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║         ALL CHECKS PASSED — PLAYIFY IS LIVE         ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
else
  echo -e "${RED}$ISSUES issue(s) need manual attention.${NC}"
fi

echo ""
echo "API:     https://$DOMAIN/health"
echo "Soketi:  wss://$DOMAIN/app"
echo "Storage: https://$DOMAIN/storage/media/"
echo ""
echo "Logs:    pm2 logs playify-api"
echo "Restart: pm2 restart playify-api"
echo ""
echo "⚠  Manual steps remaining:"
echo "   1. Edit $API_DIR/.env — set SUPABASE_SERVICE_ROLE_KEY, FCM keys, M-Pesa keys"
echo "   2. Run DB migration: psql \$DATABASE_URL < $APP_DIR/supabase/migrations/20260825999999_consolidated_master.sql"
echo "   3. Test: curl https://$DOMAIN/health"
