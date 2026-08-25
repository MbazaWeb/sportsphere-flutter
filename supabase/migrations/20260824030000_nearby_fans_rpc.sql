-- =============================================================================
-- Nearby Fans — distance calculation + RPC
-- =============================================================================

-- Haversine distance in meters between two lat/lng points
create or replace function public.haversine_meters(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
) returns double precision language sql immutable as $$
  select 6371000.0 * 2.0 * asin(sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2.0), 2) +
    cos(radians(p_lat1)) * cos(radians(p_lat2)) *
    power(sin(radians(p_lng2 - p_lng1) / 2.0), 2)
  ));
$$;

-- Find nearby fans within a radius (meters), optional sport/team filter
-- Returns: id, handle, name, avatarUrl, role, latitude, longitude,
--          distance_m, currentCountry, location
create or replace function public.nearby_fans(
  p_lat double precision,
  p_lng double precision,
  p_radius_m int default 50000,
  p_limit int default 50
) returns table (
  id text,
  handle text,
  name text,
  "avatarUrl" text,
  role text,
  latitude double precision,
  longitude double precision,
  distance_m double precision,
  "currentCountry" text,
  location text
) language sql stable security definer set search_path = public as $$
  select
    u.id,
    u.handle,
    u.name,
    u."avatarUrl",
    u.role,
    p.latitude,
    p.longitude,
    public.haversine_meters(p_lat, p_lng, p.latitude, p.longitude) as distance_m,
    u."currentCountry",
    u.location
  from public.profiles p
  join public."User" u on u.id = p.id::text
  where p.latitude is not null
    and p.longitude is not null
    and p.id::text <> auth.uid()::text
    and public.haversine_meters(p_lat, p_lng, p.latitude, p.longitude) <= p_radius_m
  order by distance_m asc
  limit p_limit;
$$;

revoke all on function public.haversine_meters(double precision, double precision, double precision, double precision) from public;
grant execute on function public.haversine_meters(double precision, double precision, double precision, double precision) to authenticated, service_role;

revoke all on function public.nearby_fans(double precision, double precision, int, int) from public;
grant execute on function public.nearby_fans(double precision, double precision, int, int) to authenticated, service_role;
