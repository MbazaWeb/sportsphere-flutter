insert into public.profiles (id, handle, role, first_name, last_name, avatar_url, is_verified, created_at, updated_at)
select u.id::uuid, u.handle, 'team', t.name, '',
       t."logoUrl", true, now(), now()
from public."Team" t
join public."User" u on u.id = t."accountUserId"
where u.id ~* '^[0-9a-f-]{36}$'
on conflict (id) do update set
  handle = excluded.handle,
  role = 'team',
  avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
  is_verified = true;
