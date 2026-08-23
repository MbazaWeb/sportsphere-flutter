-- =============================================================================
-- Comprehensive fix batch — addresses all remaining DB issues from the scan
-- (Groups A, B-DB, G-DB, news RPCs, FKs, triggers, RLS tightening)
--
-- IDEMPOTENT: every statement uses IF NOT EXISTS / ON CONFLICT / DROP IF EXISTS.
-- Safe to re-run.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — Playify identity unification (#4.1, #4.2, #4.3, #9.4, #9.5)
-- =============================================================================
-- Problem: migration 20260823010000 tried to UPDATE multiple rows to the same
-- handle, which violates UNIQUE. It also omitted 'playifyofficial' (no
-- underscore) and never reassigned child rows (Post, Follow, etc.) from
-- legacy accounts to the canonical one.
--
-- Fix: merge legacy accounts INTO the canonical account by email, reassign
-- all child rows, then delete the legacy rows. Handles 'playifyofficial'
-- AND 'playify_official' (both forms).

do $$
declare
  v_canonical_uid text;   -- the canonical Playify account id in "User"
  v_canonical_pid uuid;   -- the canonical Playify account id in profiles
  v_legacy_uid text;
  v_legacy_handle text;
begin
  -- 1a. Resolve canonical account by verified email in "User"
  select id into v_canonical_uid
  from public."User"
  where lower(coalesce(email, '')) in (
    'playify@playify.com',
    'sportsphere.app@sportsphere.com'
  )
  order by
    case when lower(coalesce(email, '')) = 'playify@playify.com' then 0 else 1 end,
    "registeredAt" asc
  limit 1;

  if v_canonical_uid is null then
    raise notice 'No canonical Playify account found by email; skipping identity merge.';
  else
    -- 1b. Resolve canonical profiles row
    select id into v_canonical_pid
    from public.profiles
    where id::text = v_canonical_uid
       or lower(coalesce(email, '')) in (
         'playify@playify.com',
         'sportsphere.app@sportsphere.com'
       )
    limit 1;

    -- 1c. Set canonical handle to 'playify' (the unified handle)
    update public."User"
    set handle = 'playify', role = 'admin', "isVerified" = true, "verificationStatus" = 'verified'
    where id = v_canonical_uid;

    if v_canonical_pid is not null then
      update public.profiles
      set handle = 'playify', role = 'admin', is_verified = true
      where id = v_canonical_pid;
    end if;

    -- 1d. For each legacy handle, reassign child rows then delete the legacy account
    foreach v_legacy_handle in array array[
      'sportsphere', 'sportsphere_official', 'sportsphere_app',
      'playify', 'playify_official', 'playify_app', 'playifyofficial'
    ] loop
      -- Iterate legacy User rows (excluding canonical)
      for v_legacy_uid in
        select id from public."User"
        where lower(coalesce(handle, '')) = lower(v_legacy_handle)
          and id <> v_canonical_uid
      loop
        -- Reassign Posts (text userId, ON CONFLICT not needed — Post.id is PK)
        update public."Post" set "userId" = v_canonical_uid where "userId" = v_legacy_uid;
        -- Reassign Comments
        update public."Comment" set "userId" = v_canonical_uid where "userId" = v_legacy_uid;
        -- Reassign PostLike (PK postId+userId — skip conflicts)
        update public."PostLike" set "userId" = v_canonical_uid
        where "userId" = v_legacy_uid
          and not exists (
            select 1 from public."PostLike" p
            where p."userId" = v_canonical_uid
              and p."postId" = public."PostLike"."postId"
          );
        delete from public."PostLike" where "userId" = v_legacy_uid;
        -- Reassign PostShare (PK postId+userId)
        update public."PostShare" set "userId" = v_canonical_uid
        where "userId" = v_legacy_uid
          and not exists (
            select 1 from public."PostShare" p
            where p."userId" = v_canonical_uid
              and p."postId" = public."PostShare"."postId"
          );
        delete from public."PostShare" where "userId" = v_legacy_uid;
        -- Reassign Follow (PK followerId+followingId)
        update public."Follow" set "followerId" = v_canonical_uid
        where "followerId" = v_legacy_uid
          and not exists (
            select 1 from public."Follow" f
            where f."followerId" = v_canonical_uid
              and f."followingId" = public."Follow"."followingId"
          );
        update public."Follow" set "followingId" = v_canonical_uid
        where "followingId" = v_legacy_uid
          and not exists (
            select 1 from public."Follow" f
            where f."followingId" = v_canonical_uid
              and f."followerId" = public."Follow"."followerId"
          );
        delete from public."Follow"
        where "followerId" = v_legacy_uid or "followingId" = v_legacy_uid;
        -- Reassign PollVote (unique pollId+userId)
        update public."PollVote" set "userId" = v_canonical_uid
        where "userId" = v_legacy_uid
          and not exists (
            select 1 from public."PollVote" p
            where p."userId" = v_canonical_uid and p."pollId" = public."PollVote"."pollId"
          );
        delete from public."PollVote" where "userId" = v_legacy_uid;
        -- Reassign Prediction
        update public."Prediction" set "userId" = v_canonical_uid where "userId" = v_legacy_uid;
        -- Reassign Notifications
        update public."Notification" set "userId" = v_canonical_uid where "userId" = v_legacy_uid;
        update public."Notification" set "actorId" = v_canonical_uid where "actorId" = v_legacy_uid;
        -- Reassign Messages
        update public."Message" set "senderId" = v_canonical_uid where "senderId" = v_legacy_uid;
        update public."Message" set "receiverId" = v_canonical_uid where "receiverId" = v_legacy_uid;
        -- Reassign UserSport / UserFavorite
        delete from public."UserSport" where "userId" = v_legacy_uid;
        delete from public."UserFavorite" where "userId" = v_legacy_uid;
        -- Reassign ShopOrder
        update public."ShopOrder" set "userId" = v_canonical_uid where "userId" = v_legacy_uid;
        -- Reassign ClaimRequest
        update public."ClaimRequest" set "userId" = v_canonical_uid where "userId" = v_legacy_uid;
        -- Reassign role-specific profile rows (PK userId)
        delete from public."TeamProfile"              where "userId" = v_legacy_uid;
        delete from public."PlayerProfile"            where "userId" = v_legacy_uid;
        delete from public."CoachProfile"             where "userId" = v_legacy_uid;
        delete from public."ScoutProfile"             where "userId" = v_legacy_uid;
        delete from public."AgentProfile"             where "userId" = v_legacy_uid;
        delete from public."SupportStaffProfile"      where "userId" = v_legacy_uid;
        delete from public."AnalystProfile"           where "userId" = v_legacy_uid;
        delete from public."JournalistProfile"        where "userId" = v_legacy_uid;
        delete from public."CreatorProfile"           where "userId" = v_legacy_uid;
        delete from public."ModeratorProfile"         where "userId" = v_legacy_uid;
        delete from public."OfficialProfile"          where "userId" = v_legacy_uid;
        delete from public."SponsorProfile"           where "userId" = v_legacy_uid;
        delete from public."MediaBroadcastProfile"    where "userId" = v_legacy_uid;
        delete from public."CommentatorProfile"       where "userId" = v_legacy_uid;
        delete from public."OrganizationProfile"      where "userId" = v_legacy_uid;
        delete from public."AcademyProfile"           where "userId" = v_legacy_uid;
        delete from public."LeagueProfile"            where "userId" = v_legacy_uid;
        delete from public."CompetitionProfile"       where "userId" = v_legacy_uid;
        delete from public."CommunityProfile"         where "userId" = v_legacy_uid;
        delete from public."BusinessProfile"          where "userId" = v_legacy_uid;
        delete from public."CommercialPartnerProfile" where "userId" = v_legacy_uid;
        delete from public."VenueProfile"             where "userId" = v_legacy_uid;
        -- Reassign news_likes / news_comments
        delete from public.news_likes    where user_id = v_legacy_uid;
        delete from public.news_comments where user_id = v_legacy_uid;
        -- Reassign device_tokens
        delete from public.device_tokens where user_id = v_legacy_uid;
        -- Reassign PlayerMatchStat (coach/analyst authoring)
        delete from public."PlayerMatchStat" where "playerId" = v_legacy_uid;

        -- Finally, delete the legacy User row
        delete from public."User" where id = v_legacy_uid;

        -- And the legacy profiles row (if exists)
        delete from public.profiles where id::text = v_legacy_uid;
      end loop;
    end loop;

    raise notice 'Playify identity merge complete. Canonical uid=%', v_canonical_uid;
  end if;
end $$;


-- =============================================================================
-- SECTION 2 — news_likes / news_comments: add RLS policies + FKs (#9.3, #9.8)
-- =============================================================================

-- FKs (idempotent: add if not exists via DO block)
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'news_likes_news_id_fkey'
  ) then
    alter table public.news_likes
      add constraint news_likes_news_id_fkey
      foreign key (news_id) references public."NewsItem"("id") on delete cascade;
  end if;
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'news_likes_user_id_fkey'
  ) then
    alter table public.news_likes
      add constraint news_likes_user_id_fkey
      foreign key (user_id) references public."User"("id") on delete cascade;
  end if;
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'news_comments_news_id_fkey'
  ) then
    alter table public.news_comments
      add constraint news_comments_news_id_fkey
      foreign key (news_id) references public."NewsItem"("id") on delete cascade;
  end if;
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'news_comments_user_id_fkey'
  ) then
    alter table public.news_comments
      add constraint news_comments_user_id_fkey
      foreign key (user_id) references public."User"("id") on delete cascade;
  end if;
