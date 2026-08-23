-- =============================================================================
-- Scan Report Fixes — 2026-08-23
-- Addresses: C9, C10, H11, H12, M22, plus trigger cleanup
-- =============================================================================

-- -----------------------------------------------------------------------------
-- C10 — Drop duplicate news triggers/functions to fix double-counting
-- -----------------------------------------------------------------------------
-- The DB has TWO INSERT triggers on news_likes and news_comments:
--   1. news_like_count / news_comment_count (INVOKER)      [pre-existing]
--   2. trg_news_like_count / trg_news_comment_count (SECURITY DEFINER) [ours]
-- Each like/comment fires BOTH, incrementing the counter by 2.
-- Fix: drop the old INVOKER triggers + functions, keep only our SECURITY DEFINER ones.

drop trigger if exists news_like_count on public.news_likes;
drop trigger if exists news_comment_count on public.news_comments;
drop function if exists public.news_like_count();
drop function if exists public.news_comment_count();

-- Recount NewsItem counters from scratch (repairs any double-counted data)
update public."NewsItem" n set
  "likeCount"    = (select count(*) from public.news_likes    l where l.news_id    = n.id),
  "commentCount" = (select count(*) from public.news_comments c where c.news_id   = n.id);


-- -----------------------------------------------------------------------------
-- C9 — Restrict User table public read to authenticated only
-- -----------------------------------------------------------------------------
-- Old policy: user_public_read for select using(true) → anon can dump ALL User
-- rows including passwordHash, email, phone, dateOfBirth, etc.
-- New: restrict to authenticated. Anon should never read user data.

drop policy if exists "user_public_read" on public."User";
create policy "user_public_read" on public."User"
  for select to authenticated
  using (true);

-- Also restrict profiles_read to authenticated (was also using(true) for public)
drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles
  for select to authenticated
  using (true);


-- -----------------------------------------------------------------------------
-- H11 — Add FK from User.id to auth.users(id)
-- -----------------------------------------------------------------------------
-- profiles.id has FK to auth.users with CASCADE. User.id (text) does NOT.
-- If a user is deleted from auth, profiles cascades but User is orphaned.

do $$
begin
  -- User.id is text; auth.users.id is uuid. We need a cast.
  -- Create the FK with a text cast via a generated column or a trigger.
  -- Simplest: add a trigger that deletes User when auth.users row is deleted.
  -- (Direct FK with cast is not supported in PostgreSQL.)
  if not exists (
    select 1 from pg_proc where proname = 'cleanup_user_on_auth_delete'
  ) then
    create function public.cleanup_user_on_auth_delete()
    returns trigger language plpgsql security definer set search_path = public as $body$
    begin
      delete from public."User" where id = old.id::text;
      return old;
    end;
    $body$;
  end if;
end $$;

-- Drop existing trigger if any, then create
drop trigger if exists trg_cleanup_user_on_auth_delete on auth.users;
create trigger trg_cleanup_user_on_auth_delete
  after delete on auth.users
  for each row execute function public.cleanup_user_on_auth_delete();


-- -----------------------------------------------------------------------------
-- H12 — Create 23 missing FK indexes for JOIN/CASCADE performance
-- -----------------------------------------------------------------------------
-- These columns have FK constraints but no index, causing seq scans on joins
-- and CASCADE deletes.

