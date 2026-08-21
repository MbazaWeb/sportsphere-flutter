-- ============================================================
-- GRANT ADMIN ACCESS: sportsphere.app@sportsphere.com
-- UID: df104a87-bc0f-421a-a066-06b9d0e48d01
-- ============================================================
-- Run in: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1. Upsert profiles (snake_case, uuid PK)
insert into public.profiles (id, handle, role, first_name, last_name, email, country, bio)
values (
  'df104a87-bc0f-421a-a066-06b9d0e48d01'::uuid,
  'sportsphere_app',
  'admin',
  'SportSphere',
  'Admin',
  'sportsphere.app@sportsphere.com',
  'Tanzania',
  'Official SportSphere platform administrator.'
)
on conflict (id) do update set
  handle = 'sportsphere_app',
  role   = 'admin',
  email  = 'sportsphere.app@sportsphere.com';

-- 2. Upsert "User" (PascalCase, text PK)
insert into public."User" (
  "id", "name", "email", "handle", "role",
  "bio", "isVerified", "updatedAt"
) values (
  'df104a87-bc0f-421a-a066-06b9d0e48d01',
  'SportSphere Admin',
  'sportsphere.app@sportsphere.com',
  'sportsphere_app',
  'admin',
  'Official SportSphere platform administrator.',
  true,
  now()
)
on conflict ("id") do update set
  "name"       = 'SportSphere Admin',
  "handle"     = 'sportsphere_app',
  "role"       = 'admin',
  "isVerified" = true,
  "updatedAt"  = now();

-- 3. Patch auth.users metadata so role appears in JWT
update auth.users
set raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
  'role',   'admin',
  'handle', 'sportsphere_app'
)
where id = 'df104a87-bc0f-421a-a066-06b9d0e48d01';

-- Verify
select
  au.email,
  au.raw_user_meta_data->>'role'   as meta_role,
  au.raw_user_meta_data->>'handle' as meta_handle,
  p.role                           as profiles_role,
  u."role"                         as user_role,
  u."isVerified"
from auth.users au
left join public.profiles p on p.id  = au.id
left join public."User"   u on u."id" = au.id::text
where au.id = 'df104a87-bc0f-421a-a066-06b9d0e48d01';
