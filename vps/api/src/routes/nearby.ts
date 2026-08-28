// vps/api/src/routes/nearby.ts
import { Hono } from 'hono'
import { query, execute } from '../lib/db.js'

export const nearbyRouter = new Hono()

nearbyRouter.get('/', async (c) => {
  const userId  = c.get('userId') as string
  const lat     = Number(c.req.query('lat'))
  const lng     = Number(c.req.query('lng'))
  const radius  = Number(c.req.query('radius') ?? 50000)
  const limit   = Math.min(Number(c.req.query('limit') ?? 50), 200)
  if (!lat || !lng) return c.json({ error: 'lat and lng required' }, 400)

  const fans = await query(`
    SELECT
      u.id, u.handle, u.name, u."avatarUrl", u.role,
      p.latitude, p.longitude, p."currentCountry" as "currentCountry",
      (6371000.0 * 2.0 * ASIN(SQRT(
        POWER(SIN(RADIANS(p.latitude  - $1) / 2.0), 2) +
        COS(RADIANS($1)) * COS(RADIANS(p.latitude)) *
        POWER(SIN(RADIANS(p.longitude - $2) / 2.0), 2)
      ))) AS distance_m
    FROM public.profiles p
    JOIN public."User" u ON u.id = p.id::text
    WHERE p.latitude IS NOT NULL
      AND p.longitude IS NOT NULL
      AND p.id::text <> $3
      AND (6371000.0 * 2.0 * ASIN(SQRT(
        POWER(SIN(RADIANS(p.latitude  - $1) / 2.0), 2) +
        COS(RADIANS($1)) * COS(RADIANS(p.latitude)) *
        POWER(SIN(RADIANS(p.longitude - $2) / 2.0), 2)
      ))) <= $4
    ORDER BY distance_m ASC
    LIMIT $5
  `, [lat, lng, userId, radius, limit])

  return c.json({ ok: true, fans })
})

nearbyRouter.post('/location', async (c) => {
  const userId = c.get('userId') as string
  const { lat, lng } = await c.req.json<{ lat: number; lng: number }>()
  if (lat == null || lng == null) return c.json({ error: 'lat and lng required' }, 400)
  await execute(
    `UPDATE public.profiles
     SET latitude = $1, longitude = $2, location_updated_at = NOW()
     WHERE id = $3::uuid`,
    [lat, lng, userId]
  )
  return c.json({ ok: true })
})
