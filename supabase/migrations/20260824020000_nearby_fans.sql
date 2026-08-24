-- Add location fields to profiles for Nearby Fans feature
alter table public.profiles
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision,
  add column if not exists location_updated_at timestamptz;

-- Index for geo queries
create index if not exists profiles_location_idx
  on public.profiles (latitude, longitude)
  where latitude is not null and longitude is not null;

-- Allow users to update their own location
create policy "profiles_update_own_location"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);
