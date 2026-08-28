#!/usr/bin/env bash
# =============================================================================
# Playify — Full Data Migration: Supabase → VPS PostgreSQL
# Uses pg_dump direct connection (fastest, no RLS issues)
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
hdr()  { echo -e "\n${YELLOW}══ $1 ══${NC}"; }

SB_DB="postgresql://postgres:0H0Ad64USEIykfwm@db.fffqjbrethogesgghjsn.supabase.co:5432/postgres"
ENV_FILE="/var/playify/app/vps/api/.env"
VPS_DB=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
SCHEMA_FIX="/var/playify/app/vps/migrate/fix_schema.sql"

[ -z "$VPS_DB" ] && fail "DATABASE_URL not set in $ENV_FILE"

BACKUP_DIR="/var/playify/migration/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup dir: $BACKUP_DIR"

# ── Test connections ──────────────────────────────────────────────────────────
hdr "TESTING CONNECTIONS"
echo -n "Supabase... "
PGPASSWORD=0H0Ad64USEIykfwm psql "$SB_DB" -c "SELECT 1" -q 2>/dev/null \
  && ok "ok" || fail "Cannot connect to Supabase"
echo -n "VPS... "
psql "$VPS_DB" -c "SELECT 1" -q 2>/dev/null && ok "ok" || fail "Cannot connect to VPS"

# ── Step 1: Fix VPS schema ────────────────────────────────────────────────────
hdr "PATCHING VPS SCHEMA (add missing columns)"
psql "$VPS_DB" -f "$SCHEMA_FIX" -q 2>&1 | grep -v "^$\|NOTICE\|already exists" || true
ok "Schema patched"

# ── Step 2: Dump from Supabase using COPY TO (no superuser needed) ───────────
hdr "EXPORTING FROM SUPABASE"

dump_table() {
  local schema_tbl="$1"   # e.g.  public."User"
  local safe="$2"          # e.g.  User
  local cols="$3"          # column list or *

  local file="$BACKUP_DIR/${safe}.csv"
  echo -n "  $schema_tbl... "

  PGPASSWORD=0H0Ad64USEIykfwm psql "$SB_DB" -t -c \
    "COPY (SELECT $cols FROM $schema_tbl) TO STDOUT CSV HEADER" \
    > "$file" 2>/dev/null || { warn "dump failed"; return; }

  local lines
  lines=$(wc -l < "$file")
  echo "$lines lines"
}

