-- =============================================================================
-- Add RoleRequest table (PRO verification queue) and Venue table (bulk upload)
-- =============================================================================

-- ── RoleRequest: stores pending PRO role upgrade requests ──────────────────
create table if not exists "RoleRequest" (
  id           text primary key,
  "userId"     uuid not null references auth.users(id) on delete cascade,
  "requestedRole" text not null,
  status       text not null default 'pending'
                 check (status in ('pending','approved','rejected')),
  notes        text,
  "createdAt"  timestamptz not null default now(),
  "reviewedAt" timestamptz,
  constraint role_request_user_role_unique unique ("userId", "requestedRole", status)
);

-- RLS: users can read their own requests; admins can read/update all
alter table "RoleRequest" enable row level security;

create policy "Users can insert own role requests"
  on "RoleRequest" for insert
  with check (auth.uid() = "userId");

create policy "Users can view own role requests"
  on "RoleRequest" for select
  using (auth.uid() = "userId");

-- Admin update policy (is_app_admin function must exist)
do $$
begin
  if exists (
    select 1 from pg_proc where proname = 'is_app_admin'
  ) then
    execute $policy$
      create policy "Admins can manage all role requests"
        on "RoleRequest" for all
        using (is_app_admin())
    $policy$;
  end if;
exception when duplicate_object then null;
end $$;

-- ── Venue table: stadiums and match venues (used by bulk fixture upload) ────
create table if not exists "Venue" (
  id      uuid primary key default gen_random_uuid(),
  name    text not null,
  city    text,
  country text default 'Tanzania',
  capacity int,
  "createdAt" timestamptz default now(),
  constraint venue_name_city_unique unique (name, city)
);

alter table "Venue" enable row level security;

create policy "Anyone can read venues"
  on "Venue" for select using (true);

do $$
begin
  if exists (select 1 from pg_proc where proname = 'is_app_admin') then
    execute $policy$
      create policy "Admins can manage venues"
        on "Venue" for all
        using (is_app_admin())
    $policy$;
  end if;
exception when duplicate_object then null;
end $$;

-- ── Seed common Tanzanian venues ────────────────────────────────────────────
insert into "Venue" (name, city, country, capacity) values
  ('National Stadium',          'Dar es Salaam', 'Tanzania', 60000),
  ('Benjamin Mkapa Stadium',    'Dar es Salaam', 'Tanzania', 60000),
  ('Uhuru Stadium',             'Dar es Salaam', 'Tanzania', 25000),
  ('Azam Complex',              'Dar es Salaam', 'Tanzania', 15000),
  ('Amaan Stadium',             'Zanzibar',      'Tanzania', 15000),
  ('Sokoine Stadium',           'Mbeya',         'Tanzania', 15000),
  ('Jamhuri Stadium',           'Dodoma',        'Tanzania', 15000),
  ('Arusha Stadium',            'Arusha',        'Tanzania', 10000)
on conflict (name, city) do nothing;

-- ── Match table: ensure league column is indexed for standings query ─────────
create index if not exists "Match_league_idx" on "Match" (league);
create index if not exists "Match_status_idx" on "Match" (status);
create index if not exists "Match_kickoff_idx" on "Match" ("kickoff");
