#!/usr/bin/env bash
# =============================================================================
# Playify — Full Data Migration: Supabase → VPS PostgreSQL
# Runs ON the VPS server where Supabase API is reachable
# Usage: bash vps/migrate/migrate.sh
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
hdr()  { echo -e "\n${YELLOW}══ $1 ══${NC}"; }

# ── Config ────────────────────────────────────────────────────────────────────
ENV_FILE="/var/playify/app/vps/api/.env"
source "$ENV_FILE" 2>/dev/null || true

SUPABASE_URL="${SUPABASE_URL:-https://fffqjbrethogesgghjsn.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
DB_URL="${DATABASE_URL:-}"

if [ -z "$DB_URL" ]; then fail "DATABASE_URL not set in $ENV_FILE"; fi
if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ] && [ -z "$SUPABASE_ANON_KEY" ]; then
  fail "SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY required"
fi

# Use service role key if available (bypasses RLS for full data access)
SB_KEY="${SUPABASE_SERVICE_ROLE_KEY:-$SUPABASE_ANON_KEY}"

EXPORT_DIR="/var/playify/migration/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EXPORT_DIR"
echo "Export directory: $EXPORT_DIR"

# ── Fetch function ─────────────────────────────────────────────────────────────
fetch_table() {
  local table="$1"
  local file="$EXPORT_DIR/${table}.json"
  local url="${SUPABASE_URL}/rest/v1/${table}?select=*&limit=10000"

  echo -n "  Fetching $table... "
  local response
  response=$(curl -sf "$url" \
    -H "apikey: $SB_KEY" \
    -H "Authorization: Bearer $SB_KEY" \
    -H "Accept: application/json" \
    -H "Prefer: count=exact" 2>/dev/null || echo "[]")

  if echo "$response" | grep -q '"error"'; then
    echo "⚠️  error: $(echo "$response" | grep -o '"message":"[^"]*"' | head -1)"
    echo "[]" > "$file"
    return
  fi

  echo "$response" > "$file"
  local count
  count=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo "?")
  echo "$count rows"
}

# ── Paginated fetch for large tables ─────────────────────────────────────────
fetch_table_paginated() {
  local table="$1"
  local file="$EXPORT_DIR/${table}.json"
  local offset=0
  local limit=1000
  local all="[]"

  echo -n "  Fetching $table (paginated)... "
  while true; do
    local url="${SUPABASE_URL}/rest/v1/${table}?select=*&limit=${limit}&offset=${offset}"
    local chunk
    chunk=$(curl -sf "$url" \
      -H "apikey: $SB_KEY" \
      -H "Authorization: Bearer $SB_KEY" \
      -H "Accept: application/json" 2>/dev/null || echo "[]")

    local chunk_len
    chunk_len=$(echo "$chunk" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)

    if [ "$chunk_len" -eq 0 ]; then break; fi

    all=$(echo "$all $chunk" | python3 -c "
import sys,json
parts = sys.stdin.read().split()
# Merge two JSON arrays
combined = []
for p in ['$all', '$chunk']:
    try:
        d = json.loads(p)
        if isinstance(d, list): combined.extend(d)
    except: pass
print(json.dumps(combined))
" 2>/dev/null || echo "$all")

    offset=$((offset + limit))
    echo -n "."
    if [ "$chunk_len" -lt "$limit" ]; then break; fi
  done

  echo "$all" > "$file"
  local total
  total=$(echo "$all" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "?")
  echo " $total rows total"
}

# =============================================================================
# SECTION 1 — EXPORT FROM SUPABASE
# =============================================================================
hdr "EXPORTING FROM SUPABASE"

# Test connection first
echo -n "Testing Supabase connection... "
TEST=$(curl -sf "${SUPABASE_URL}/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: $SB_KEY" \
  -H "Authorization: Bearer $SB_KEY" 2>/dev/null || echo "FAILED")
if echo "$TEST" | grep -q "FAILED\|error\|Error"; then
  fail "Cannot reach Supabase. Check SUPABASE_URL and keys in $ENV_FILE"
fi
ok "Supabase reachable"

# Export all tables
fetch_table_paginated "User"
fetch_table_paginated "profiles"
fetch_table_paginated "Post"
fetch_table_paginated "Follow"
fetch_table_paginated "PostLike"
fetch_table_paginated "Comment"
fetch_table_paginated "CommentLike"
fetch_table_paginated "Message"
fetch_table_paginated "Notification"
fetch_table_paginated "Community"
fetch_table_paginated "CommunityMember"
fetch_table_paginated "League"
fetch_table_paginated "Team"
fetch_table_paginated "Player"
fetch_table_paginated "Coach"
fetch_table_paginated "Match"
fetch_table_paginated "Sport"
fetch_table_paginated "NewsItem"
fetch_table_paginated "Poll"
fetch_table_paginated "PollVote"
fetch_table_paginated "Prediction"
fetch_table_paginated "ShopOrder"
fetch_table_paginated "ClaimRequest"
fetch_table_paginated "UserFavorite"
fetch_table_paginated "UserSport"
fetch_table_paginated "entity_follows"
fetch_table_paginated "device_tokens"
fetch_table_paginated "fans"
fetch_table "Role"
fetch_table "Sport"

ok "Export complete → $EXPORT_DIR"
ls -lh "$EXPORT_DIR" | awk '{print "  "$5, $9}'

# =============================================================================
# SECTION 2 — IMPORT INTO VPS POSTGRESQL
# =============================================================================
hdr "IMPORTING INTO VPS POSTGRESQL"

# Python import script
python3 << PYEOF
import json, os, sys, subprocess, re
from pathlib import Path

export_dir = "$EXPORT_DIR"
db_url     = "$DB_URL"

# Use psycopg2 if available, else pg directly via psql
try:
    import psycopg2
    import psycopg2.extras
    USE_PSYCOPG2 = True
    print("Using psycopg2 driver")
except ImportError:
    USE_PSYCOPG2 = False
    print("psycopg2 not available — using psql binary")

def run_psql(sql: str):
    result = subprocess.run(
        ["psql", db_url, "-c", sql],
        capture_output=True, text=True
    )
    if result.returncode != 0 and "ERROR" in result.stderr:
        print(f"  SQL error: {result.stderr[:200]}")
    return result.returncode == 0

def load(filename: str) -> list:
    path = Path(export_dir) / filename
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, list) else []
    except:
        return []

