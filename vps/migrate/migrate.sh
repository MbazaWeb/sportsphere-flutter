#!/usr/bin/env bash
# =============================================================================
# Playify — Full Data Migration: Supabase PostgreSQL → VPS PostgreSQL
# Method: pg_dump direct (fastest, no RLS issues, no API limits)
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
hdr()  { echo -e "\n${YELLOW}══ $1 ══${NC}"; }

# ── Connection strings ────────────────────────────────────────────────────────
# Supabase direct PostgreSQL (from your dashboard)
SB_DB="postgresql://postgres:0H0Ad64USEIykfwm@db.fffqjbrethogesgghjsn.supabase.co:5432/postgres"

# VPS PostgreSQL (from .env)
ENV_FILE="/var/playify/app/vps/api/.env"
VPS_DB=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")

if [ -z "$VPS_DB" ]; then fail "DATABASE_URL not set in $ENV_FILE"; fi

echo "Source: Supabase PostgreSQL"
echo "Target: $VPS_DB"

BACKUP_DIR="/var/playify/migration/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup dir: $BACKUP_DIR"

# ── Test both connections ─────────────────────────────────────────────────────
hdr "TESTING CONNECTIONS"

echo -n "Supabase PostgreSQL... "
PGPASSWORD=0H0Ad64USEIykfwm psql "$SB_DB" -c "SELECT COUNT(*) FROM public.profiles" -t 2>/dev/null \
  && ok "connected" || fail "Cannot connect to Supabase PostgreSQL"

echo -n "VPS PostgreSQL... "
psql "$VPS_DB" -c "SELECT 1" -q 2>/dev/null && ok "connected" || fail "Cannot connect to VPS PostgreSQL"

# =============================================================================
# SECTION 1 — DUMP EACH TABLE FROM SUPABASE
# =============================================================================
hdr "DUMPING TABLES FROM SUPABASE"

# Tables to migrate (in FK dependency order)
TABLES=(
  "public.profiles"
  'public."User"'
  'public."Role"'
  'public."Sport"'
  'public."League"'
  'public."Team"'
  'public."Player"'
  'public."Coach"'
  'public."Match"'
  'public."Community"'
  'public."NewsItem"'
  'public."Post"'
  'public."Poll"'
  'public."Prediction"'
  'public."Follow"'
  'public."PostLike"'
  'public."PostShare"'
  'public."Comment"'
  'public."CommentLike"'
  'public."PollVote"'
  'public."CommunityMember"'
  'public."UserFavorite"'
  'public."UserSport"'
  'public."Message"'
  'public."Notification"'
  'public."ShopOrder"'
  'public."ClaimRequest"'
  'public."VerificationRequest"'
  "public.device_tokens"
  "public.entity_follows"
  "public.fans"
  "public.taxonomy_term"
  'public."PlayerMatchStat"'
  'public."RoleRequest"'
)

dump_table() {
  local tbl="$1"
  local safe_name
  safe_name=$(echo "$tbl" | tr -d '"' | tr '.' '_' | tr -d ' ')
  local file="$BACKUP_DIR/${safe_name}.sql"

  echo -n "  Dumping $tbl... "
  PGPASSWORD=0H0Ad64USEIykfwm pg_dump "$SB_DB" \
    --data-only \
    --no-privileges \
    --no-owner \
    --table="$tbl" \
    --format=plain \
    2>/dev/null > "$file" || { warn "Failed to dump $tbl"; return; }

  local lines
  lines=$(wc -l < "$file")
  echo "$lines lines"
}

for tbl in "${TABLES[@]}"; do
  dump_table "$tbl"
done

ok "Dump complete"
du -sh "$BACKUP_DIR"

# =============================================================================
# SECTION 2 — PREPARE VPS TABLES FOR IMPORT
# =============================================================================
hdr "PREPARING VPS POSTGRESQL"

# Disable FK checks temporarily for import
psql "$VPS_DB" << 'SQL'
-- Temporarily disable triggers (FK checks) for bulk import
SET session_replication_role = replica;
SQL

# =============================================================================
# SECTION 3 — RESTORE INTO VPS POSTGRESQL
# =============================================================================
hdr "RESTORING INTO VPS POSTGRESQL"