create index if not exists "Post_communityId_idx" on public."Post"("communityId") where "communityId" is not null;
create index if not exists "Notification_actorId_idx" on public."Notification"("actorId") where "actorId" is not null;
create index if not exists "Prediction_matchId_idx" on public."Prediction"("matchId") where "matchId" is not null;
create index if not exists "PlayerMatchStat_matchId_idx" on public."PlayerMatchStat"("matchId") where "matchId" is not null;
create index if not exists "ClaimRequest_coachId_idx" on public."ClaimRequest"("coachId") where "coachId" is not null;
create index if not exists "ClaimRequest_playerId_idx" on public."ClaimRequest"("playerId") where "playerId" is not null;
create index if not exists "ClaimRequest_teamId_idx" on public."ClaimRequest"("teamId") where "teamId" is not null;
create index if not exists "Coach_teamId_idx" on public."Coach"("teamId") where "teamId" is not null;
create index if not exists "Coach_sportId_idx" on public."Coach"("sportId") where "sportId" is not null;
create index if not exists "Coach_leagueId_idx" on public."Coach"("leagueId") where "leagueId" is not null;
create index if not exists "Community_createdById_idx" on public."Community"("createdById") where "createdById" is not null;
create index if not exists "League_sportId_idx" on public."League"("sportId") where "sportId" is not null;
create index if not exists "Player_leagueId_idx" on public."Player"("leagueId") where "leagueId" is not null;
create index if not exists "Player_teamId_idx" on public."Player"("teamId") where "teamId" is not null;
create index if not exists "Player_sportId_idx" on public."Player"("sportId") where "sportId" is not null;
create index if not exists "Prediction_userId_idx" on public."Prediction"("userId");
create index if not exists "Team_leagueId_idx" on public."Team"("leagueId") where "leagueId" is not null;
create index if not exists "Team_sportId_idx" on public."Team"("sportId") where "sportId" is not null;
create index if not exists "VerificationRequest_userId_idx" on public."VerificationRequest"("userId");
create index if not exists "news_comments_user_id_idx" on public.news_comments(user_id);
create index if not exists "news_comments_news_id_idx" on public.news_comments(news_id);
create index if not exists "Post_matchId_idx2" on public."Post"("matchId") where "matchId" is not null;
create index if not exists "Poll_matchId_idx2" on public."Poll"("matchId") where "matchId" is not null;


-- -----------------------------------------------------------------------------
-- M22 — Add is_app_admin() guards to SECURITY DEFINER admin RPCs
-- -----------------------------------------------------------------------------
-- admin_set_profile_role, approve_claim, reject_claim — these run as
-- SECURITY DEFINER (service role privileges) but had NO check that the caller
-- is actually an admin.

-- admin_set_profile_role already has the guard (we added it in 20260824010000).
-- approve_claim and reject_claim need it.