# Each entry: "schema.table" "safe_name" "column_list"
dump_table 'public.profiles'           'profiles'           '*'
dump_table 'public."User"'             'User'               '"id","name","email","handle","role","avatarUrl","coverUrl","bio","location","gender","nationality","countryOfOrigin","currentCountry","dateOfBirth","followerCount","followingCount","fanCount","postCount","roleData","sportsFollowing","interests","roleProfile","preferences","privacySettings","notifPrefs","isPro","isBanned","bannedAt","bannedReason","emailVerified","registeredAt","updatedAt","lastSeenAt","coverGradient","isVerified","verificationStatus"'
dump_table 'public."Role"'             'Role'               '*'
dump_table 'public."Sport"'            'Sport'              '"id","name","slug","icon","category","description","tags","isActive","displayOrder","createdAt","updatedAt"'
dump_table 'public."League"'           'League'             '"id","name","slug","country","logoUrl","type","season","verified","isActive","description","metadata","createdAt","updatedAt"'
dump_table 'public."Team"'             'Team'               '"id","leagueId","sportId","name","slug","shortName","city","country","logoUrl","venue","foundedYear","source","verified","isActive","description","metadata","createdAt","updatedAt","accountUserId","isClaimable","competitive_level","organization_type","gender","age_category","geographic_scope","sport_slug","sport_variant","primaryColor","identity_status"'
dump_table 'public."Player"'           'Player'             '"id","teamId","leagueId","sportId","name","slug","firstName","lastName","position","nationality","photoUrl","dateOfBirth","heightCm","weightKg","shirtNumber","verified","isActive","metadata","createdAt","updatedAt","isClaimable","accountUserId","player_type","gender","age_category","career_level","sport_slug","identity_status"'
dump_table 'public."Coach"'            'Coach'              '"id","teamId","leagueId","sportId","name","slug","firstName","lastName","nationality","photoUrl","dateOfBirth","role","verified","isActive","metadata","createdAt","updatedAt"'
dump_table 'public."Match"'            'Match'              '"id","league","homeTeam","awayTeam","homeScore","awayScore","status","minute","venue","kickoffAt","events","lineups","stats","homeBadge","awayBadge","season","externalId","continent","country","createdAt","updatedAt"'
dump_table 'public."Community"'        'Community'          '"id","name","description","topic","memberCount","createdById","createdAt"'
dump_table 'public."NewsItem"'         'NewsItem'           '"id","title","slug","body","summary","imageUrl","category","tags","status","source","source_url","is_breaking","likeCount","commentCount","shareCount","viewCount","publishedAt","createdAt","updatedAt"'
dump_table 'public."Post"'             'Post'               '"id","userId","content","postType","mediaUrls","hashtags","teamTag","playerTag","communityId","sportTag","matchId","isBreaking","likeCount","commentCount","shareCount","viewCount","createdAt","updatedAt"'
dump_table 'public."Poll"'             'Poll'               '"id","postId","matchId","question","options","totalVotes","endsAt","createdAt"'
dump_table 'public."Prediction"'       'Prediction'         '"id","userId","matchId","postId","homeTeam","awayTeam","predictedHome","predictedAway","confidence","result","isCorrect","pointsEarned","createdAt","outcome"'
dump_table 'public."Follow"'           'Follow'             '"followerId","followingId","createdAt"'
dump_table 'public."PostLike"'         'PostLike'           '"postId","userId","createdAt"'
dump_table 'public."PostShare"'        'PostShare'          '"postId","userId","createdAt"'
dump_table 'public."Comment"'          'Comment'            '"id","postId","userId","content","parentId","mentionedUserIds","mediaUrls","mediaType","likeCount","createdAt"'
dump_table 'public."CommentLike"'      'CommentLike'        '"commentId","userId","createdAt"'
dump_table 'public."PollVote"'         'PollVote'           '"id","pollId","userId","optionIdx","createdAt"'
dump_table 'public."CommunityMember"'  'CommunityMember'    '"communityId","userId","role","joinedAt"'
dump_table 'public."UserFavorite"'     'UserFavorite'       '"id","userId","targetType","targetId","targetName","targetHandle","createdAt"'
dump_table 'public."UserSport"'        'UserSport'          '"id","userId","sportId","createdAt","is_primary","weight"'
dump_table 'public."Message"'          'Message'            '"id","senderId","receiverId","content","isRead","createdAt"'
dump_table 'public."Notification"'     'Notification'       '"id","userId","type","title","body","isRead","actorId","referenceId","targetId","targetType","createdAt"'
dump_table 'public."ShopOrder"'        'ShopOrder'          '"id","userId","sellerHandle","sellerName","itemId","itemName","kind","quantity","unitPriceTzs","amountTzs","status","createdAt","paymentMethod","paymentRef"'
dump_table 'public."ClaimRequest"'     'ClaimRequest'       '"id","userId","profileType","profileId","profileName","leagueId","teamId","playerId","coachId","claimEmail","claimPhone","evidenceNotes","evidenceUrls","status","reviewerId","reviewNotes","submittedAt","reviewedAt"'
dump_table 'public."VerificationRequest"' 'VerificationRequest' '"id","userId","role","roleData","roleId","roleTypeId","status","adminNotes","reviewedBy","submittedAt","reviewedAt"'
dump_table 'public.device_tokens'      'device_tokens'      '"user_id","token","platform","updated_at"'
dump_table 'public.entity_follows'     'entity_follows'     '"id","follower_id","entity_type","entity_id","account_uid","is_fan","created_at"'
dump_table 'public.fans'               'fans'               '"fan_id","target_id","created_at"'
dump_table 'public.taxonomy_term'      'taxonomy_term'      '"domain","slug","label","parent_slug","sort_order"'

# Fix PollVote column name: Supabase=optionIdx, VPS=optionIndex
if [ -f "$BACKUP_DIR/PollVote.csv" ]; then
  sed -i '1s/optionIdx/optionIndex/' "$BACKUP_DIR/PollVote.csv"
  echo "  Fixed PollVote: optionIdx → optionIndex"
fi

# Fix UserSport: is_primary → isPrimary
if [ -f "$BACKUP_DIR/UserSport.csv" ]; then
  sed -i '1s/is_primary/isPrimary/' "$BACKUP_DIR/UserSport.csv"
  echo "  Fixed UserSport: is_primary → isPrimary"
fi

ok "Export complete"

# ── Step 3: Import into VPS ────────────────────────────────────────────────────
hdr "IMPORTING INTO VPS POSTGRESQL"

