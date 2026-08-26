// vps/api/src/index.ts
// Playify VPS API — Bun + Hono
// Sits in front of Supabase for server-side operations:
//   - M-Pesa STK Push + callback (amount always from DB)
//   - FCM push notifications (Firebase service account)
//   - Media upload + compress (Sharp + MinIO/S3)
//   - Feed scoring (personalised, weighted)
//   - Nearby fans (Haversine)
//   - Admin actions (delete user, approve/reject claim)
//   - AI assistant (Anthropic + DeepSeek)
//
// Auth: every protected route reads the Supabase JWT from
//   Authorization: Bearer <supabase_access_token>
// and verifies it via supabase.auth.getUser(token).
// Supabase remains the source of truth for auth + realtime + direct DB reads.

import { Hono }   from 'hono'
import { cors }   from 'hono/cors'
import { logger } from 'hono/logger'
import { secureHeaders } from 'hono/secure-headers'

import { authMiddleware }   from './middleware/auth.js'
import { adminMiddleware }  from './middleware/admin.js'

import { healthRouter }   from './routes/health.js'
import { feedRouter }     from './routes/feed.js'
import { mediaRouter }    from './routes/media.js'
import { matchRouter }    from './routes/matches.js'
import { mpesaRouter }    from './routes/mpesa.js'
import { fcmRouter }      from './routes/fcm.js'
import { claimsRouter }   from './routes/claims.js'
import { adminRouter }    from './routes/admin.js'
import { aiRouter }       from './routes/ai.js'
import { nearbyRouter }   from './routes/nearby.js'
import { notifRouter }    from './routes/notifications.js'

const app = new Hono()

// ── Global middleware ────────────────────────────────────────────────────────
app.use('*', secureHeaders())
app.use('*', logger())
app.use('*', cors({
  origin: (origin) => {
    const allowed = (Bun.env.ALLOWED_ORIGINS ?? 'https://app.playify.app')
      .split(',').map(s => s.trim())
    // Flutter mobile doesn't send Origin — allow null/empty
    if (!origin) return '*'
    return allowed.includes(origin) ? origin : ''
  },
  allowMethods:  ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowHeaders:  ['Content-Type', 'Authorization', 'apikey', 'x-client-info'],
  credentials:   true,
}))

// ── Public routes (no JWT required) ─────────────────────────────────────────
app.route('/health',           healthRouter)
app.route('/v1/matches',       matchRouter)   // public read (matches, standings)
app.route('/v1/mpesa/callback', mpesaRouter)  // Safaricom callback — verified by shortcode

// ── Authenticated routes (Supabase JWT required) ─────────────────────────────
app.use('/v1/*', authMiddleware)

app.route('/v1/feed',          feedRouter)
app.route('/v1/media',         mediaRouter)
app.route('/v1/mpesa',         mpesaRouter)
app.route('/v1/fcm',           fcmRouter)
app.route('/v1/claims',        claimsRouter)
app.route('/v1/nearby',        nearbyRouter)
app.route('/v1/notifications', notifRouter)
app.route('/v1/ai',            aiRouter)

// ── Admin routes (Supabase JWT + admin role required) ────────────────────────
app.use('/v1/admin/*', adminMiddleware)
app.route('/v1/admin', adminRouter)

// ── 404 ──────────────────────────────────────────────────────────────────────
app.notFound((c) => c.json({ error: 'Not found' }, 404))
app.onError((err, c) => {
  console.error('[API Error]', err)
  return c.json({ error: err.message ?? 'Internal server error' }, 500)
})

const port = Number(Bun.env.PORT ?? 3000)
console.log(`Playify API running on :${port}`)

export default { port, fetch: app.fetch }