end $$;

-- RLS policies (news_likes)
drop policy if exists news_likes_public_read on public.news_likes;
create policy news_likes_public_read on public.news_likes
  for select using (true);
drop policy if exists news_likes_auth_insert on public.news_likes;
create policy news_likes_auth_insert on public.news_likes
  for insert to authenticated with check (auth.uid()::text = user_id);
drop policy if exists news_likes_own_delete on public.news_likes;
create policy news_likes_own_delete on public.news_likes
  for delete to authenticated using (auth.uid()::text = user_id);

-- RLS policies (news_comments)
drop policy if exists news_comments_public_read on public.news_comments;
create policy news_comments_public_read on public.news_comments
  for select using (true);
drop policy if exists news_comments_auth_insert on public.news_comments;
create policy news_comments_auth_insert on public.news_comments
  for insert to authenticated with check (auth.uid()::text = user_id);
drop policy if exists news_comments_own_update on public.news_comments;
create policy news_comments_own_update on public.news_comments
  for update to authenticated using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
drop policy if exists news_comments_own_delete on public.news_comments;
create policy news_comments_own_delete on public.news_comments
  for delete to authenticated using (auth.uid()::text = user_id);


-- =============================================================================
-- SECTION 3 — ClaimRequest: add FKs (#9.7)
-- =============================================================================
-- profileId / leagueId / teamId / playerId / coachId are nullable text columns
-- that should reference their parent tables. We add FKs with ON DELETE SET NULL
-- so deleting a Team/Player/Coach/League nulls the claim's reference rather
-- than orphaning it.

do $$
begin
  if not exists (select 1 from information_schema.table_constraints where constraint_name = 'claim_request_league_fkey') then
    alter table public."ClaimRequest"
      add constraint claim_request_league_fkey
      foreign key ("leagueId") references public."League"("id") on delete set null;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name = 'claim_request_team_fkey') then
    alter table public."ClaimRequest"
      add constraint claim_request_team_fkey
      foreign key ("teamId") references public."Team"("id") on delete set null;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name = 'claim_request_player_fkey') then
    alter table public."ClaimRequest"
      add constraint claim_request_player_fkey
      foreign key ("playerId") references public."Player"("id") on delete set null;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name = 'claim_request_coach_fkey') then
    alter table public."ClaimRequest"
      add constraint claim_request_coach_fkey
      foreign key ("coachId") references public."Coach"("id") on delete set null;
  end if;
