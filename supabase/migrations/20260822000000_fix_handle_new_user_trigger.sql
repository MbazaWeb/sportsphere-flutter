-- ============================================================
-- FIX: handle_new_user trigger
-- ============================================================
-- Root causes of "Database error saving new user" (HTTP 500):
--
-- 1. profiles.handle has UNIQUE constraint — if a handle is
--    already taken (duplicate attempt, seeded data, partial
--    prior row), the INSERT crashes the entire auth.signUp().
--
-- 2. "User"."location" is inserted but may not exist as a column
--    in all environments, causing a column-not-found error.
--
-- 3. No error handling — any constraint violation aborts signUp.
--
-- Fix: wrap both inserts in EXCEPTION blocks, deduplicate
-- handles with a numeric suffix, and only insert columns that
-- are guaranteed to exist.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  h        text;
  fn       text;
  ln       text;
  role_v   text;
  country_v text;
  display  text;
  suffix   int := 0;
  h_try    text;
begin
  -- ── Parse metadata ──────────────────────────────────────────
  fn        := trim(coalesce(new.raw_user_meta_data->>'first_name', ''));
  ln        := trim(coalesce(new.raw_user_meta_data->>'last_name', ''));
  role_v    := coalesce(new.raw_user_meta_data->>'role', 'fan');
  country_v := coalesce(new.raw_user_meta_data->>'country', 'Tanzania');

  -- Strip leading @ and lowercase the handle
  h := lower(
    regexp_replace(
      coalesce(new.raw_user_meta_data->>'handle', split_part(new.email, '@', 1)),
      '^@+', ''
    )
  );
  -- Remove any characters that are not alphanumeric or underscore
  h := regexp_replace(h, '[^a-z0-9_]', '', 'g');
  -- Ensure handle is not empty
  if h = '' then h := split_part(new.email, '@', 1); end if;

  display := trim(fn || ' ' || ln);
  if display = '' then display := h; end if;

  -- ── Deduplicate handle ──────────────────────────────────────
  -- If 'mbazza' is taken try 'mbazza1', 'mbazza2', etc.
  h_try := h;
  loop
    exit when not exists (
      select 1 from public.profiles where handle = h_try
    );
    suffix := suffix + 1;
    h_try := h || suffix::text;
    exit when suffix > 999; -- safety valve
  end loop;
  h := h_try;

  -- ── Insert into profiles (snake_case table) ─────────────────
  begin
    insert into public.profiles (
      id, handle, role, first_name, last_name,
      email, country, dob, bio
    ) values (
      new.id,
      h,
      role_v,
      fn,
      ln,
      new.email,
      country_v,
      nullif(new.raw_user_meta_data->>'dob', '')::date,
      coalesce(new.raw_user_meta_data->>'bio', '')
    )
    on conflict (id) do update set
      handle     = excluded.handle,
      first_name = excluded.first_name,
      last_name  = excluded.last_name,
      email      = excluded.email,
      country    = excluded.country,
      dob        = coalesce(excluded.dob, profiles.dob),
      updated_at = now();
  exception when others then
    -- Log but never fail signUp because of profiles write
    raise warning '[handle_new_user] profiles insert failed for %: %', new.id, sqlerrm;
  end;

  -- ── Insert into "User" (PascalCase table) ───────────────────
  begin
    insert into public."User" (
      "id", "name", "email", "handle", "role",
      "bio", "currentCountry", "dateOfBirth",
      "emailVerified", "updatedAt"
    ) values (
      new.id::text,
      display,
      new.email,
      h,
      role_v,
      coalesce(new.raw_user_meta_data->>'bio', ''),
      country_v,
      nullif(new.raw_user_meta_data->>'dob', '')::timestamptz,
      coalesce(new.email_confirmed_at is not null, false),
      now()
    )
    on conflict ("id") do update set
      "name"        = excluded."name",
      "email"       = excluded."email",
      "handle"      = excluded."handle",
      "role"        = excluded."role",
      "updatedAt"   = now();
  exception when others then
    -- Log but never fail signUp because of "User" write
    raise warning '[handle_new_user] User insert failed for %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

-- Re-attach trigger (function replaced in place, but be explicit)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
