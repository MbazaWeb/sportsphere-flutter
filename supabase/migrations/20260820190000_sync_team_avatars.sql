
-- Ensure every team has a logo; sync to User + profiles avatars.
-- Default badge: media/teams/default-team.png

update public."Team"
set "logoUrl" = 'https://fffqjbrethogesgghjsn.supabase.co/storage/v1/object/public/media/teams/default-team.png'
where "logoUrl" is null or btrim("logoUrl") = '';

update public."User" u
set "avatarUrl" = t."logoUrl"
from public."Team" t
where t."accountUserId" = u.id
  and t."logoUrl" is not null
  and (u."avatarUrl" is null or u."avatarUrl" is distinct from t."logoUrl");

update public.profiles p
set avatar_url = t."logoUrl"
from public."Team" t
where t."accountUserId" = p.id::text
  and t."logoUrl" is not null
  and (p.avatar_url is null or p.avatar_url is distinct from t."logoUrl");

-- profiles.id may be uuid type — also try uuid cast path
update public.profiles p
set avatar_url = t."logoUrl"
from public."Team" t
where t."accountUserId" = p.id::text
  and t."logoUrl" is not null;
