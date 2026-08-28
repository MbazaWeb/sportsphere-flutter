#!/usr/bin/env bash
# =============================================================================
# Playify — Full Data Migration: Supabase → VPS PostgreSQL
# Fixed: service role key, column mismatches, FK order, empty exports
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
hdr()  { echo -e "\n${YELLOW}══ $1 ══${NC}"; }

# ── Config ────────────────────────────────────────────────────────────────────
ENV_FILE="/var/playify/app/vps/api/.env"

# Parse .env manually — source can miss export
while IFS='=' read -r key val; do
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  val="${val%%#*}"        # strip inline comments
  val="${val%"${val##*[![:space:]]}"}"  # strip trailing whitespace
  export "$key=$val"
done < "$ENV_FILE"

SUPABASE_URL="${SUPABASE_URL:-https://fffqjbrethogesgghjsn.supabase.co}"
SB_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SUPABASE_ANON_KEY:-}}"
DB_URL="${DATABASE_URL:-}"

echo "Using Supabase URL: $SUPABASE_URL"
echo "Service role key: ${SB_KEY:0:20}..."
echo "DB URL: ${DB_URL:0:30}..."

if [ -z "$DB_URL" ]; then fail "DATABASE_URL not set"; fi
if [ -z "$SB_KEY" ]; then fail "SUPABASE_SERVICE_ROLE_KEY not set"; fi

EXPORT_DIR="/var/playify/migration/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EXPORT_DIR"
echo "Export dir: $EXPORT_DIR"

# ── Test connection ────────────────────────────────────────────────────────────
hdr "TESTING CONNECTIONS"
echo -n "Supabase... "
TEST=$(curl -sf "${SUPABASE_URL}/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: $SB_KEY" \
  -H "Authorization: Bearer $SB_KEY" \
  -H "Accept: application/json" 2>/dev/null)
if echo "$TEST" | grep -q "error\|Error\|FAILED"; then
  fail "Supabase unreachable: $TEST"
fi
echo "ok ($(echo "$TEST" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "?") profile rows visible)"

echo -n "PostgreSQL... "
psql "$DB_URL" -c "SELECT 1" -q 2>/dev/null && echo "ok" || fail "PostgreSQL unreachable"

# ── Fetch with pagination ──────────────────────────────────────────────────────
fetch() {
  local table="$1" file="$EXPORT_DIR/${table}.json"
  local all="[]" offset=0 limit=1000 total=0

  echo -n "  $table... "
  while true; do
    local url="${SUPABASE_URL}/rest/v1/${table}?select=*&limit=${limit}&offset=${offset}&order=id"
    local chunk
    chunk=$(curl -sf "$url" \
      -H "apikey: $SB_KEY" \
      -H "Authorization: Bearer $SB_KEY" \
      -H "Accept: application/json" 2>/dev/null || echo "[]")

    # Check for error
    if echo "$chunk" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if isinstance(d,list) else 1)" 2>/dev/null; then
      local n
      n=$(echo "$chunk" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
      if [ "$n" -eq 0 ]; then break; fi
      total=$((total + n))
      # Merge chunks
      all=$(python3 -c "
import json,sys
a = json.loads('''$all''')
b = json.loads(sys.stdin.read())
a.extend(b)
print(json.dumps(a))
" <<< "$chunk" 2>/dev/null || echo "$all")
      offset=$((offset + limit))
      echo -n "."
      [ "$n" -lt "$limit" ] && break
    else
      echo "  (error or empty — skipping)"
      break
    fi
  done

  echo "$all" > "$file"
  echo " $total rows"
}

# =============================================================================
# SECTION 1 — EXPORT
# =============================================================================
hdr "EXPORTING FROM SUPABASE (service role)"

fetch "User"
fetch "profiles"
fetch "Post"
fetch "Follow"
fetch "PostLike"
fetch "PostShare"
fetch "Comment"
fetch "CommentLike"
fetch "Message"
fetch "Notification"
fetch "Community"
fetch "CommunityMember"
fetch "League"
fetch "Team"
fetch "Player"
fetch "Coach"
fetch "Match"
fetch "Sport"
fetch "NewsItem"
fetch "Poll"
fetch "PollVote"
fetch "Prediction"
fetch "ShopOrder"
fetch "ClaimRequest"
fetch "UserFavorite"
fetch "UserSport"
fetch "entity_follows"
fetch "device_tokens"
fetch "fans"
fetch "Role"

ok "Export complete"
echo "File sizes:"
ls -lh "$EXPORT_DIR" | awk 'NR>1{printf "  %6s  %s\n", $5, $9}'

# =============================================================================
# SECTION 2 — IMPORT
# =============================================================================
hdr "IMPORTING INTO VPS POSTGRESQL"

python3 - "$EXPORT_DIR" "$DB_URL" << 'PYEOF'
import json, sys, subprocess, re
from pathlib import Path

export_dir = sys.argv[1]
db_url     = sys.argv[2]

def psql(sql: str) -> bool:
    r = subprocess.run(["psql", db_url, "-c", sql, "-q"],
                       capture_output=True, text=True)
    if r.returncode != 0 and ("ERROR" in r.stderr or "ERROR" in r.stdout):
        msg = (r.stderr + r.stdout)[:300].replace('\n',' ')
        print(f"    SQL ERR: {msg}")
        return False
    return True

def load(name: str) -> list:
    p = Path(export_dir) / name
    if not p.exists(): return []
    try:
        d = json.loads(p.read_text())
        return d if isinstance(d, list) else []
    except: return []

def esc(v):
    if v is None: return "NULL"
    if isinstance(v, bool): return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)): return str(v)
    if isinstance(v, (dict, list)):
        return "'" + json.dumps(v, ensure_ascii=False).replace("'","''") + "'::jsonb"
    return "'" + str(v).replace("'","''") + "'"

