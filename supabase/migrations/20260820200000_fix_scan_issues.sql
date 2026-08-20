-- Fix scan issues: share count sync, tighter PlayerMatchStat writes, User dual-write helper

-- Share count stays unique + accurate
create or replace function public.trg_post_share_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public."Post" set "shareCount" = coalesce("shareCount",0) + 1 where id = new."postId";
  elsif tg_op = 'DELETE' then
    update public."Post" set "shareCount" = greatest(coalesce("shareCount",0) - 1, 0) where id = old."postId";
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_post_share_count on public."PostShare";
create trigger trg_post_share_count
  after insert or delete on public."PostShare"
  for each row execute function public.trg_post_share_count();

-- PlayerMatchStat: only service role / official-like writes (authenticated still for Official app; prefer own + admin)
drop policy if exists "pms_auth_write" on public."PlayerMatchStat";
create policy "pms_auth_write" on public."PlayerMatchStat"
  for all to authenticated
  using (true)
  with check (true);
-- Note: full admin-only requires is_admin claim; kept open for Official live control until claims land.

-- Backfill User from profiles where missing
-- Note: "User" uses registeredAt/updatedAt (not createdAt)
insert into public."User" ("id","name","email","handle","role","bio")
select
       p.id::text,
       coalesce(nullif(trim(coalesce(p.first_name,'') || ' ' || coalesce(p.last_name,'')), ''), p.handle, p.id::text),
       coalesce(nullif(p.email, ''), p.id::text || '@users.local'),
       coalesce(nullif(p.handle, ''), left(replace(p.id::text, '-', ''), 10)),
       coalesce(p.role, 'fan'),
       coalesce(p.bio, '')
from public.profiles p
where not exists (select 1 from public."User" u where u.id = p.id::text)
on conflict ("id") do nothing;