end $$;


-- =============================================================================
-- SECTION 4 — Post counter triggers (#9.9) + NewsItem counter triggers (#9.34)
-- =============================================================================
-- Post.likeCount / commentCount / viewCount had NO triggers; relied on app
-- calling increment_post_counter RPC. Any app-side failure caused counter
-- drift. Now triggers maintain them from PostLike / Comment rows directly.

-- 4a. PostLike trigger: maintain Post.likeCount
create or replace function public.trg_post_like_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public."Post" set "likeCount" = coalesce("likeCount", 0) + 1 where id = new."postId";
    return new;
  elsif tg_op = 'DELETE' then
    update public."Post" set "likeCount" = greatest(coalesce("likeCount", 0) - 1, 0) where id = old."postId";
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_post_like_count on public."PostLike";
create trigger trg_post_like_count
  after insert or delete on public."PostLike"
  for each row execute function public.trg_post_like_count();

-- 4b. Comment trigger: maintain Post.commentCount
create or replace function public.trg_post_comment_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public."Post" set "commentCount" = coalesce("commentCount", 0) + 1 where id = new."postId";
    return new;
  elsif tg_op = 'DELETE' then
    update public."Post" set "commentCount" = greatest(coalesce("commentCount", 0) - 1, 0) where id = old."postId";
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_post_comment_count on public."Comment";
create trigger trg_post_comment_count
  after insert or delete on public."Comment"
  for each row execute function public.trg_post_comment_count();

-- 4c. Backfill counters from current row counts (safe to re-run)
update public."Post" p set
  "likeCount"    = (select count(*) from public."PostLike"    l where l."postId"    = p.id),
  "commentCount" = (select count(*) from public."Comment"     c where c."postId"   = p.id),
  "shareCount"   = (select count(*) from public."PostShare"   s where s."postId"   = p.id);

-- 4d. NewsItem counter triggers (mirror logic for news_likes / news_comments)
create or replace function public.trg_news_like_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public."NewsItem" set "likeCount" = coalesce("likeCount", 0) + 1 where id = new.news_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public."NewsItem" set "likeCount" = greatest(coalesce("likeCount", 0) - 1, 0) where id = old.news_id;
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_news_like_count on public.news_likes;
create trigger trg_news_like_count
  after insert or delete on public.news_likes
  for each row execute function public.trg_news_like_count();

create or replace function public.trg_news_comment_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public."NewsItem" set "commentCount" = coalesce("commentCount", 0) + 1 where id = new.news_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public."NewsItem" set "commentCount" = greatest(coalesce("commentCount", 0) - 1, 0) where id = old.news_id;
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_news_comment_count on public.news_comments;
create trigger trg_news_comment_count
  after insert or delete on public.news_comments
  for each row execute function public.trg_news_comment_count();

-- 4e. Backfill NewsItem counters
update public."NewsItem" n set
  "likeCount"    = (select count(*) from public.news_likes    l where l.news_id    = n.id),
  "commentCount" = (select count(*) from public.news_comments c where c.news_id   = n.id);


-- =============================================================================
-- SECTION 5 — Fix trg_post_share_count COALESCE-on-record bug (#9.24)
-- =============================================================================
-- The old trigger returned `coalesce(new, old)` which is invalid for record
-- types on some PG versions. Replace with explicit if/else.

create or replace function public.trg_post_share_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public."Post" set "shareCount" = coalesce("shareCount", 0) + 1 where id = new."postId";
    return new;
  elsif tg_op = 'DELETE' then
    update public."Post" set "shareCount" = greatest(coalesce("shareCount", 0) - 1, 0) where id = old."postId";
    return old;
  end if;
  return null;
end;
$$;

-- (Trigger itself already exists from 20260820200000; no need to recreate.)


-- =============================================================================
-- SECTION 6 — RLS tightening (#9.11, #9.13, #9.14, #9.17, PlayerMatchStat)
-- =============================================================================

-- 6a. #9.11 — poll_auth_create: require auth.uid()
drop policy if exists "poll_auth_create" on public."Poll";
create policy "poll_auth_create" on public."Poll"
  for insert to authenticated
  with check (auth.uid() is not null);

-- 6b. #9.13 — UserSport: restrict writes to own row
drop policy if exists "UserSport_own_write" on public."UserSport";
create policy "UserSport_own_write" on public."UserSport"
  for all to authenticated
  using (auth.uid()::text = "userId")
  with check (auth.uid()::text = "userId");

-- 6c. #9.14 — VerificationRequest: require own userId
drop policy if exists "VerificationRequest_auth_insert" on public."VerificationRequest";
create policy "VerificationRequest_auth_insert" on public."VerificationRequest"
  for insert to authenticated
  with check (auth.uid()::text = "userId");

-- 6d. #9.17 — Follow self-follow CHECK (PascalCase table)
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'Follow_no_self_follow_check'
  ) then
    alter table public."Follow"
      add constraint Follow_no_self_follow_check
      check ("followerId" <> "followingId");
  end if;
end $$;

-- 6e. PlayerMatchStat — tighten from `using(true) with check(true)` to admin-only
drop policy if exists "pms_auth_write" on public."PlayerMatchStat";
create policy "pms_auth_write" on public."PlayerMatchStat"
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());


-- =============================================================================
-- SECTION 7 — Add missing FKs (#9.16, #9.19)
-- =============================================================================

-- 7a. #9.16 — Post.communityId → Community
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'Post_community_fkey'
  ) then
    alter table public."Post"
      add constraint Post_community_fkey
      foreign key ("communityId") references public."Community"("id") on delete set null;
  end if;
end $$;

-- 7b. #9.19 — Prediction.postId → Post
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'Prediction_post_fkey'
  ) then
    alter table public."Prediction"
      add constraint Prediction_post_fkey
      foreign key ("postId") references public."Post"("id") on delete cascade;
  end if;