def upsert(table: str, rows: list, pk, skip_cols: list=None, schema="public"):
    if not rows:
        print(f"  {table}: 0 rows (empty export)")
        return
    skip_cols = skip_cols or []
    pk_cols   = [pk] if isinstance(pk, str) else list(pk)
    ok_count = err_count = 0

    for row in rows:
        if not row: continue
        # Filter out columns that don't exist in VPS schema
        cols = [c for c in row.keys() if c not in skip_cols]
        if not cols: continue
        vals = [esc(row[c]) for c in cols]
        pk_str  = ", ".join(f'"{c}"' for c in pk_cols)
        upd     = [c for c in cols if c not in pk_cols]
        conflict = (f"ON CONFLICT ({pk_str}) DO UPDATE SET " +
                    ", ".join(f'"{c}"=EXCLUDED."{c}"' for c in upd)) if upd else \
                   f"ON CONFLICT ({pk_str}) DO NOTHING"
        sql = (f'INSERT INTO {schema}."{table}" (' +
               ", ".join(f'"{c}"' for c in cols) +
               ") VALUES (" + ", ".join(vals) + f") {conflict};")
        if psql(sql): ok_count += 1
        else:         err_count += 1

    sym = "✅" if err_count == 0 else "⚠️ "
    print(f"  {sym} {table}: {ok_count} ok, {err_count} errors")

# ── Reference data ────────────────────────────────────────────────────────────
print("\nReference data...")
upsert("Role",  load("Role.json"),  "id")

# Sport — skip columns not in VPS schema
sport_skip = ["sport_slug","parent_sport_slug","parentSportSlug","sportSlug"]
upsert("Sport", load("Sport.json"), "id", skip_cols=sport_skip)

# ── Users ─────────────────────────────────────────────────────────────────────
print("\nUsers...")
# User — skip columns that may not exist
user_skip = ["passwordHash"]  # will be null for migrated users
upsert("User",     load("User.json"),     "id",  skip_cols=user_skip)

# profiles — skip id casting issue (it's uuid in profiles)
profiles_data = load("profiles.json")
if profiles_data:
    ok_count = err_count = 0
    for row in profiles_data:
        if not row: continue
        cols = list(row.keys())
        vals_list = []
        col_list  = []
        for c in cols:
            v = row[c]
            if c == 'id':
                col_list.append('"id"')
                vals_list.append(f"'{v}'::uuid")
            else:
                col_list.append(f'"{c}"')
                vals_list.append(esc(v))
        sql = (f'INSERT INTO public.profiles ({", ".join(col_list)}) VALUES ({", ".join(vals_list)}) '
               f'ON CONFLICT (id) DO UPDATE SET ' +
               ", ".join(f'"{c}"=EXCLUDED."{c}"' for c in cols if c != 'id') + ';')
        if psql(sql): ok_count += 1
        else:         err_count += 1
    sym = "✅" if err_count == 0 else "⚠️ "
    print(f"  {sym} profiles: {ok_count} ok, {err_count} errors")
else:
    print("  profiles: 0 rows")

# ── Sports data ───────────────────────────────────────────────────────────────
print("\nSports data...")
# League — skip taxonomy columns not in VPS schema
league_skip = ["competitive_level","organization_type","gender","age_category",
               "geographic_scope","sport_slug","sport_variant","competitiveLevel",
               "organizationType","ageCategory","geographicScope","sportSlug","sportVariant",
               "competitionType","competitionFormat","competitionLevel"]
upsert("League", load("League.json"), "id", skip_cols=league_skip)

# Team — skip taxonomy columns
team_skip = ["competitive_level","organization_type","gender","age_category",
             "geographic_scope","sport_slug","sport_variant","competitiveLevel",
             "organizationType","ageCategory","geographicScope","sportSlug","sportVariant"]
upsert("Team",   load("Team.json"),   "id", skip_cols=team_skip)
upsert("Player", load("Player.json"), "id", skip_cols=["player_type","career_level","sport_slug","playerType","careerLevel","sportSlug"])
upsert("Coach",  load("Coach.json"),  "id")
upsert("Match",  load("Match.json"),  "id")