create or replace function public.approve_claim(p_claim_id text, p_review_notes text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  claim record;
  target_uid text;
begin
  if not public.is_app_admin() then
    raise exception 'permission denied: admin only';
  end if;
  select * into claim from public."ClaimRequest" where id = p_claim_id;
  if not found then
    raise exception 'claim not found';
  end if;
  update public."ClaimRequest"
    set status = 'approved', "reviewerId" = auth.uid()::text,
        "reviewNotes" = p_review_notes, "reviewedAt" = now()
    where id = p_claim_id;
  -- Promote user role if profile claim
  if claim."profileType" = 'user' and claim."userId" is not null then
    update public.profiles set role = 'admin', is_verified = true, updated_at = now()
      where id = claim."userId"::uuid;
    update public."User" set role = 'admin', "isVerified" = true, "updatedAt" = now()
      where id = claim."userId";
  end if;
  -- Notify the claimant
  insert into public."Notification" ("userId", "type", "body", "actorId", "targetId", "createdAt")
  values (claim."userId", 'claim_approved',
    coalesce(p_review_notes, 'Your profile claim was approved.'),
    auth.uid()::text, p_claim_id, now());
  return jsonb_build_object('id', p_claim_id, 'status', 'approved');
end;
$$;
revoke all on function public.approve_claim(text, text) from public;
grant execute on function public.approve_claim(text, text) to authenticated, service_role;

create or replace function public.reject_claim(p_claim_id text, p_review_notes text default '')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  claim record;
begin
  if not public.is_app_admin() then
    raise exception 'permission denied: admin only';
  end if;
  select * into claim from public."ClaimRequest" where id = p_claim_id;
  if not found then
    raise exception 'claim not found';
  end if;
  update public."ClaimRequest"
    set status = 'rejected', "reviewerId" = auth.uid()::text,
        "reviewNotes" = p_review_notes, "reviewedAt" = now()
    where id = p_claim_id;
  insert into public."Notification" ("userId", "type", "body", "actorId", "targetId", "createdAt")
  values (claim."userId", 'claim_rejected',
    coalesce(p_review_notes, 'Your profile claim was rejected.'),
    auth.uid()::text, p_claim_id, now());
  return jsonb_build_object('id', p_claim_id, 'status', 'rejected');
end;
$$;
revoke all on function public.reject_claim(text, text) from public;
grant execute on function public.reject_claim(text, text) to authenticated, service_role;


-- -----------------------------------------------------------------------------
-- H1 — Atomic poll vote counting RPC
-- -----------------------------------------------------------------------------
-- Old: read totalVotes, +1, write back (TOCTOU race).
-- New: atomic increment via UPDATE ... SET totalVotes = totalVotes + 1

create or replace function public.increment_poll_votes(p_poll_id text, p_user_id text, p_option_index int)
returns void language plpgsql security definer set search_path = public as $$
begin
  -- Insert vote (idempotent via unique constraint)
  insert into public."PollVote" ("pollId", "userId", "optionIndex", "createdAt")
  values (p_poll_id, p_user_id, p_option_index, now())
  on conflict ("pollId", "userId") do nothing;

  -- Atomic recount
  update public."Poll" set "totalVotes" = (
    select count(*) from public."PollVote" where "pollId" = p_poll_id
  ) where id = p_poll_id;
end;
$$;
revoke all on function public.increment_poll_votes(text, text, int) from public;
grant execute on function public.increment_poll_votes(text, text, int) to authenticated, service_role;


-- -----------------------------------------------------------------------------
-- H2 — Atomic community member count RPC
-- -----------------------------------------------------------------------------
create or replace function public.join_community_atomic(p_community_id uuid, p_user_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public."CommunityMember" ("communityId", "userId", "role", "joinedAt")
  values (p_community_id, p_user_id, 'member', now())
  on conflict ("communityId", "userId") do nothing;

  update public."Community" set "memberCount" = (
    select count(*) from public."CommunityMember" where "communityId" = p_community_id
  ) where id = p_community_id;
end;
$$;
revoke all on function public.join_community_atomic(uuid, text) from public;
grant execute on function public.join_community_atomic(uuid, text) to authenticated, service_role;

create or replace function public.leave_community_atomic(p_community_id uuid, p_user_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public."CommunityMember"
    where "communityId" = p_community_id and "userId" = p_user_id;

  update public."Community" set "memberCount" = (
    select count(*) from public."CommunityMember" where "communityId" = p_community_id
  ) where id = p_community_id;
end;
$$;
revoke all on function public.leave_community_atomic(uuid, text) from public;
grant execute on function public.leave_community_atomic(uuid, text) to authenticated, service_role;


-- -----------------------------------------------------------------------------
-- H3 — confirmOrderPaid ownership check RPC
-- -----------------------------------------------------------------------------
create or replace function public.confirm_order_paid(p_order_id text, p_provider_ref text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  -- Only the order owner or an admin can mark it paid
  if not exists (
    select 1 from public."ShopOrder"
    where id = p_order_id and "userId" = auth.uid()::text
  ) and not public.is_app_admin() then
    raise exception 'permission denied: not order owner';
  end if;

  update public."ShopOrder"
    set status = 'paid',
        "paymentRef" = coalesce(p_provider_ref, "paymentRef"),
        "updatedAt" = now()
    where id = p_order_id;
end;
$$;
revoke all on function public.confirm_order_paid(text, text) from public;
grant execute on function public.confirm_order_paid(text, text) to authenticated, service_role;


-- -----------------------------------------------------------------------------
-- Done. Verification queries:
-- -----------------------------------------------------------------------------
-- -- C10: should show only trg_news_* triggers, no news_* triggers
-- select tgname from pg_trigger where tgrelid = 'public.news_likes'::regclass;
-- select tgname from pg_trigger where tgrelid = 'public.news_comments'::regclass;
--
-- -- C9: user_public_read should be for authenticated, not public
-- select polname, polroles from pg_policy where polrelid = 'public."User"'::regclass;
--
-- -- H12: count of indexes on FK columns
-- select count(*) from pg_indexes where indexname like '%_idx' and schemaname = 'public';
--
-- -- M22: approve_claim should have is_app_admin guard
-- select prosrc from pg_proc where proname = 'approve_claim';
