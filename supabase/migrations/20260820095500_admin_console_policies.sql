-- Policies so official/admin/organization roles can manage entities from the web console.
-- Mobile users keep existing own-row rules.

-- profiles: officials can read all (for user management lists)
drop policy if exists "admin_read_profiles" on public.profiles;
create policy "admin_read_profiles" on public.profiles
  for select using (
    true
  );

drop policy if exists "admin_update_profiles" on public.profiles;
create policy "admin_update_profiles" on public.profiles
  for update using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
  );

-- Match: allow official update/insert
alter table public."Match" enable row level security;

drop policy if exists "public_read_match" on public."Match";
create policy "public_read_match" on public."Match"
  for select using (true);

drop policy if exists "admin_write_match" on public."Match";
create policy "admin_write_match" on public."Match"
  for all using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
  ) with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
  );

-- Team public read
alter table public."Team" enable row level security;
drop policy if exists "public_read_team" on public."Team";
create policy "public_read_team" on public."Team" for select using (true);

drop policy if exists "admin_write_team" on public."Team";
create policy "admin_write_team" on public."Team"
  for all using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
  ) with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
  );

-- League public read
alter table public."League" enable row level security;
drop policy if exists "public_read_league" on public."League";
create policy "public_read_league" on public."League" for select using (true);

-- Post moderation
alter table public."Post" enable row level security;
drop policy if exists "public_read_post" on public."Post";
create policy "public_read_post" on public."Post" for select using (true);

drop policy if exists "admin_write_post" on public."Post";
create policy "admin_write_post" on public."Post"
  for all using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
    or (auth.uid()::text = "userId")
  ) with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and coalesce(p.role, '') in ('admin', 'official', 'organization')
    )
    or (auth.uid()::text = "userId")
  );

-- Ensure official account has organization role
update public.profiles
set role = 'organization', is_verified = true
where handle = 'sportsphere';
