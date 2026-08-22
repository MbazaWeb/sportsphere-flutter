
-- Official identity: handle playify, email playify@playify.com (run after auth email change in dashboard)
update public.profiles
set handle = 'playify',
    role = 'admin',
    is_verified = true
where lower(coalesce(email, '')) in (
  'playify@playify.com',
  'sportsphere.app@sportsphere.com'
)
or lower(coalesce(handle, '')) in (
  'sportsphere', 'sportsphere_app', 'sportsphere_official', 'playify', 'playify_app'
);

update public."User"
set handle = 'playify',
    role = 'admin',
    "isVerified" = true
where lower(coalesce(email, '')) in (
  'playify@playify.com',
  'sportsphere.app@sportsphere.com'
)
or lower(coalesce(handle, '')) in (
  'sportsphere', 'sportsphere_app', 'sportsphere_official', 'playify', 'playify_app'
);