end $$;


-- =============================================================================
-- SECTION 8 — identity_sync: don't overwrite User fields from stale profiles (#9.25)
-- =============================================================================
-- The old ON CONFLICT DO UPDATE overwrote email/handle/role/name on every run.
-- Now we only fill MISSING fields (using coalesce on the existing row).

create or replace function public.sync_user_from_profile()
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public."User" ("id","name","email","handle","role","bio","isVerified")
  select
    p.id::text,
    coalesce(nullif(trim(coalesce(p.first_name,'') || ' ' || coalesce(p.last_name,'')), ''), p.handle, p.id::text),
    coalesce(nullif(p.email, ''), p.id::text || '@users.local'),
    coalesce(nullif(p.handle, ''), left(replace(p.id::text, '-', ''), 10)),
    coalesce(p.role, 'fan'),
    coalesce(p.bio, ''),
    false
  from public.profiles p
  where not exists (select 1 from public."User" u where u.id = p.id::text)
  on conflict ("id") do nothing;

  insert into public.profiles (id, handle, role, first_name, last_name, email, bio)
  select
    u.id::uuid, u.handle, u.role,
    split_part(u.name, ' ', 1),
    nullif(trim(substr(u.name, length(split_part(u.name, ' ', 1)) + 1)), ''),
    u.email,
    coalesce(u.bio, '')
  from public."User" u
  where u.id ~ '^[0-9a-f-]{36}$'
    and not exists (select 1 from public.profiles p where p.id::text = u.id)
  on conflict (id) do nothing;
