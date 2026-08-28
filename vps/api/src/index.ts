// vps/api/src/index.ts — Playify VPS API
// Data: VPS PostgreSQL (direct pg)
// Auth: Supabase JWT verification only
import { Hono }            from 'hono'
import { cors }            from 'hono/cors'
import { logger }          from 'hono/logger'
import { secureHeaders }   from 'hono/secure-headers'

import { authMiddleware }  from './middleware/auth.js'
import { adminMiddleware } from './middleware/admin.js'

import { healthRouter }    from './routes/health.js'
import { feedRouter }      from './routes/feed.js'
import { mediaRouter }     from './routes/media.js'
import { matchRouter }     from './routes/matches.js'
import { mpesaRouter, mpesaCallbackHandler } from './routes/mpesa.js'
import { fcmRouter }       from './routes/fcm.js'
import { claimsRouter }    from './routes/claims.js'
import { adminRouter }     from './routes/admin.js'
import { aiRouter }        from './routes/ai.js'
import { nearbyRouter }    from './routes/nearby.js'
import { notifRouter }     from './routes/notifications.js'
import { socialRouter }    from './routes/social.js'

const app = new Hono()

// ── Global middleware ─────────────────────────────────────────────────────────
app.use('*', secureHeaders())
app.use('*', logger())
app.use('*', cors({
  origin: (origin) => {
    if (!origin) return null
    const allowed = (Bun.env.ALLOWED_ORIGINS ?? 'https://playifysport.fun')
      .split(',').map(s => s.trim())
    return allowed.includes(origin) ? origin : null
  },
  allowMethods:  ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowHeaders:  ['Content-Type','Authorization','apikey','x-client-info'],
  credentials:   true,
}))

// ── Public routes (no JWT) ────────────────────────────────────────────────────
app.route('/health',   healthRouter)
app.route('/v1/matches', matchRouter)

// M-Pesa callback — Safaricom sends no JWT, verified by BusinessShortCode
app.post('/v1/mpesa/callback', mpesaCallbackHandler)

// ── Auth middleware — all /v1/* ────────────────────────────────────────────────
app.use('/v1/*', authMiddleware)

// ── Authenticated routes ──────────────────────────────────────────────────────
app.route('/v1/feed',          feedRouter)
app.route('/v1/media',         mediaRouter)
app.route('/v1/mpesa',         mpesaRouter)
app.route('/v1/fcm',           fcmRouter)
app.route('/v1/claims',        claimsRouter)
app.route('/v1/nearby',        nearbyRouter)
app.route('/v1/notifications', notifRouter)
app.route('/v1/ai',            aiRouter)
app.route('/v1/social',        socialRouter)

// ── Admin routes (JWT + admin role) ───────────────────────────────────────────
app.use('/v1/admin/*', adminMiddleware)
app.route('/v1/admin', adminRouter)

// ── Error handlers ────────────────────────────────────────────────────────────
app.notFound((c) => c.json({ error: 'Not found' }, 404))
app.onError((err, c) => {
  console.error('[API Error]', err)
  return c.json({ error: err.message ?? 'Internal server error' }, 500)
})

const port = Number(Bun.env.PORT ?? 3000)
console.log(`Playify API running on :${port}`)

export default { port, fetch: app.fetch }
