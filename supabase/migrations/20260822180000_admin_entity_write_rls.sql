
-- Unified admin gate: profiles + User role OR official handles
create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and (
            lower(coalesce(p.role, '')) in ('admin', 'official', 'organization', 'moderator')
            or lower(coalesce(p.handle, '')) in (
              'sportsphere', 'sportsphere_official', 'sportsphere_app',
              'playify', 'playify_official', 'playify_app'
            )
          )
      )
      or exists (
        select 1 from public."User" u
        where u.id = auth.uid()::text
          and (
            lower(coalesce(u.role, '')) in ('admin', 'official', 'organization', 'moderator')
            or lower(coalesce(u.handle, '')) in (
              'sportsphere', 'sportsphere_official', 'sportsphere_app',
              'playify', 'playify_official', 'playify_app'
            )
          )
      )
    );
$$;

grant execute on function public.is_app_admin() to authenticated, anon, service_role;

-- Promote official accounts
update public.profiles
set role = 'admin',
    is_verified = true
where lower(coalesce(handle, '')) in (
  'sportsphere', 'sportsphere_official', 'sportsphere_app',
  'playify', 'playify_official', 'playify_app'
);

update public."User"
set role = 'admin',
    "isVerified" = true,
    "verificationStatus" = 'verified'
where lower(coalesce(handle, '')) in (
  'sportsphere', 'sportsphere_official', 'sportsphere_app',
  'playify', 'playify_official', 'playify_app'
);

-- League: was missing write policy (insert failed for everyone)
alter table public."League" enable row level security;
drop policy if exists "public_read_league" on public."League";
create policy "public_read_league" on public."League" for select using (true);
drop policy if exists "admin_write_league" on public."League";
create policy "admin_write_league" on public."League"
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- Competition
alter table public."Competition" enable row level security;
drop policy if exists competition_public_read on public."Competition";
create policy competition_public_read on public."Competition" for select using (true);
drop policy if exists competition_admin on public."Competition";
create policy competition_admin on public."Competition"
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- Team
drop policy if exists "admin_write_team" on public."Team";
drop policy if exists "team_public" on public."Team";
drop policy if exists "public_read_team" on public."Team";
create policy "public_read_team" on public."Team" for select using (true);
create policy "admin_write_team" on public."Team"
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- Match
drop policy if exists "admin_write_match" on public."Match";
drop policy if exists "public_read_match" on public."Match";
create policy "public_read_match" on public."Match" for select using (true);
create policy "admin_write_match" on public."Match"
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- Player / Coach if tables exist
do $$ begin
  if to_regclass('public."Player"') is not null then
    execute 'alter table public."Player" enable row level security';
    execute 'drop policy if exists public_read_player on public."Player"';
    execute 'create policy public_read_player on public."Player" for select using (true)';
    execute 'drop policy if exists admin_write_player on public."Player"';
    execute 'create policy admin_write_player on public."Player" for all to authenticated using (public.is_app_admin()) with check (public.is_app_admin())';
  end if;
  if to_regclass('public."Coach"') is not null then
    execute 'alter table public."Coach" enable row level security';
    execute 'drop policy if exists public_read_coach on public."Coach"';
    execute 'create policy public_read_coach on public."Coach" for select using (true)';
    execute 'drop policy if exists admin_write_coach on public."Coach"';
    execute 'create policy admin_write_coach on public."Coach" for all to authenticated using (public.is_app_admin()) with check (public.is_app_admin())';
  end if;
end $$;

-- Post admin path still allows author
drop policy if exists "admin_write_post" on public."Post";
create policy "admin_write_post" on public."Post"
  for all to authenticated
  using (public.is_app_admin() or auth.uid()::text = "userId")
  with check (public.is_app_admin() or auth.uid()::text = "userId");
