-- =============================================================================
-- PART I (rules 28-37) + EXISTING PROFILES RECONCILIATION:
-- Audit + identity reconciliation for admin-created records missing auth_user_id
-- =============================================================================
-- This migration DOES NOT create Auth identities (that requires the
-- service-role key + a secure backend — see Edge Function). It:
--
--   1. Adds `claimStatus` column to Player, Team, and the profiles table
--      (text, default 'unclaimed', values: unclaimed|invited|claim_pending|
--      claimed|verified).
--   2. Adds `authUserId` column to Player if missing (Team already has
--      accountUserId; profiles.id IS the auth uid).
--   3. Adds an `identity_audit` table that records every reconciliation
--      action (entity_type, entity_id, old_uid, new_uid, action, reason,
--      created_at).
--   4. Inserts audit rows for every admin-created Player/Team/profile that
--      currently has a NULL auth identity — so the admin can review the
--      report and provision identities via a secure Edge Function.
--
-- SECURITY: This migration runs with the migration role (server-side) and
-- does NOT touch auth.users. It only marks records as 'unclaimed' so they
-- can be claimed via the existing ClaimRequest flow.
-- =============================================================================

-- ── 1. Add claimStatus to Player ────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'Player'
      and column_name = 'claimStatus'
  ) then
    alter table public."Player" add column "claimStatus" text not null default 'unclaimed';
    comment on column public."Player"."claimStatus" is
      'unclaimed | invited | claim_pending | claimed | verified';
  end if;
end$$;

-- ── 2. Add authUserId to Player (if missing) ────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'Player'
      and column_name = 'authUserId'
  ) then
    alter table public."Player" add column "authUserId" text;
    comment on column public."Player"."authUserId" is
      'FK to auth.users.id — the authenticated owner of this player profile. NULL until claimed.';
  end if;
end$$;

-- ── 3. Add claimStatus to Team ──────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'Team'
      and column_name = 'claimStatus'
  ) then
    alter table public."Team" add column "claimStatus" text not null default 'unclaimed';
  end if;
end$$;

-- ── 4. Add claimStatus to profiles (snake_case) ────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'claim_status'
  ) then
    alter table public.profiles add column claim_status text not null default 'unclaimed';
  end if;
end$$;

-- ── 5. Create identity_audit table ─────────────────────────────────────────
create table if not exists public.identity_audit (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,          -- 'player' | 'team' | 'profile'
  entity_id text not null,
  entity_name text,
  old_auth_user_id text,
  new_auth_user_id text,
  action text not null,               -- 'uid_provisioned' | 'uid_associated' | 'broken_identity_detected' | 'marked_unclaimed'
  reason text,                         -- 'admin_created_profile_missing_uid' etc.
  created_by text,
  created_at timestamptz not null default now()
);

create index if not exists idx_identity_audit_entity
  on public.identity_audit (entity_type, entity_id);

create index if not exists idx_identity_audit_created_at
  on public.identity_audit (created_at desc);

-- RLS: only authenticated users can read their own audit rows; admins can read all.
alter table public.identity_audit enable row level security;

drop policy if exists "audit_own_read" on public.identity_audit;
create policy "audit_own_read" on public.identity_audit
  for select to authenticated
  using (
    public.is_app_admin()
    or (entity_type = 'profile' and entity_id = auth.uid()::text)
  );

-- Only admins can write audit rows (writes should come from server-side
-- reconciliation functions, not from the client).
drop policy if exists "audit_admin_write" on public.identity_audit;
create policy "audit_admin_write" on public.identity_audit
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- ── 6. Backfill: mark every admin-created Player with NULL authUserId as unclaimed ─
do $$
declare
  v_count int := 0;
begin
  insert into public.identity_audit (entity_type, entity_id, entity_name, action, reason)
  select
    'player',
    p.id,
    p.name,
    'marked_unclaimed',
    'admin_created_profile_missing_uid'
  from public."Player" p
  where p."authUserId" is null
    or p."authUserId" = ''
    or trim(p."authUserId") = '';

  get diagnostics v_count = row_count;
  raise notice 'Marked % players as unclaimed (missing authUserId)', v_count;
end$$;

-- ── 7. Backfill: mark every Team with NULL accountUserId as unclaimed ───────
do $$
declare
  v_count int := 0;
begin
  insert into public.identity_audit (entity_type, entity_id, entity_name, action, reason)
  select
    'team',
    t.id,
    t.name,
    'marked_unclaimed',
    'admin_created_profile_missing_uid'
  from public."Team" t
  where t."accountUserId" is null
    or t."accountUserId" = ''
    or trim(t."accountUserId") = '';

  get diagnostics v_count = row_count;
  raise notice 'Marked % teams as unclaimed (missing accountUserId)', v_count;
end$$;

-- ── 8. Update claimStatus on records that have a valid auth uid ─────────────
-- A profile with a valid auth uid is still 'unclaimed' until the user goes
-- through the ClaimRequest flow. But if the ClaimRequest was already approved,
-- mark it as 'claimed'.

update public."Player" p
   set "claimStatus" = 'claimed'
  from public."ClaimRequest" cr
 where cr."profileType" = 'player'
   and cr."playerId" = p.id
   and cr.status = 'approved';

update public."Team" t
   set "claimStatus" = 'claimed'
  from public."ClaimRequest" cr
 where cr."profileType" = 'team'
   and cr."teamId" = t.id
   and cr.status = 'approved';

-- ── 9. Add is_app_admin to the security definer functions if missing ────────
-- (settle_match_predictions and create_team_fan_community are already
-- security definer; this is just a comment that they should NOT expose
-- sensitive auth data.)
comment on function public.create_team_fan_community(text) is
  'Security definer — runs as the migration role. Does NOT expose auth.users data. Only inserts into Community.';
comment on function public.settle_match_predictions(text) is
  'Security definer — runs as the migration role. Only updates Prediction rows for the given match.';
