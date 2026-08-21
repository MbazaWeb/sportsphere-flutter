-- ============================================================
-- WIPE ALL SEEDED DATA
-- SportSphere — clean slate for real users
--
-- Run this in Supabase Dashboard → SQL Editor
-- (or via supabase db execute --file wipe_seeded_data.sql)
--
-- What this removes:
--   • All 46 team auth accounts + their User/profiles rows
--   • All 12 person-role demo accounts (coach, scout, agent, etc.)
--   • All Team, Player, Coach, Match, League rows
--   • All seeded Community rows
--   • All dependent data (posts, follows, notifications, etc.)
--     that belonged to these seeded accounts
--
-- What this KEEPS:
--   • Schema (all tables, functions, triggers, RLS policies)
--   • Role catalog (Role table — the 23 role types)
--   • Any real user accounts (non-seeded emails)
-- ============================================================

-- ── Step 1: Collect seeded account IDs ───────────────────────
-- Team accounts: email pattern *@teams.sportsphere.test
-- Person role accounts: email pattern *@sportsphere.test (non-team)

create temp table _seeded_ids as
select u.id
from public."User" u
where
  u."email" like '%@teams.sportsphere.test'
  or u."email" like '%@sportsphere.test'
  or u."email" like '%@users.local';

-- Also catch any auth.users with those patterns not yet in User table
create temp table _seeded_auth_ids as
select au.id::text
from auth.users au
where
  au.email like '%@teams.sportsphere.test'
  or au.email like '%@sportsphere.test'
  or au.email like '%@users.local';

-- ── Step 2: Wipe dependent data in order ─────────────────────

-- Orders
delete from public."Order"
where "buyerId" in (select id from _seeded_ids);

-- Notifications
delete from public."Notification"
where "receiverId" in (select id from _seeded_ids)
   or "actorId"   in (select id from _seeded_ids);

-- Messages
delete from public."Message"
where "senderId"   in (select id from _seeded_ids)
   or "receiverId" in (select id from _seeded_ids);

-- Comments
delete from public."Comment"
where "authorId" in (select id from _seeded_ids);

-- Post likes
delete from public."PostLike"
where "userId" in (select id from _seeded_ids);

-- Posts
delete from public."Post"
where "authorId" in (select id from _seeded_ids);

-- Follows
delete from public."Follow"
where "followerId"  in (select id from _seeded_ids)
   or "followingId" in (select id from _seeded_ids);

-- Community members
delete from public."CommunityMember"
where "userId" in (select id from _seeded_ids);

-- Poll votes
delete from public."PollVote"
where "userId" in (select id from _seeded_ids);

-- Predictions
delete from public."Prediction"
where "userId" in (select id from _seeded_ids);

-- PlayerMatchStat
delete from public."PlayerMatchStat"
where "playerId" in (
  select id from public."Player"
  where "accountUserId" in (select id from _seeded_ids)
);

-- Claim requests
delete from public."ClaimRequest"
where "requesterId" in (select id from _seeded_ids);

-- ── Step 3: Wipe entity tables ────────────────────────────────

-- Players (all — none were real users)
delete from public."Player";

-- Coaches (all — none were real users)
delete from public."Coach";

-- Matches (all — fixture data, no real user ownership)
delete from public."Match";

-- Teams (all — 46 seeded clubs)
delete from public."Team";

-- Leagues (seeded)
delete from public."League";

-- ── Step 4: Wipe seeded Communities ──────────────────────────
-- These 5 were seeded with hardcoded IDs
delete from public."Community"
where id in (
  'com-simba-fans',
  'com-yanga-union',
  'com-tpl-tactics',
  'com-dar-meetups',
  'com-predictions'
);

-- ── Step 5: Wipe role-specific profile tables ─────────────────
delete from public."TeamProfile"
where "userId" in (select id from _seeded_ids);

delete from public."PlayerProfile"
where "userId" in (select id from _seeded_ids);

delete from public."CoachProfile"
where "userId" in (select id from _seeded_ids);

delete from public."ScoutProfile"
where "userId" in (select id from _seeded_ids);

delete from public."AgentProfile"
where "userId" in (select id from _seeded_ids);

delete from public."SupportStaffProfile"
where "userId" in (select id from _seeded_ids);

delete from public."AnalystProfile"
where "userId" in (select id from _seeded_ids);

delete from public."JournalistProfile"
where "userId" in (select id from _seeded_ids);

delete from public."CreatorProfile"
where "userId" in (select id from _seeded_ids);

delete from public."ModeratorProfile"
where "userId" in (select id from _seeded_ids);

delete from public."OfficialProfile"
where "userId" in (select id from _seeded_ids);

delete from public."SponsorProfile"
where "userId" in (select id from _seeded_ids);

delete from public."MediaBroadcastProfile"
where "userId" in (select id from _seeded_ids);

-- ── Step 6: Wipe User + profiles rows ────────────────────────
delete from public."User"
where id in (select id from _seeded_ids);

delete from public.profiles
where id in (select id::uuid from _seeded_ids where id ~ '^[0-9a-f-]{36}$');

-- ── Step 7: Delete auth.users (requires service role) ────────
-- This removes the actual login credentials for all seeded accounts.
delete from auth.users
where id in (
  select au.id from auth.users au
  where au.email like '%@teams.sportsphere.test'
     or au.email like '%@sportsphere.test'
     or au.email like '%@users.local'
);

-- ── Step 8: Reset counts to zero ─────────────────────────────
-- Any real users that followed seeded accounts get stale counts reset
update public."User"
set "followingCount" = (
  select count(*) from public."Follow" f where f."followerId" = "User".id
),
"followerCount" = (
  select count(*) from public."Follow" f where f."followingId" = "User".id
)
where id not in (select id from _seeded_ids);

-- ── Step 9: Clean up temp tables ─────────────────────────────
drop table _seeded_ids;
drop table _seeded_auth_ids;

-- ── Verification ─────────────────────────────────────────────
select
  (select count(*) from public."Team")          as teams,
  (select count(*) from public."Player")        as players,
  (select count(*) from public."Coach")         as coaches,
  (select count(*) from public."Match")         as matches,
  (select count(*) from public."League")        as leagues,
  (select count(*) from public."Community")     as communities,
  (select count(*) from auth.users)             as auth_users,
  (select count(*) from public."User")          as app_users;
-- Expected: teams=0, players=0, coaches=0, matches=0, leagues=0,
--           communities=0, auth_users=only real signups, app_users=only real signups