import_table() {
  local schema_tbl="$1"
  local safe="$2"
  local pk="$3"

  local file="$BACKUP_DIR/${safe}.csv"
  [ ! -f "$file" ] && { echo "  ⏭  $safe (no file)"; return; }
  local lines
  lines=$(wc -l < "$file")
  [ "$lines" -le 1 ] && { echo "  ⏭  $safe (empty)"; return; }

  echo -n "  $schema_tbl... "
  local result
  result=$(psql "$VPS_DB" -c \
    "\COPY $schema_tbl FROM '$file' CSV HEADER ON_ERROR_STOP 0" 2>&1 | tail -2)

  if echo "$result" | grep -qE "^COPY [0-9]+"; then
    local n
    n=$(echo "$result" | grep -oE "COPY [0-9]+" | awk '{print $2}')
    echo "${n} rows ✅"
  elif echo "$result" | grep -qi "error"; then
    echo "⚠️  $(echo "$result" | grep -i error | head -1 | cut -c1-120)"
  else
    echo "✅"
  fi
}

import_table 'public.profiles'                'profiles'            'id'
import_table 'public."User"'                  'User'                'id'
import_table 'public."Role"'                  'Role'                'id'
import_table 'public."Sport"'                 'Sport'               'id'
import_table 'public."League"'                'League'              'id'
import_table 'public."Team"'                  'Team'                'id'
import_table 'public."Player"'                'Player'              'id'
import_table 'public."Coach"'                 'Coach'               'id'
import_table 'public."Match"'                 'Match'               'id'
import_table 'public."Community"'             'Community'           'id'
import_table 'public."NewsItem"'              'NewsItem'            'id'
import_table 'public."Post"'                  'Post'                'id'
import_table 'public."Poll"'                  'Poll'                'id'
import_table 'public."Prediction"'            'Prediction'          'id'
import_table 'public."Follow"'                'Follow'              '"followerId","followingId"'
import_table 'public."PostLike"'              'PostLike'            '"postId","userId"'
import_table 'public."PostShare"'             'PostShare'           '"postId","userId"'
import_table 'public."Comment"'               'Comment'             'id'
import_table 'public."CommentLike"'           'CommentLike'         '"commentId","userId"'
import_table 'public."PollVote"'              'PollVote'            '"pollId","userId"'
import_table 'public."CommunityMember"'       'CommunityMember'     '"communityId","userId"'
import_table 'public."UserFavorite"'          'UserFavorite'        'id'
import_table 'public."UserSport"'             'UserSport'           'id'
import_table 'public."Message"'               'Message'             'id'
import_table 'public."Notification"'          'Notification'        'id'
import_table 'public."ShopOrder"'             'ShopOrder'           'id'
import_table 'public."ClaimRequest"'          'ClaimRequest'        'id'
import_table 'public."VerificationRequest"'   'VerificationRequest' 'id'
import_table 'public.device_tokens'           'device_tokens'       '"user_id","token"'
import_table 'public.entity_follows'          'entity_follows'      '"follower_id","entity_type","entity_id"'
import_table 'public.fans'                    'fans'                '"fan_id","target_id"'
import_table 'public.taxonomy_term'           'taxonomy_term'       '"domain","slug"'

# ── Step 4: Verify ────────────────────────────────────────────────────────────
hdr "VERIFICATION"

psql "$VPS_DB" << 'SQL'
SELECT table_name, rows FROM (
  SELECT 'User'             as table_name, COUNT(*) as rows FROM public."User"
  UNION ALL SELECT 'profiles',             COUNT(*) FROM public.profiles
  UNION ALL SELECT 'Post',                 COUNT(*) FROM public."Post"
  UNION ALL SELECT 'Follow',               COUNT(*) FROM public."Follow"
  UNION ALL SELECT 'Comment',              COUNT(*) FROM public."Comment"
  UNION ALL SELECT 'Team',                 COUNT(*) FROM public."Team"
  UNION ALL SELECT 'Player',               COUNT(*) FROM public."Player"
  UNION ALL SELECT 'League',               COUNT(*) FROM public."League"
  UNION ALL SELECT 'Match',                COUNT(*) FROM public."Match"
  UNION ALL SELECT 'Community',            COUNT(*) FROM public."Community"
  UNION ALL SELECT 'Message',              COUNT(*) FROM public."Message"
  UNION ALL SELECT 'Notification',         COUNT(*) FROM public."Notification"
  UNION ALL SELECT 'Sport',                COUNT(*) FROM public."Sport"
  UNION ALL SELECT 'NewsItem',             COUNT(*) FROM public."NewsItem"
  UNION ALL SELECT 'device_tokens',        COUNT(*) FROM public.device_tokens
  UNION ALL SELECT 'entity_follows',       COUNT(*) FROM public.entity_follows
  UNION ALL SELECT 'PostLike',             COUNT(*) FROM public."PostLike"
  UNION ALL SELECT 'CommunityMember',      COUNT(*) FROM public."CommunityMember"
  UNION ALL SELECT 'ClaimRequest',         COUNT(*) FROM public."ClaimRequest"
) t ORDER BY rows DESC;
SQL

ok "Migration complete! Backup at $BACKUP_DIR"