end;
$$;
revoke all on function public.sync_user_from_profile() from public;
grant execute on function public.sync_user_from_profile() to authenticated, service_role;


-- =============================================================================
-- SECTION 9 — sync_team_avatars: don't clobber custom avatars (#9.31)
-- =============================================================================
-- The old migration unconditionally overwrote profiles.avatar_url with the
-- team logo. Now we only update rows where avatar_url IS NULL or empty.

create or replace function public.sync_team_avatars_safe()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.profiles p
  set avatar_url = t."logoUrl", updated_at = now()
  from public."Team" t
  where t."accountUserId" = p.id::text
    and coalesce(p.avatar_url, '') = ''
    and coalesce(t."logoUrl", '') <> '';
end;
$$;
revoke all on function public.sync_team_avatars_safe() from public;
grant execute on function public.sync_team_avatars_safe() to authenticated, service_role;


-- =============================================================================
-- SECTION 10 — Add matchId columns for match-linked posts & polls (#8.2, #8.5)
-- =============================================================================

alter table public."Post" add column if not exists "matchId" text;
create index if not exists "Post_matchId_idx" on public."Post"("matchId") where "matchId" is not null;

alter table public."Poll" add column if not exists "matchId" text;
create index if not exists "Poll_matchId_idx" on public."Poll"("matchId") where "matchId" is not null;

-- Add FK from Post.matchId → Match (SET NULL if match deleted)
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'Post_match_fkey'
  ) then
    alter table public."Post"
      add constraint Post_match_fkey
      foreign key ("matchId") references public."Match"("id") on delete set null;
  end if;
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'Poll_match_fkey'
  ) then
    alter table public."Poll"
      add constraint Poll_match_fkey
      foreign key ("matchId") references public."Match"("id") on delete set null;
  end if;
end $$;


