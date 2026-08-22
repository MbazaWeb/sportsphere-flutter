-- Team branding colour used for buttons, borders, accents on team surfaces.
alter table public."Team"
  add column if not exists "primaryColor" text default '#168CFF';

comment on column public."Team"."primaryColor" is 'Hex colour e.g. #E31B23 for team UI accents';
