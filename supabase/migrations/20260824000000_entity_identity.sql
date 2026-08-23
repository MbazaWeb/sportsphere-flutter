-- ═══════════════════════════════════════════════════════════════════════════
-- PLAYIFY ENTITY IDENTITY MIGRATION
-- Every claimable entity (Team, Player, League/Competition) gets:
--   1. accountUserId column  → auth.users.id (uuid)
--   2. isClaimable column    → whether the public can claim it
--   3. identity_status column → 'healthy' | 'pending' | 'flagged'
-- The fans and Follow tables gain entity-level support via entity_follows.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Add identity columns to Team ──────────────────────────────────────────
alter table public."Team"
  add column if not exists "accountUserId" uuid references auth.users(id) on delete set null,
  add column if not exists "isClaimable"   boolean not null default true,
  add column if not exists "identity_status" text not null default 'pending';

create unique index if not exists "Team_accountUserId_idx"
  on public."Team"("accountUserId") where "accountUserId" is not null;

-- ── 2. Add identity columns to Player ────────────────────────────────────────
alter table public."Player"
  add column if not exists "accountUserId" uuid references auth.users(id) on delete set null,
  add column if not exists "isClaimable"   boolean not null default true,
  add column if not exists "identity_status" text not null default 'pending';

create unique index if not exists "Player_accountUserId_idx"
  on public."Player"("accountUserId") where "accountUserId" is not null;

-- ── 3. Add identity columns to League ────────────────────────────────────────
alter table public."League"
  add column if not exists "accountUserId" uuid references auth.users(id) on delete set null,
  add column if not exists "isClaimable"   boolean not null default true,
  add column if not exists "identity_status" text not null default 'pending';

create unique index if not exists "League_accountUserId_idx"
  on public."League"("accountUserId") where "accountUserId" is not null;

-- ── 4. entity_follows — fan/follow for any entity (Team, Player, etc.) ───────
-- Complements the existing fans table (which requires uuid profiles).
-- entity_follows uses the entity's accountUserId as the target.
create table if not exists public.entity_follows (
  id            uuid primary key default gen_random_uuid(),
  follower_id   uuid not null references auth.users(id) on delete cascade,
  entity_type   text not null,   -- 'team' | 'player' | 'league'
  entity_id     text not null,   -- Team.id | Player.id | League.id (text)
  account_uid   uuid,            -- entity.accountUserId at follow time
  is_fan        boolean not null default false,
  created_at    timestamptz not null default now(),
  unique(follower_id, entity_type, entity_id)
);

create index if not exists entity_follows_entity_idx
  on public.entity_follows(entity_type, entity_id);
create index if not exists entity_follows_account_idx
  on public.entity_follows(account_uid);

-- ── 5. entity_communities — auto fan community for each Team ─────────────────
create table if not exists public.entity_communities (
  id          uuid primary key default gen_random_uuid(),
  entity_type text not null default 'team',
  entity_id   text not null unique,
  name        text not null,
  slug        text not null unique,
  description text,
  member_count int not null default 0,
  created_at  timestamptz not null default now()
);

-- ── 6. Reconciliation diagnostic view ────────────────────────────────────────
create or replace view public.entity_identity_report as
  select
    'team'                       as entity_type,
    t."id"                       as entity_id,
    t."name"                     as entity_name,
    t."accountUserId"            as account_uid,
    t."isClaimable"              as is_claimable,
    t."identity_status"          as identity_status,
    (au.id is not null)          as auth_user_exists,
    (p.id is not null)           as profile_exists,
    (ec.id is not null)          as community_exists,
    case
      when t."accountUserId" is null then 'MISSING_IDENTITY'
      when au.id is null             then 'BROKEN_AUTH'
      when p.id is null              then 'MISSING_PROFILE'
      else 'HEALTHY'
    end                          as resolved_status
  from public."Team" t
  left join auth.users au on au.id = t."accountUserId"
  left join public.profiles p  on p.id  = t."accountUserId"
  left join public.entity_communities ec on ec.entity_id = t.id

  union all

  select
    'player'                     as entity_type,
    pl."id"                      as entity_id,
    pl."name"                    as entity_name,
    pl."accountUserId"           as account_uid,
    pl."isClaimable"             as is_claimable,
    pl."identity_status"         as identity_status,
    (au.id is not null)          as auth_user_exists,
    (p.id is not null)           as profile_exists,
    false                        as community_exists,
    case
      when pl."accountUserId" is null then 'MISSING_IDENTITY'
      when au.id is null              then 'BROKEN_AUTH'
      when p.id is null               then 'MISSING_PROFILE'
      else 'HEALTHY'
    end                          as resolved_status
  from public."Player" pl
  left join auth.users au on au.id = pl."accountUserId"
  left join public.profiles p  on p.id  = pl."accountUserId"

  union all

  select
    'league'                     as entity_type,
    l."id"                       as entity_id,
    l."name"                     as entity_name,
    l."accountUserId"            as account_uid,
    l."isClaimable"              as is_claimable,
    l."identity_status"          as identity_status,
    (au.id is not null)          as auth_user_exists,
    (p.id is not null)           as profile_exists,
    false                        as community_exists,
    case
      when l."accountUserId" is null then 'MISSING_IDENTITY'
      when au.id is null             then 'BROKEN_AUTH'
      when p.id is null              then 'MISSING_PROFILE'
      else 'HEALTHY'
    end                          as resolved_status
  from public."League" l
  left join auth.users au on au.id = l."accountUserId"
  left join public.profiles p  on p.id  = l."accountUserId";
