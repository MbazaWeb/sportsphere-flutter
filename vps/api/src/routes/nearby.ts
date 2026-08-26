// vps/api/src/routes/nearby.ts
import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'
export const nearbyRouter = new Hono()

nearbyRouter.get('/', async (c) => {
  const userId   = c.get('userId') as string
  const lat      = Number(c.req.query('lat'))
  const lng      = Number(c.req.query('lng'))
  const radius   = Number(c.req.query('radius') ?? 50000)
  const limit    = Math.min(Number(c.req.query('limit') ?? 50), 200)
  if (!lat || !lng) return c.json({ error: 'lat and lng required' }, 400)
  const { data, error } = await supabaseAdmin
    .rpc('nearby_fans', { p_lat: lat, p_lng: lng, p_radius_m: radius, p_limit: limit })
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, fans: data ?? [] })
})

// Update own location
nearbyRouter.post('/location', async (c) => {
  const userId = c.get('userId') as string
  const { lat, lng } = await c.req.json<{ lat: number; lng: number }>()
  if (lat == null || lng == null) return c.json({ error: 'lat and lng required' }, 400)
  await supabaseAdmin.from('profiles').update({
    latitude: lat, longitude: lng,
    location_updated_at: new Date().toISOString(),
  }).eq('id', userId)
  return c.json({ ok: true })
})
