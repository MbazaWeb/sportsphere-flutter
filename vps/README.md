# Playify VPS — Hetzner Setup & Scale Path

## Start Here → Scale Up

```
Now (0–10k users)     Later (10k–100k)      Big (100k–1M+)
──────────────────    ────────────────       ───────────────
Hetzner CX22          Hetzner CPX31          Hetzner CPX41
2 vCPU / 4 GB RAM     4 vCPU / 8 GB RAM      8 vCPU / 16 GB RAM
€3.29/mo              €13.09/mo              €27.49/mo
```

Hetzner resizes with one click — zero migration, zero data loss, ~2 min reboot.

## Stack on CX22

| Service | Port | Purpose |
|---|---|---|
| PostgreSQL 16 | 5432 (local) | Primary database |
| Bun + Hono | 3000 (local) | REST API |
| Soketi | 6001 | Pusher-compatible WebSocket (live scores, feed, DMs) |
| MinIO | 9000/9001 (local) | S3-compatible object storage (images, video, podcast) |
| Nginx | 80/443 | Reverse proxy + TLS termination |
| PM2 | — | Process manager (auto-restart on crash) |
| Cloudflare | DNS/CDN | Free CDN, absorbs most read traffic, zero egress |

## Deploy

```bash
# 1. Create Hetzner CX22 (Ubuntu 24.04)
#    Set SSH key during creation

# 2. SSH in and run setup
ssh root@YOUR_SERVER_IP
curl -fsSL https://raw.githubusercontent.com/MbazaWeb/sportsphere-flutter/main/vps/setup.sh | \
  DOMAIN=api.playify.app bash

# 3. Point DNS
#    A api.playify.app → YOUR_SERVER_IP  (in Cloudflare, proxy ON)

# 4. TLS
certbot --nginx -d api.playify.app --non-interactive --agree-tos -m admin@playify.app

# 5. Run database migration
psql $DATABASE_URL < prisma/migrations/20260825999999_consolidated/migration.sql

# 6. Fill env and restart API
cp vps/.env.example /var/playify/api/.env
nano /var/playify/api/.env   # fill in secrets
pm2 restart playify-api
```

## Scale Triggers

| Signal | Action |
|---|---|
| RAM consistently >70% | Resize to CPX31 (Hetzner console → 1 click) |
| CPU spikes during live matches | Resize to CPX41 |
| Storage >80% full | Add Hetzner Volume (€0.059/GB/mo), mount to `/var/playify/storage` |
| DB slowing down | Move Postgres to separate CX22 (DB-only), update `DATABASE_URL` |
| 100k+ concurrent realtime | Move Soketi to its own CX22, update `SOKETI_HOST` |
| Media CDN costs rising | Switch MinIO to Backblaze B2 + Cloudflare (Bandwidth Alliance = $0 egress) |

## PM2 Commands

```bash
pm2 list                  # all processes
pm2 logs playify-api      # API logs
pm2 logs playify-soketi   # WebSocket logs
pm2 restart all           # restart everything
pm2 monit                 # live dashboard
```

## MinIO Console

Access at `http://YOUR_SERVER_IP:9001` (block in UFW for production — access via SSH tunnel):

```bash
ssh -L 9001:localhost:9001 root@YOUR_SERVER_IP
# then open http://localhost:9001
```

## Backups

```bash
# PostgreSQL daily backup (add to cron)
pg_dump $DATABASE_URL | gzip > /var/backups/playify-$(date +%Y%m%d).sql.gz

# Cron: every day at 2am
echo "0 2 * * * root pg_dump postgresql://playify:PASS@localhost/playify | gzip > /var/backups/playify-\$(date +\%Y\%m\%d).sql.gz" >> /etc/cron.d/playify-backup
```

## Flutter → VPS (when ready to wire)

```dart
// dart_defines.json (already in repo)
{
  "SUPABASE_URL": "https://fffqjbrethogesgghjsn.supabase.co",  // keep during transition
  "API_BASE_URL": "https://api.playify.app/api",               // VPS API
  "SOKETI_KEY": "YOUR_SOKETI_APP_KEY",
  "SOKETI_HOST": "api.playify.app",
  "STORAGE_BASE": "https://api.playify.app/storage"
}
```