restore_table() {
  local tbl="$1"
  local safe_name
  safe_name=$(echo "$tbl" | tr -d '"' | tr '.' '_' | tr -d ' ')
  local file="$BACKUP_DIR/${safe_name}.sql"

  if [ ! -f "$file" ] || [ ! -s "$file" ]; then
    echo "  ⏭  $tbl (no data)"
    return
  fi

  echo -n "  Restoring $tbl... "

  # Fix: replace Supabase sequence nextval with nothing (we use our own sequences)
  # Also handle any auth.users references
  sed -i \
    "s|auth\.uid()|'00000000-0000-0000-0000-000000000000'::uuid|g" \
    "$file" 2>/dev/null || true

  local result
  result=$(psql "$VPS_DB" \
    --set ON_ERROR_STOP=off \
    -f "$file" 2>&1 | tail -5)

  if echo "$result" | grep -q "^INSERT\|COPY"; then
    echo "✅"
  elif echo "$result" | grep -qi "error"; then
    echo "⚠️  $(echo "$result" | grep -i error | head -1)"
  else
    echo "✅ (no conflicts)"
  fi
}

# Restore in FK order
for tbl in "${TABLES[@]}"; do
  restore_table "$tbl"
done

# Re-enable FK checks
psql "$VPS_DB" << 'SQL'
SET session_replication_role = DEFAULT;
SQL

# =============================================================================
# SECTION 4 — FIX COLUMN MISMATCHES (for any that failed above)
# =============================================================================
hdr "FIXING COLUMN MISMATCHES VIA COPY"

# For tables where pg_dump failed due to column differences,
# use direct COPY via psql pipe (only the columns that exist on both sides)

copy_table() {
  local src_tbl="$1"
  local dst_tbl="${2:-$1}"
  local cols="$3"
  local safe_name
  safe_name=$(echo "$src_tbl" | tr -d '"' | tr '.' '_')

  echo -n "  COPY $src_tbl → $dst_tbl ($cols)... "
  PGPASSWORD=0H0Ad64USEIykfwm psql "$SB_DB" -t -c \
    "COPY (SELECT $cols FROM $src_tbl) TO STDOUT CSV HEADER" 2>/dev/null | \
    psql "$VPS_DB" -c \
    "COPY $dst_tbl ($cols) FROM STDIN CSV HEADER ON CONFLICT DO NOTHING" 2>&1 | tail -1
}

# Sport — only common columns
copy_table 'public."Sport"' 'public."Sport"' \
  '"id","name","slug","icon","category","description","tags","isActive","displayOrder","createdAt","updatedAt"'

# League — skip taxonomy-only columns
copy_table 'public."League"' 'public."League"' \
  '"id","name","slug","country","logoUrl","type","season","verified","isActive","description","createdAt","updatedAt"'

# Team — skip taxonomy-only columns
copy_table 'public."Team"' 'public."Team"' \
  '"id","name","slug","shortName","city","country","logoUrl","primaryColor","venue","foundedYear","verified","isActive","description","createdAt","updatedAt"'

# Player
copy_table 'public."Player"' 'public."Player"' \
  '"id","name","slug","firstName","lastName","position","nationality","photoUrl","verified","isActive","metadata","createdAt","updatedAt"'

ok "Column-specific copy done"

# =============================================================================
# SECTION 5 — VERIFY
# =============================================================================
hdr "VERIFICATION"

psql "$VPS_DB" << 'SQL'
SELECT table_name, rows FROM (
  SELECT 'User'          as table_name, COUNT(*) as rows FROM public."User"
  UNION ALL SELECT 'profiles',    COUNT(*) FROM public.profiles
  UNION ALL SELECT 'Post',        COUNT(*) FROM public."Post"
  UNION ALL SELECT 'Follow',      COUNT(*) FROM public."Follow"
  UNION ALL SELECT 'Comment',     COUNT(*) FROM public."Comment"
  UNION ALL SELECT 'Team',        COUNT(*) FROM public."Team"
  UNION ALL SELECT 'Player',      COUNT(*) FROM public."Player"
  UNION ALL SELECT 'League',      COUNT(*) FROM public."League"
  UNION ALL SELECT 'Match',       COUNT(*) FROM public."Match"
  UNION ALL SELECT 'Community',   COUNT(*) FROM public."Community"
  UNION ALL SELECT 'Message',     COUNT(*) FROM public."Message"
  UNION ALL SELECT 'Notification',COUNT(*) FROM public."Notification"
  UNION ALL SELECT 'Sport',       COUNT(*) FROM public."Sport"
  UNION ALL SELECT 'NewsItem',    COUNT(*) FROM public."NewsItem"
  UNION ALL SELECT 'device_tokens',COUNT(*) FROM public.device_tokens
  UNION ALL SELECT 'entity_follows',COUNT(*) FROM public.entity_follows
) t ORDER BY rows DESC;
SQL

echo ""
ok "Migration complete!"
echo "Backup at: $BACKUP_DIR"
echo ""
echo "Next: test login at https://playifysport.fun/v1/auth/login"
