-- ============================================================
-- WIPE ALL SEEDED DATA — SportSphere clean slate
-- ============================================================
-- Run in: Supabase Dashboard → SQL Editor → Run
--
-- Removes all 46 team accounts, 12 demo role accounts,
-- all Team/Player/Coach/Match/League rows, seeded communities,
-- and all their dependent data.
--
-- Keeps: schema, functions, triggers, RLS, Role catalog,
--        any real user accounts you created yourself.
-- ============================================================


-- Step 1: Collect seeded account IDs

create temp table _wipe_ids as
select id from public."User"
where
  "email" like '%@teams.sportsphere.test'
  or "email" like '%@sportsphere.test'
  or "email" like '%@users.local';

-- UUID equivalents for snake_case tables (profiles uses uuid PK)
create temp table _wipe_uuids as
select id from public.profiles
where id::text in (select id from _wipe_ids);


-- Step 2: Snake_case tables (profiles/uuid FK)

delete from public.fans
  where fan_id    in (select id from _wipe_uuids)
     or target_id in (select id from _wipe_uuids);

delete from public.follows
  where follower_id  in (select id from _wipe_uuids)
     or following_id in (select id from _wipe_uuids);

delete from public.post_likes
  where user_id in (select id from _wipe_uuids);

delete from public.community_members
  where user_id in (select id from _wipe_uuids);

delete from public.news_likes
  where user_id in (select id from _wipe_uuids);

delete from public.news_comments
  where user_id in (select id from _wipe_uuids);

delete from public.posts
  where user_id in (select id from _wipe_uuids);

delete from public.device_tokens
  where user_id in (select id from _wipe_ids);


-- Step 3: PascalCase social / commerce tables

delete from public."ShopOrder"
  where "buyerId" in (select id from _wipe_ids);

delete from public."PostShare"
  where "userId" in (select id from _wipe_ids);

delete from public."Notification"
  where "receiverId" in (select id from _wipe_ids)
     or "actorId"    in (select id from _wipe_ids);

delete from public."Message"
  where "senderId"   in (select id from _wipe_ids)
     or "receiverId" in (select id from _wipe_ids);

delete from public."CommentLike"
  where "userId" in (select id from _wipe_ids);

delete from public."Comment"
  where "authorId" in (select id from _wipe_ids);

delete from public."PostLike"
  where "userId" in (select id from _wipe_ids);

delete from public."Post"
  where "authorId" in (select id from _wipe_ids);

delete from public."Follow"
  where "followerId"  in (select id from _wipe_ids)
     or "followingId" in (select id from _wipe_ids);

delete from public."CommunityMember"
  where "userId" in (select id from _wipe_ids);

delete from public."PollVote"
  where "userId" in (select id from _wipe_ids);

delete from public."Prediction"
  where "userId" in (select id from _wipe_ids);

delete from public."ClaimRequest"
  where "userId" in (select id from _wipe_ids);

delete from public."UserSport"
  where "userId" in (select id from _wipe_ids);

delete from public."UserFavorite"
  where "userId" in (select id from _wipe_ids);

delete from public."VerificationRequest"
  where "userId" in (select id from _wipe_ids);


-- Step 4: Player stats first (FK to Player)

delete from public."PlayerMatchStat";


-- Step 5: Entity tables — wipe all rows

delete from public."Player";
delete from public."Coach";
delete from public."Match";
delete from public."Team";
delete from public."League";
delete from public."Competition";
delete from public."Location";


-- Step 6: Seeded communities (hardcoded IDs and names)

delete from public."Community"
  where id in (
    'com-simba-fans',
    'com-yanga-union',
    'com-tpl-tactics',
    'com-dar-meetups',
    'com-predictions'
  );

delete from public.communities
  where name in (
    'Simba SC Official Fans',
    'Yanga Union',
    'TPL Tactics Room',
    'Dar Matchday Meetups',
    'Predictions League'
  );


-- Step 7: Role-specific profile tables

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


-- Step 8: User + profiles rows

delete from public."User"
  where id in (select id from _wipe_ids);

delete from public.profiles
  where id in (select id from _wipe_uuids);


-- Step 9: Auth users (requires service role — works in SQL editor)

delete from auth.users
  where email like '%@teams.sportsphere.test'
     or email like '%@sportsphere.test'
     or email like '%@users.local';


-- Step 10: Recount stats for remaining real users

update public."User" set
  "followingCount" = (
    select count(*) from public."Follow" f where f."followerId" = "User".id
  ),
  "followerCount" = (
    select count(*) from public."Follow" f where f."followingId" = "User".id
  ),
  "postCount" = (
    select count(*) from public."Post" p where p."authorId" = "User".id
  );


-- Step 11: Cleanup temp tables

drop table _wipe_ids;
drop table _wipe_uuids;


-- Verification — all entity counts should be 0 after this runs

select
  (select count(*) from public."Team")         as teams,
  (select count(*) from public."Player")       as players,
  (select count(*) from public."Coach")        as coaches,
  (select count(*) from public."Match")        as matches,
  (select count(*) from public."League")       as leagues,
  (select count(*) from public."Community")    as communities,
  (select count(*) from public.communities)    as communities_v2,
  (select count(*) from auth.users)            as auth_users,
  (select count(*) from public."User")         as app_users,
  (select count(*) from public."Post")         as posts;

-- Expected: teams=0, players=0, coaches=0, matches=0, leagues=0
--           communities=0, communities_v2=0
--           auth_users/app_users/posts = only your real sign-ups