def escape_val(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, (dict, list)):
        s = json.dumps(v).replace("'", "''")
        return f"'{s}'::jsonb"
    s = str(v).replace("'", "''")
    return f"'{s}'"

def upsert(table: str, rows: list, pk: str | list, schema: str = "public"):
    if not rows:
        print(f"  {table}: 0 rows (skipped)")
        return
    
    pk_cols = [pk] if isinstance(pk, str) else pk
    total = 0
    errors = 0
    
    for row in rows:
        if not row:
            continue
        cols = list(row.keys())
        vals = [escape_val(row[c]) for c in cols]
        
        # Build conflict clause
        pk_str = ", ".join(f'"{c}"' for c in pk_cols)
        
        # Build update set (exclude pk columns)
        update_cols = [c for c in cols if c not in pk_cols]
        if update_cols:
            update_str = ", ".join(f'"{c}"=EXCLUDED."{c}"' for c in update_cols)
            conflict = f"ON CONFLICT ({pk_str}) DO UPDATE SET {update_str}"
        else:
            conflict = f"ON CONFLICT ({pk_str}) DO NOTHING"
        
        col_str = ", ".join(f'"{c}"' for c in cols)
        val_str = ", ".join(vals)
        sql = f'INSERT INTO {schema}."{table}" ({col_str}) VALUES ({val_str}) {conflict};'
        
        if run_psql(sql):
            total += 1
        else:
            errors += 1
    
    status = "✅" if errors == 0 else "⚠️ "
    print(f"  {status} {table}: {total} imported, {errors} errors")

# ── Import order matters (FK dependencies) ────────────────────────────────────

print("\nImporting reference data...")
upsert("Role",   load("Role.json"),   "id")
upsert("Sport",  load("Sport.json"),  "id")

print("\nImporting users and profiles...")
# User table first (no FK dependencies)
upsert("User",     load("User.json"),     "id")
upsert("profiles", load("profiles.json"), "id", schema="public")

print("\nImporting sports data...")
upsert("League",  load("League.json"),  "id")
upsert("Team",    load("Team.json"),    "id")
upsert("Player",  load("Player.json"),  "id")
upsert("Coach",   load("Coach.json"),   "id")
upsert("Match",   load("Match.json"),   "id")

print("\nImporting content...")
upsert("NewsItem",  load("NewsItem.json"),  "id")
upsert("Community", load("Community.json"), "id")
upsert("Post",      load("Post.json"),      "id")
upsert("Poll",      load("Poll.json"),      "id")
upsert("Prediction",load("Prediction.json"),"id")

print("\nImporting social graph...")
upsert("Follow",          load("Follow.json"),          ["followerId","followingId"])
upsert("PostLike",        load("PostLike.json"),        ["postId","userId"])
upsert("PostShare",       load("PostShare.json"),       ["postId","userId"])
upsert("Comment",         load("Comment.json"),         "id")
upsert("CommentLike",     load("CommentLike.json"),     ["commentId","userId"])
upsert("PollVote",        load("PollVote.json"),        ["pollId","userId"])
upsert("CommunityMember", load("CommunityMember.json"), ["communityId","userId"])
upsert("UserFavorite",    load("UserFavorite.json"),    "id")
upsert("UserSport",       load("UserSport.json"),       "id")

print("\nImporting messaging and notifications...")
upsert("Message",      load("Message.json"),      "id")
upsert("Notification", load("Notification.json"), "id")

print("\nImporting commerce...")
upsert("ShopOrder",    load("ShopOrder.json"),    "id")
upsert("ClaimRequest", load("ClaimRequest.json"), "id")

print("\nImporting device tokens and entity follows...")
upsert("device_tokens",  load("device_tokens.json"),  ["user_id","token"], schema="public")
upsert("entity_follows", load("entity_follows.json"), ["follower_id","entity_type","entity_id"], schema="public")
upsert("fans",           load("fans.json"),            ["fan_id","target_id"], schema="public")

print("\nDone importing!")
PYEOF

# =============================================================================
# SECTION 3 — VERIFY
# =============================================================================
hdr "VERIFICATION"

psql "$DB_URL" << 'SQL'
SELECT
  'User'         as table_name, COUNT(*) as rows FROM public."User"
UNION ALL SELECT 'profiles',    COUNT(*) FROM public.profiles
UNION ALL SELECT 'Post',        COUNT(*) FROM public."Post"
UNION ALL SELECT 'Follow',      COUNT(*) FROM public."Follow"
UNION ALL SELECT 'Team',        COUNT(*) FROM public."Team"
UNION ALL SELECT 'Player',      COUNT(*) FROM public."Player"
UNION ALL SELECT 'Match',       COUNT(*) FROM public."Match"
UNION ALL SELECT 'Community',   COUNT(*) FROM public."Community"
UNION ALL SELECT 'Message',     COUNT(*) FROM public."Message"
UNION ALL SELECT 'Notification',COUNT(*) FROM public."Notification"
ORDER BY rows DESC;
SQL

ok "Migration complete!"
echo ""
echo "Export files saved at: $EXPORT_DIR"
echo "Keep these as backup before removing Supabase dependency."
