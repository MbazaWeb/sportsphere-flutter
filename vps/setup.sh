#!/usr/bin/env bash
# =============================================================================
# Playify — Hetzner CX22 Full Server Setup
# Ubuntu 24.04 LTS
# Stack: PostgreSQL 16 · Bun · Hono · Soketi · MinIO · Nginx · PM2
# Scale path: CX22 (€3.29) → CPX31 (€13.09) → CPX41 (€27.49)
# Run as root: bash setup.sh
# =============================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

PLAYIFY_DB_PASS="${PLAYIFY_DB_PASS:-$(openssl rand -hex 24)}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-playify}"
MINIO_ROOT_PASS="${MINIO_ROOT_PASS:-$(openssl rand -hex 24)}"
SOKETI_APP_ID="${SOKETI_APP_ID:-playify}"
SOKETI_APP_KEY="${SOKETI_APP_KEY:-$(openssl rand -hex 16)}"
SOKETI_APP_SECRET="${SOKETI_APP_SECRET:-$(openssl rand -hex 32)}"
DOMAIN="${DOMAIN:-playifysport.fun}"

echo "================================================================"
echo " Playify VPS Setup — Hetzner CX22"
echo " Domain: $DOMAIN"
echo "================================================================"

# ─── 1. System baseline ──────────────────────────────────────────────────────
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git unzip build-essential \
  nginx certbot python3-certbot-nginx \
  ufw fail2ban htop lsof \
  postgresql-16 postgresql-client-16

# ─── 2. Firewall ─────────────────────────────────────────────────────────────
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (certbot)
ufw allow 443/tcp   # HTTPS
# Soketi port 6001 NOT exposed — access via Nginx /app/ proxy only
# ufw allow 6001/tcp
ufw --force enable
echo "Firewall configured"

# ─── 3. PostgreSQL 16 ────────────────────────────────────────────────────────
systemctl enable postgresql
systemctl start postgresql

sudo -u postgres psql -c "CREATE USER playify WITH PASSWORD '$PLAYIFY_DB_PASS' SUPERUSER;" 2>/dev/null || \
  sudo -u postgres psql -c "ALTER USER playify WITH PASSWORD '$PLAYIFY_DB_PASS';"
sudo -u postgres psql -c "CREATE DATABASE playify OWNER playify;" 2>/dev/null || true

# pg_hba: allow local password auth
PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
sed -i 's/^local\s\+all\s\+all\s\+peer/local   all             all                                     md5/' "$PG_HBA"
systemctl reload postgresql
echo "PostgreSQL ready"

# ─── 4. Bun runtime ──────────────────────────────────────────────────────────
if ! command -v bun &>/dev/null; then
  curl -fsSL https://bun.sh/install | bash
  ln -sf "$HOME/.bun/bin/bun" /usr/local/bin/bun
fi
echo "Bun $(bun --version) ready"

# ─── 5. Node/PM2 (for Soketi) ────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
npm install -g pm2 @soketi/soketi --silent
pm2 startup systemd -u root --hp /root | tail -1 | bash || true
echo "Node $(node --version) + PM2 + Soketi ready"

# ─── 6. MinIO ────────────────────────────────────────────────────────────────
if [ ! -f /usr/local/bin/minio ]; then
  wget -q https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
  chmod +x /usr/local/bin/minio
fi
if [ ! -f /usr/local/bin/mc ]; then
  wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
  chmod +x /usr/local/bin/mc
fi
mkdir -p /var/playify/storage /var/playify/logs
useradd -r -s /sbin/nologin minio-user 2>/dev/null || true
chown -R minio-user:minio-user /var/playify/storage

cat > /etc/systemd/system/minio.service << EOF
[Unit]
Description=MinIO Object Storage
After=network.target

[Service]
User=minio-user
Group=minio-user
WorkingDirectory=/var/playify/storage
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server /var/playify/storage --console-address ":9001"
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/default/minio << EOF
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASS}
MINIO_VOLUMES=/var/playify/storage
MINIO_OPTS="--console-address :9001"
EOF

systemctl daemon-reload
systemctl enable minio
systemctl start minio
sleep 3

# Create buckets
mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASS" 2>/dev/null || true
mc mb --ignore-existing local/avatars local/covers local/posts local/media 2>/dev/null || true
mc anonymous set public local/avatars local/covers local/posts local/media 2>/dev/null || true
echo "MinIO ready"