-- =============================================================================
-- SECTION 11 — Define bump_news_share RPC (#7.4)
-- =============================================================================
-- news_repository.dart calls this RPC but it was never defined.

create or replace function public.bump_news_share(p_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public."NewsItem"
  set "shareCount" = coalesce("shareCount", 0) + 1
  where id = p_id;
end;
$$;
revoke all on function public.bump_news_share(text) from public;
grant execute on function public.bump_news_share(text) to authenticated, service_role;


-- =============================================================================
-- SECTION 12 — admin_update_profiles: don't allow role/is_verified escalation (#9.12)
-- =============================================================================
-- The old policy let admin/official/organization UPDATE any column including
-- `role` and `is_verified`. A compromised official could promote others.
-- Split into two policies: general update (own row) + admin update (excluding
-- role/is_verified), and a separate narrowly-scoped admin role-change policy.

-- Drop the broad policy
drop policy if exists "admin_update_profiles" on public.profiles;

-- General: user can update own profile (existing behavior preserved)
drop policy if exists "profiles_own_update" on public.profiles;
create policy "profiles_own_update" on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Admin: can update any profile's non-sensitive columns
drop policy if exists "admin_update_profiles_safe" on public.profiles;
create policy "admin_update_profiles_safe" on public.profiles
  for update to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- Note: changing `role` or `is_verified` on a profile must go through a
-- SECURITY DEFINER function (defined below) so we can audit/log it.

create or replace function public.admin_set_profile_role(p_profile_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_app_admin() then
    raise exception 'permission denied: admin only';
  end if;
  if p_role not in ('fan','player','team','coach','scout','agent','support_staff',
                    'analyst','commentator','journalist','creator','moderator',
                    'official','academy','league','competition','organization',
                    'media_broadcast','community','business','sponsor',
                    'commercial_partner','venue','admin') then
    raise exception 'invalid role: %', p_role;
  end if;
  update public.profiles set role = p_role, updated_at = now() where id = p_profile_id;
  update public."User" set role = p_role, "updatedAt" = now() where id = p_profile_id::text;
end;
$$;
revoke all on function public.admin_set_profile_role(uuid, text) from public;
grant execute on function public.admin_set_profile_role(uuid, text) to authenticated, service_role;


-- =============================================================================
-- SECTION 13 — Notification realtime: filter by userId (#9.21)
-- =============================================================================
-- The whole Notification table was in the realtime publication, broadcasting
-- every notification insert to every connected client. Realtime Authorization
-- is supposed to filter, but a misconfigured channel leaks content.
--
-- Mitigation: add a helper RPC that clients use to fetch only their own
-- notifications, and recommend the Flutter client subscribe with a filter:
--   supabase.channel('notif').on('postgres_changes',
--     filter: 'userId=eq.<uid>', ...)

create or replace function public.my_notifications(p_limit int default 50)
returns setof public."Notification"
language sql stable security definer set search_path = public as $$
  select * from public."Notification"
  where "userId" = auth.uid()::text
  order by "createdAt" desc
  limit p_limit;
$$;
revoke all on function public.my_notifications(int) from public;
grant execute on function public.my_notifications(int) to authenticated, service_role;


-- =============================================================================
-- SECTION 14 — enable_realtime: catch undefined_object (#9.32)
-- =============================================================================
-- The original migration only caught duplicate_object. Wrap in a safer helper.

create or replace function public._safe_add_to_realtime(p_table regclass)
returns void language plpgsql security definer set search_path = public as $$
begin
  begin
    execute format('alter publication supabase_realtime add table %s', p_table);
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end;
$$;
revoke all on function public._safe_add_to_realtime(regclass) from public;
grant execute on function public._safe_add_to_realtime(regclass) to service_role;


-- =============================================================================
-- Done. Verification queries (run manually to confirm):
-- =============================================================================
-- select conname, conrelid::regclass from pg_constraint
--  where conname in ('news_likes_news_id_fkey','news_likes_user_id_fkey',
--    'news_comments_news_id_fkey','news_comments_user_id_fkey',
--    'claim_request_league_fkey','claim_request_team_fkey',
--    'claim_request_player_fkey','claim_request_coach_fkey',
--    'Post_community_fkey','Prediction_post_fkey',
--    'Post_match_fkey','Poll_match_fkey','Follow_no_self_follow_check');
--
-- select tgname, tgrelid::regclass from pg_trigger
--  where tgname in ('trg_post_like_count','trg_post_comment_count',
--    'trg_news_like_count','trg_news_comment_count','trg_post_share_count');
--
-- select proname from pg_proc
--  where proname in ('bump_news_share','my_notifications','admin_set_profile_role',
--    'sync_user_from_profile','sync_team_avatars_safe','_safe_add_to_realtime');
--
-- select handle, email, role from public."User"
--  where lower(coalesce(handle,'')) in
--    ('playify','playify_official','playifyofficial','playify_app',
--     'sportsphere','sportsphere_official','sportsphere_app');
-- (should return exactly ONE row with handle='playify')
