-- Ensure Team.primaryColor exists (team create was failing without it)
alter table public."Team"
  add column if not exists "primaryColor" text default '#168CFF';

-- Admin write policies (idempotent) for Team / Player / Coach / Match / News
do $$
begin
  -- Team
  alter table public."Team" enable row level security;
  drop policy if exists "admin_write_team" on public."Team";
  create policy "admin_write_team" on public."Team"
    for all to authenticated
    using (public.is_app_admin())
    with check (public.is_app_admin());
  drop policy if exists "public_read_team" on public."Team";
  create policy "public_read_team" on public."Team" for select using (true);

  -- Player
  alter table public."Player" enable row level security;
  drop policy if exists "admin_write_player" on public."Player";
  create policy "admin_write_player" on public."Player"
    for all to authenticated
    using (public.is_app_admin())
    with check (public.is_app_admin());
  drop policy if exists "public_read_player" on public."Player";
  create policy "public_read_player" on public."Player" for select using (true);

  -- Coach
  alter table public."Coach" enable row level security;
  drop policy if exists "admin_write_coach" on public."Coach";
  create policy "admin_write_coach" on public."Coach"
    for all to authenticated
    using (public.is_app_admin())
    with check (public.is_app_admin());
  drop policy if exists "public_read_coach" on public."Coach";
  create policy "public_read_coach" on public."Coach" for select using (true);
exception when others then
  raise notice 'policy setup: %', SQLERRM;
end $$;

-- Live post count helper (counts Post.userId OR authorId)
create or replace function public.count_posts_for_user(p_id text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int from public."Post" p
  where p."userId" = p_id
     or p."authorId" = p_id
     or p.user_id::text = p_id
     or p.author_id::text = p_id;
$$;

grant execute on function public.count_posts_for_user(text) to authenticated, anon, service_role;