# ─── 7. Soketi (Pusher-compatible WebSocket) ─────────────────────────────────
mkdir -p /etc/playify
cat > /etc/playify/soketi.json << EOF
{
  "debug": false,
  "host": "0.0.0.0",
  "port": 6001,
  "appManager.driver": "array",
  "appManager.array.apps": [
    {
      "id": "${SOKETI_APP_ID}",
      "key": "${SOKETI_APP_KEY}",
      "secret": "${SOKETI_APP_SECRET}",
      "maxConnections": 10000,
      "enableClientMessages": true,
      "enabled": true,
      "webhooks": []
    }
  ],
  "metrics.enabled": false,
  "maxBackpressureInBytes": 67108864,
  "httpMaxPayloadSize": 104857600
}
EOF

pm2 start soketi --name playify-soketi -- --config /etc/playify/soketi.json
pm2 save
echo "Soketi realtime ready on :6001"

# ─── 8. Playify API (Bun + Hono) ─────────────────────────────────────────────
# Clone the repo and use the vps/api source directly
mkdir -p /var/playify
if [ ! -d /var/playify/app ]; then
  git clone https://github.com/MbazaWeb/sportsphere-flutter.git /var/playify/app
else
  cd /var/playify/app && git pull && cd /root
fi

cd /var/playify/app/vps/api
bun install

# Create .env from example if not already present
if [ ! -f .env ]; then
  cp /var/playify/app/vps/.env.example .env
  echo "⚠  Edit /var/playify/app/vps/api/.env before starting the API"
fi

# Inject the credentials generated above into the .env
sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://playify:${PLAYIFY_DB_PASS}@localhost:5432/playify|" .env
sed -i "s|MINIO_ROOT_USER=.*|MINIO_ROOT_USER=${MINIO_ROOT_USER}|" .env
sed -i "s|MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASS}|" .env

pm2 start /usr/local/bin/bun --name playify-api -- run src/index.ts
pm2 save
cd /root
echo "Playify API running on :3000"

# ─── 9. Nginx ────────────────────────────────────────────────────────────────
cat > /etc/nginx/sites-available/playify << NGINX_EOF
# Playify — Nginx reverse proxy
# HTTP → HTTPS redirect
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://\$host\$request_uri; }
}

# HTTPS — API + Soketi + MinIO
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL — filled in by certbot
    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;

    # Security headers
    add_header X-Frame-Options       DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy       strict-origin-when-cross-origin;
    add_header Permissions-Policy    "camera=(), microphone=()";

    # Gzip
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;

    client_max_body_size 110M;   # slightly above 100MB media bucket limit

    # ── Soketi WebSocket (/app/  — must be before catch-all) ─────────────
    location /app/ {
        proxy_pass         http://127.0.0.1:6001;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_read_timeout 600s;
    }

    # ── MinIO object storage (/storage/ — before catch-all) ──────────────
    location /storage/ {
        proxy_pass         http://127.0.0.1:9000/;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_buffering    off;
        proxy_read_timeout 300s;
    }

    # ── Hono API — catch-all (/health /v1/* /v1/mpesa/callback etc.) ─────
    # Flutter calls https://playifysport.fun/v1/... directly (no /api prefix)
    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/playify /etc/nginx/sites-enabled/playify
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
echo "Nginx configured"

# ─── 10. Save credentials ────────────────────────────────────────────────────
cat > /root/playify-credentials.txt << CREDS
# Playify VPS Credentials — KEEP SAFE, DO NOT COMMIT
# Generated: $(date -u)

POSTGRES_URL=postgresql://playify:${PLAYIFY_DB_PASS}@localhost:5432/playify

MINIO_ENDPOINT=http://localhost:9000
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASS}
MINIO_CONSOLE=http://localhost:9001

SOKETI_HOST=localhost
SOKETI_PORT=6001
SOKETI_APP_ID=${SOKETI_APP_ID}
SOKETI_APP_KEY=${SOKETI_APP_KEY}
SOKETI_APP_SECRET=${SOKETI_APP_SECRET}

API_URL=https://${DOMAIN}/api
CREDS
chmod 600 /root/playify-credentials.txt

# ─── 11. PM2 status ──────────────────────────────────────────────────────────
pm2 list

echo ""
echo "================================================================"
echo " Playify server ready on Hetzner CX22"
echo ""
echo " Next steps:"
echo "   1. Point DNS: A ${DOMAIN} → $(curl -s ifconfig.me)"
echo "   2. TLS:  certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@playify.app"
echo "   3. Run migrations: psql \$POSTGRES_URL < prisma/migrations/20260825999999_consolidated/migration.sql"
echo "   4. Edit /var/playify/api/.env with your keys"
echo "   5. Scale: Hetzner console → resize to CPX31 when RAM >70%"
echo ""
echo " Credentials saved to: /root/playify-credentials.txt"
echo "================================================================"
