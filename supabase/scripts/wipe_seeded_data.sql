-- ============================================================
-- WIPE ALL SEEDED DATA — SportSphere clean slate
-- ============================================================
-- Run in: Supabase Dashboard → SQL Editor → Run
--
-- Removes all seeded team accounts, demo role accounts,
-- all Team/Player/Coach/Match/League rows, seeded communities.
-- Keeps: schema, functions, triggers, RLS, Role catalog,
--        any real user accounts.
--
-- FIX: snake_case tables use uuid FK, PascalCase use text FK.
--      _wipe_uuids for uuid columns, _wipe_ids for text columns.
-- ============================================================

-- Step 1: Collect seeded account IDs (text)
create temp table _wipe_ids as
select id from public."User"
where
  "email" like '%@teams.sportsphere.test'
  or "email" like '%@sportsphere.test'
  or "email" like '%@users.local';

-- Step 2: Matching UUIDs for snake_case tables
create temp table _wipe_uuids as
select id from public.profiles
where id::text in (select id from _wipe_ids);

-- Step 3: Snake_case tables (uuid FK)
delete from public.fans           where fan_id    in (select id from _wipe_uuids) or target_id in (select id from _wipe_uuids);
delete from public.follows        where follower_id in (select id from _wipe_uuids) or following_id in (select id from _wipe_uuids);
delete from public.post_likes     where user_id   in (select id from _wipe_uuids);
delete from public.community_members where user_id in (select id from _wipe_uuids);
delete from public.posts          where author_id  in (select id from _wipe_uuids);

-- Step 4: news/device tables (text FK)
delete from public.news_likes     where user_id in (select id from _wipe_ids);
delete from public.news_comments  where user_id in (select id from _wipe_ids);
delete from public.device_tokens  where user_id in (select id from _wipe_ids);

-- Step 5: PascalCase social tables (text FK)
delete from public."ShopOrder"       where "buyerId"    in (select id from _wipe_ids);
delete from public."PostShare"       where "userId"     in (select id from _wipe_ids);
delete from public."Notification"    where "receiverId" in (select id from _wipe_ids) or "actorId" in (select id from _wipe_ids);
delete from public."Message"         where "senderId"   in (select id from _wipe_ids) or "receiverId" in (select id from _wipe_ids);
delete from public."CommentLike"     where "userId"     in (select id from _wipe_ids);
delete from public."Comment"         where "authorId"   in (select id from _wipe_ids);
delete from public."PostLike"        where "userId"     in (select id from _wipe_ids);
delete from public."Post"            where "authorId"   in (select id from _wipe_ids);
delete from public."Follow"          where "followerId" in (select id from _wipe_ids) or "followingId" in (select id from _wipe_ids);
delete from public."CommunityMember" where "userId"     in (select id from _wipe_ids);
delete from public."PollVote"        where "userId"     in (select id from _wipe_ids);
delete from public."Prediction"      where "userId"     in (select id from _wipe_ids);
delete from public."ClaimRequest"    where "userId"     in (select id from _wipe_ids);
delete from public."UserSport"       where "userId"     in (select id from _wipe_ids);
delete from public."UserFavorite"    where "userId"     in (select id from _wipe_ids);
delete from public."VerificationRequest" where "userId" in (select id from _wipe_ids);

-- Step 6: Entity tables — wipe ALL rows
delete from public."PlayerMatchStat";
delete from public."Player";
delete from public."Coach";
delete from public."Match";
delete from public."Team";
delete from public."League";
delete from public."Competition";

-- Step 7: Communities — wipe all
delete from public."Community";
delete from public.communities;

-- Step 8: Role-specific profile tables
delete from public."TeamProfile"              where "userId" in (select id from _wipe_ids);
delete from public."PlayerProfile"            where "userId" in (select id from _wipe_ids);
delete from public."CoachProfile"             where "userId" in (select id from _wipe_ids);
delete from public."ScoutProfile"             where "userId" in (select id from _wipe_ids);
delete from public."AgentProfile"             where "userId" in (select id from _wipe_ids);
delete from public."SupportStaffProfile"      where "userId" in (select id from _wipe_ids);
delete from public."AnalystProfile"           where "userId" in (select id from _wipe_ids);
delete from public."JournalistProfile"        where "userId" in (select id from _wipe_ids);
delete from public."CreatorProfile"           where "userId" in (select id from _wipe_ids);
delete from public."ModeratorProfile"         where "userId" in (select id from _wipe_ids);
delete from public."OfficialProfile"          where "userId" in (select id from _wipe_ids);
delete from public."SponsorProfile"           where "userId" in (select id from _wipe_ids);
delete from public."MediaBroadcastProfile"    where "userId" in (select id from _wipe_ids);
delete from public."CommentatorProfile"       where "userId" in (select id from _wipe_ids);
delete from public."OrganizationProfile"      where "userId" in (select id from _wipe_ids);
delete from public."AcademyProfile"           where "userId" in (select id from _wipe_ids);
delete from public."LeagueProfile"            where "userId" in (select id from _wipe_ids);
delete from public."CompetitionProfile"       where "userId" in (select id from _wipe_ids);
delete from public."CommunityProfile"         where "userId" in (select id from _wipe_ids);
delete from public."BusinessProfile"          where "userId" in (select id from _wipe_ids);
delete from public."CommercialPartnerProfile" where "userId" in (select id from _wipe_ids);
delete from public."VenueProfile"             where "userId" in (select id from _wipe_ids);

-- Step 9: User + profiles rows
delete from public."User"   where id in (select id from _wipe_ids);
delete from public.profiles where id in (select id from _wipe_uuids);

-- Step 10: Auth users
delete from auth.users
  where email like '%@teams.sportsphere.test'
     or email like '%@sportsphere.test'
     or email like '%@users.local';

-- Step 11: Reset social counts for remaining real users
update public."User" set
  "followingCount" = (select count(*) from public."Follow" f where f."followerId" = "User".id),
  "followerCount"  = (select count(*) from public."Follow" f where f."followingId" = "User".id),
  "postCount"      = (select count(*) from public."Post"   p where p."authorId"    = "User".id);

-- Step 12: Cleanup
drop table _wipe_ids;
drop table _wipe_uuids;

-- Verification
select
  (select count(*) from public."Team")      as teams,
  (select count(*) from public."Player")    as players,
  (select count(*) from public."Coach")     as coaches,
  (select count(*) from public."Match")     as matches,
  (select count(*) from public."League")    as leagues,
  (select count(*) from public."Community") as communities,
  (select count(*) from auth.users)         as auth_users,
  (select count(*) from public."User")      as app_users;
