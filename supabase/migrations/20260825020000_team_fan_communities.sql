-- =============================================================================
-- PART E (rules 14-17): Automatic team fan communities
-- =============================================================================
-- Every team must automatically receive its fan community when the team is
-- created. This migration:
--
--   1. Adds a function that creates a "<TeamName> Fan Community" row in the
--      Community table, linked back to the team via the `teamId` column.
--   2. Adds a trigger that fires AFTER INSERT on "Team" so every new team
--      gets its community automatically — no app code changes needed.
--   3. Backfills existing teams that don't yet have a community.
--   4. Enforces uniqueness on (Community.teamId) so duplicates are impossible
--      at the database level (idempotent re-runs).
-- =============================================================================

-- ── 1. Add teamId column to Community if it doesn't exist ──────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'Community'
      and column_name = 'teamId'
  ) then
    alter table public."Community" add column "teamId" text;
    comment on column public."Community"."teamId" is
      'FK to Team.id — set when this community is the auto-created fan community for a team';
  end if;
end$$;

-- ── 2. Unique constraint so each team has at most one fan community ─────────
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'Community_teamId_unique'
  ) then
    alter table public."Community"
      add constraint "Community_teamId_unique" unique ("teamId");
  end if;
end$$;

-- Add FK from Community.teamId → Team.id (set null on team delete)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'Community_team_fkey'
  ) then
    alter table public."Community"
      add constraint "Community_team_fkey"
      foreign key ("teamId") references public."Team"(id) on delete set null;
  end if;
end$$;

-- ── 3. Function: create_team_fan_community(p_team_id text) ─────────────────
-- Creates a "<TeamName> Fan Community" row linked to the team. Idempotent —
-- if a community for this teamId already exists, returns silently.

create or replace function public.create_team_fan_community(p_team_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_name text;
  v_team_slug text;
  v_community_id text;
  v_existing_id text;
begin
  -- Fetch the team
  select "name", slug into v_team_name, v_team_slug
  from public."Team"
  where id = p_team_id;

  if not found then
    raise notice 'Team % not found — skipping community creation', p_team_id;
    return;
  end if;

  -- Idempotency check: skip if community already exists for this team
  select id into v_existing_id
  from public."Community"
  where "teamId" = p_team_id;

  if v_existing_id is not null then
    raise notice 'Community for team % already exists (%) — skipping',
      p_team_id, v_existing_id;
    return;
  end if;

  -- Generate community id and insert
  v_community_id := 'comm-team-' || v_team_slug;

  insert into public."Community" (id, name, description, topic, "teamId", "createdAt")
  values (
    v_community_id,
    v_team_name || ' Fan Community',
    'Official fan community for ' || v_team_name,
    'team_fan',
    p_team_id,
    now()
  )
  on conflict (id) do nothing;

  raise notice 'Created community % for team % (%)',
    v_community_id, v_team_name, p_team_id;
end;
$$;

-- ── 4. Trigger: auto-create community on Team insert ────────────────────────
drop trigger if exists trg_team_create_fan_community on public."Team";

create trigger trg_team_create_fan_community
  after insert on public."Team"
  for each row
  execute function public.create_team_fan_community(new.id);

-- ── 5. Backfill existing teams ─────────────────────────────────────────────
do $$
declare
  t record;
  v_count int := 0;
begin
  for t in select id from public."Team" loop
    perform public.create_team_fan_community(t.id);
    v_count := v_count + 1;
  end loop;
  raise notice 'Backfill processed % teams', v_count;
end$$;

-- ── 6. Grant execute on the function to authenticated users ─────────────────
-- (so app code or admin RPCs can call it if needed)
grant execute on function public.create_team_fan_community(text) to authenticated;
