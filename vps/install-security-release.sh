#!/usr/bin/env bash
# Run with sudo after candidate validation. Retains the old configuration for rollback.
set -Eeuo pipefail
test "$(id -u)" = 0
stage=/home/david/playify-fix-stage
test -s "$stage/admin/dist/index.html"
test -s "$stage/vps/api/src/index.ts"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup=/var/backups/playify-release-$stamp
release=/opt/playify/releases/$stamp
install -d -m 700 "$backup"
runuser -u postgres -- pg_dump -Fc playify > "$backup/predeploy.dump"
pg_restore --list "$backup/predeploy.dump" > /dev/null
cp -a /etc/nginx/sites-enabled/playify "$backup/nginx-link"
cp -L /etc/nginx/sites-enabled/playify "$backup/nginx.conf"
if test -f /etc/cron.d/playify-autodeploy; then cp -a /etc/cron.d/playify-autodeploy "$backup/autodeploy"; fi
if test -e /var/www/html/admin; then cp -a /var/www/html/admin "$backup/admin"; fi
if test -f /etc/systemd/system/playify-api.service; then cp -a /etc/systemd/system/playify-api.service "$backup/service"; fi
previous=$(readlink -f /opt/playify/current || true)
rollback() {
  trap - ERR
  systemctl stop playify-api.service || true
  cp "$backup/nginx.conf" /etc/nginx/sites-enabled/playify
  if test -L /var/www/html/admin; then unlink /var/www/html/admin; fi
  if test -e "$backup/previous-admin"; then mv "$backup/previous-admin" /var/www/html/admin; fi
  if test -f "$backup/autodeploy"; then cp "$backup/autodeploy" /etc/cron.d/playify-autodeploy; fi
  if test -n "$previous" && test -d "$previous"; then ln -sfn "$previous" /opt/playify/current; fi
  if test -f "$backup/service"; then cp "$backup/service" /etc/systemd/system/playify-api.service; systemctl daemon-reload; systemctl start playify-api.service; else /usr/bin/pm2 restart playify-api; fi
  nginx -t && systemctl reload nginx
  echo "Deployment failed; previous API/proxy restored. Backup: $backup"
}
trap rollback ERR

getent passwd playify-api >/dev/null || useradd --system --home /var/lib/playify-api --shell /usr/sbin/nologin playify-api
install -d -m 755 "$release/api" "$release/admin" /opt/playify/runtime
cp -a "$stage/vps/api/src" "$release/api/"
cp "$stage/vps/api/package.json" "$release/api/"
cp -aL "$stage/vps/api/node_modules" "$release/api/"
cp -a "$stage/admin/dist/." "$release/admin/"
install -o root -g playify-api -m 640 /var/playify/app/vps/api/.env "$release/api/.env"
install -o root -g root -m 755 /home/david/.bun/bin/bun /opt/playify/runtime/bun
ln -sfn "$release" /opt/playify/current

cat > /etc/systemd/system/playify-api.service <<'SERVICE'
[Unit]
Description=Playify API
After=network-online.target postgresql.service
Wants=network-online.target
[Service]
Type=simple
User=playify-api
Group=playify-api
WorkingDirectory=/opt/playify/current/api
ExecStart=/opt/playify/runtime/bun run src/index.ts
Environment=NODE_ENV=production HOST=127.0.0.1 PORT=3000
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
StateDirectory=playify-api
UMask=0077
[Install]
WantedBy=multi-user.target
SERVICE

# Immutable release replaces the old automatic git-pull + root-PM2 restart job.
if test -f /etc/cron.d/playify-autodeploy; then mv /etc/cron.d/playify-autodeploy "$backup/disabled-autodeploy"; fi
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/nginx/sites-enabled/playify')
s=p.read_text()
marker='    client_max_body_size 110M;'
assert marker in s, 'Nginx configuration changed; inspect before deploying'
routes='''
    location = /admin { return 308 /admin/; }
    location ^~ /admin/ {
        root /var/www/html;
        try_files $uri $uri/ /admin/index.html;
        add_header Cache-Control "no-cache";
    }
    location = /app/playify.apk { return 302 /downloads/playify.apk; }
    location ^~ /storage/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }
    location = /v1/mpesa/callback {
        access_log off;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header X-Real-IP $remote_addr;
    }
'''
assert 'location ^~ /admin/' not in s, 'Admin routing already installed; inspect before redeploying'
p.write_text(s.replace(marker,marker+'\n'+routes))
PY
if test -e /var/www/html/admin; then mv /var/www/html/admin "$backup/previous-admin"; fi
ln -s "$release/admin" /var/www/html/admin
nginx -t
/usr/bin/pm2 stop playify-api
systemctl daemon-reload
systemctl enable --now playify-api.service
for attempt in {1..15}; do
  if curl --fail --silent http://127.0.0.1:3000/health > /dev/null; then break; fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:3000/health > /dev/null
systemctl reload nginx

# Daily database dumps, retained locally for 14 days. Offsite backups remain a separate task.
install -d -m 700 /var/backups/playify
cat > /usr/local/sbin/playify-backup <<'BACKUP'
#!/usr/bin/env bash
set -euo pipefail
umask 077
backup_dir=/var/backups/playify
target="$backup_dir/playify-$(date -u +%Y%m%dT%H%M%SZ).dump"
runuser -u postgres -- pg_dump -Fc playify > "$target.tmp"
pg_restore --list "$target.tmp" > /dev/null
mv "$target.tmp" "$target"
find "$backup_dir" -maxdepth 1 -type f -name 'playify-*.dump' -mtime +14 -delete
BACKUP
chmod 750 /usr/local/sbin/playify-backup
printf '0 2 * * * root /usr/local/sbin/playify-backup\n' > /etc/cron.d/playify-backup
/usr/local/sbin/playify-backup
trap - ERR
printf 'Release: %s\nBackup: %s\nStatus: installed\n' "$release" "$backup" | tee "$stage/deployment-result.txt"
chmod 644 "$stage/deployment-result.txt"
echo 'Playify deployment complete.'