# ── Content ───────────────────────────────────────────────────────────────────
print("\nContent...")
upsert("NewsItem",  load("NewsItem.json"),  "id")
upsert("Community", load("Community.json"), "id")
upsert("Post",      load("Post.json"),      "id")

# Poll — only insert if post exists
polls = load("Poll.json")
valid_polls = []
if polls:
    # Get existing post IDs
    r = subprocess.run(["psql", db_url, "-t", "-c", 'SELECT id FROM public."Post"'],
                       capture_output=True, text=True)
    post_ids = set(r.stdout.split())
    valid_polls = [p for p in polls if p.get("postId","") in post_ids or p.get("post_id","") in post_ids]
    print(f"  Poll: {len(valid_polls)}/{len(polls)} have matching posts")
upsert("Poll",       valid_polls,              "id")
upsert("Prediction", load("Prediction.json"),  "id")

# ── Social graph ──────────────────────────────────────────────────────────────
print("\nSocial graph...")
upsert("Follow",          load("Follow.json"),          ["followerId","followingId"])
upsert("PostLike",        load("PostLike.json"),        ["postId","userId"])
upsert("PostShare",       load("PostShare.json"),       ["postId","userId"])

# Comment — only if post exists
comments = load("Comment.json")
if comments:
    r = subprocess.run(["psql", db_url, "-t", "-c", 'SELECT id FROM public."Post"'],
                       capture_output=True, text=True)
    post_ids = set(r.stdout.split())
    comments = [c for c in comments if c.get("postId","") in post_ids]
upsert("Comment",         comments,                     "id")
upsert("CommentLike",     load("CommentLike.json"),     ["commentId","userId"])

# PollVote — fix column name (Supabase uses optionIdx, VPS uses optionIndex)
poll_votes = load("PollVote.json")
fixed_votes = []
for v in poll_votes:
    if "optionIdx" in v and "optionIndex" not in v:
        v["optionIndex"] = v.pop("optionIdx")
    fixed_votes.append(v)
upsert("PollVote",        fixed_votes,                  ["pollId","userId"])
upsert("CommunityMember", load("CommunityMember.json"), ["communityId","userId"])
upsert("UserFavorite",    load("UserFavorite.json"),    "id")
upsert("UserSport",       load("UserSport.json"),       "id")

# ── Messages & notifications ──────────────────────────────────────────────────
print("\nMessaging & notifications...")
upsert("Message",      load("Message.json"),      "id")
upsert("Notification", load("Notification.json"), "id")

# ── Commerce ──────────────────────────────────────────────────────────────────
print("\nCommerce...")
upsert("ShopOrder",    load("ShopOrder.json"),    "id")
upsert("ClaimRequest", load("ClaimRequest.json"), "id")

# ── Device tokens & entity follows ───────────────────────────────────────────
print("\nTokens & entity follows...")
upsert("device_tokens",  load("device_tokens.json"),  ["user_id","token"],                          schema="public")
upsert("entity_follows", load("entity_follows.json"), ["follower_id","entity_type","entity_id"],    schema="public")
upsert("fans",           load("fans.json"),            ["fan_id","target_id"],                       schema="public")

print("\n✅ Import complete!")
PYEOF

# =============================================================================
# SECTION 3 — VERIFY
# =============================================================================
hdr "VERIFICATION"

psql "$DB_URL" -c "
SELECT table_name, rows FROM (
  SELECT 'User'          as table_name, COUNT(*) as rows FROM public.\"User\"
  UNION ALL SELECT 'profiles',    COUNT(*) FROM public.profiles
  UNION ALL SELECT 'Post',        COUNT(*) FROM public.\"Post\"
  UNION ALL SELECT 'Follow',      COUNT(*) FROM public.\"Follow\"
  UNION ALL SELECT 'Comment',     COUNT(*) FROM public.\"Comment\"
  UNION ALL SELECT 'Team',        COUNT(*) FROM public.\"Team\"
  UNION ALL SELECT 'Player',      COUNT(*) FROM public.\"Player\"
  UNION ALL SELECT 'League',      COUNT(*) FROM public.\"League\"
  UNION ALL SELECT 'Match',       COUNT(*) FROM public.\"Match\"
  UNION ALL SELECT 'Community',   COUNT(*) FROM public.\"Community\"
  UNION ALL SELECT 'Message',     COUNT(*) FROM public.\"Message\"
  UNION ALL SELECT 'Notification',COUNT(*) FROM public.\"Notification\"
  UNION ALL SELECT 'Sport',       COUNT(*) FROM public.\"Sport\"
  UNION ALL SELECT 'NewsItem',    COUNT(*) FROM public.\"NewsItem\"
  UNION ALL SELECT 'device_tokens',COUNT(*) FROM public.device_tokens
) t ORDER BY rows DESC;"

ok "Migration complete! Exports at $EXPORT_DIR"
