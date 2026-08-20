
-- Keep User + profiles aligned; backfill gaps

-- Ensure profiles can be read for handle resolution
-- Backfill User from profiles
insert into public."User" (
  "id","name","email","handle","role","bio","isVerified","createdAt","updatedAt"
)
select
  p.id::text,
  coalesce(nullif(trim(coalesce(p.first_name,'') || ' ' || coalesce(p.last_name,'')), ''), p.handle, p.id::text),
  coalesce(nullif(p.email, ''), p.id::text || '@users.local'),
  coalesce(nullif(p.handle, ''), left(replace(p.id::text, '-', ''), 10)),
  coalesce(p.role, 'fan'),
  coalesce(p.bio, ''),
  false,
  now(),
  now()
from public.profiles p
where not exists (select 1 from public."User" u where u.id = p.id::text)
on conflict ("id") do update set
  "handle" = excluded."handle",
  "email" = excluded."email",
  "name" = excluded."name",
  "role" = excluded."role",
  "updatedAt" = now();

-- Backfill profiles from User where missing
insert into public.profiles (id, handle, role, first_name, last_name, email, bio)
select
  u.id::uuid,
  u.handle,
  u.role,
  split_part(u.name, ' ', 1),
  nullif(trim(substr(u.name, length(split_part(u.name, ' ', 1)) + 1)), ''),
  u.email,
  coalesce(u.bio, '')
from public."User" u
where u.id ~ '^[0-9a-f-]{36}$'
  and not exists (select 1 from public.profiles p where p.id::text = u.id)
on conflict (id) do nothing;
