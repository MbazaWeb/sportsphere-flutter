-- -----------------------------------------------------------------------------
-- RACE follow-up: fix uuid/text param mismatch on community RPCs.
-- -----------------------------------------------------------------------------
-- The Community.id column is `text` (see 20260819232000_full_app_schema.sql
-- line 161) and seed data uses human-readable IDs like 'com-simba-fans'
-- (see 20260820200100_seed_communities.sql). The original
-- 20260825000000_scan_report_fixes.sql defined join_community_atomic /
-- leave_community_atomic with `p_community_id uuid`, which made every call
-- with a non-uuid-shaped community ID fail with
--   `invalid input syntax for type uuid: "com-simba-fans"`.
--
-- This migration recreates both functions with `p_community_id text` so they
-- accept any community ID (uuid-shaped or human-readable). The function
-- bodies are unchanged — only the param type and the revoke/grant signatures
-- are updated. This is backward-compatible: a uuid string is valid text, so
-- runtime-created communities (whose IDs default to gen_random_uuid()::text)
-- still work.
-- -----------------------------------------------------------------------------

-- Drop the uuid-variant first (idempotent: no error if it doesn't exist).
drop function if exists public.join_community_atomic(uuid, text);
drop function if exists public.leave_community_atomic(uuid, text);

-- Recreate with text param.
create or replace function public.join_community_atomic(p_community_id text, p_user_id text)
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
revoke all on function public.join_community_atomic(text, text) from public;
grant execute on function public.join_community_atomic(text, text) to authenticated, service_role;

create or replace function public.leave_community_atomic(p_community_id text, p_user_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public."CommunityMember"
    where "communityId" = p_community_id and "userId" = p_user_id;

  update public."Community" set "memberCount" = (
    select count(*) from public."CommunityMember" where "communityId" = p_community_id
  ) where id = p_community_id;
end;
$$;
revoke all on function public.leave_community_atomic(text, text) from public;
grant execute on function public.leave_community_atomic(text, text) to authenticated, service_role;
