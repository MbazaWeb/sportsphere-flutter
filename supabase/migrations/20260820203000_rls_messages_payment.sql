
-- Admin-oriented PlayerMatchStat write: Official / service only preferred
-- App Official uses authenticated session; tighten to users with role official OR handle sportsphere

drop policy if exists "pms_auth_write" on public."PlayerMatchStat";

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public."User" u
    where u.id = auth.uid()::text
      and (
        lower(u.role) in ('official','admin','moderator')
        or lower(u.handle) in ('sportsphere','sportsphere_official')
      )
  );
$$;

drop policy if exists "pms_admin_write" on public."PlayerMatchStat";
create policy "pms_admin_write" on public."PlayerMatchStat"
  for all to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- Message policies
alter table public."Message" enable row level security;
drop policy if exists "msg_participants_read" on public."Message";
drop policy if exists "msg_auth_send" on public."Message";
drop policy if exists "msg_own_update" on public."Message";
create policy "msg_participants_read" on public."Message"
  for select using (auth.uid()::text = "senderId" or auth.uid()::text = "receiverId");
create policy "msg_auth_send" on public."Message"
  for insert with check (auth.uid()::text = "senderId");
create policy "msg_own_update" on public."Message"
  for update using (auth.uid()::text = "receiverId" or auth.uid()::text = "senderId");

-- Poll write policies
drop policy if exists "poll_auth_create" on public."Poll";
drop policy if exists "poll_public_read" on public."Poll";
create policy "poll_public_read" on public."Poll" for select using (true);
create policy "poll_auth_create" on public."Poll" for insert with check (true);

drop policy if exists "poll_vote_auth" on public."PollVote";
drop policy if exists "poll_vote_public_read" on public."PollVote";
create policy "poll_vote_public_read" on public."PollVote" for select using (true);
create policy "poll_vote_auth" on public."PollVote" for insert with check (auth.uid()::text = "userId");

-- ShopOrder payment columns if missing
do $$ begin
  alter table public."ShopOrder" add column if not exists "paymentMethod" text;
  alter table public."ShopOrder" add column if not exists "paymentRef" text;
exception when others then null;
end $$;
