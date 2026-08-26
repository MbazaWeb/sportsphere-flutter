// vps/api/src/index.ts
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
import { mpesaRouter, mpesaCallbackHandler } from './routes/mpesa.js'
import { fcmRouter }      from './routes/fcm.js'
import { claimsRouter }   from './routes/claims.js'
import { adminRouter }    from './routes/admin.js'
import { aiRouter }       from './routes/ai.js'
import { nearbyRouter }   from './routes/nearby.js'
import { notifRouter }    from './routes/notifications.js'

const app = new Hono()

// ── Global middleware ─────────────────────────────────────────────────────────
app.use('*', secureHeaders())
app.use('*', logger())
app.use('*', cors({
  origin: (origin) => {
    // Flutter mobile sends no Origin header — allow it
    if (!origin) return null   // null = no ACAO header, fine for non-browser clients
    const allowed = (Bun.env.ALLOWED_ORIGINS ?? 'https://app.playify.app')
      .split(',').map(s => s.trim())
    return allowed.includes(origin) ? origin : null
  },
  allowMethods:  ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowHeaders:  ['Content-Type', 'Authorization', 'apikey', 'x-client-info'],
  credentials:   true,
}))

// ── Public routes (NO JWT) ────────────────────────────────────────────────────
app.route('/health',               healthRouter)
app.route('/v1/matches',           matchRouter)   // public: live scores, standings

// Safaricom callback — public, no JWT, verified by BusinessShortCode inside handler
// Registered BEFORE the /v1/* auth middleware so it is NOT protected
app.post('/v1/mpesa/callback', mpesaCallbackHandler)

// ── Auth middleware — all /v1/* except the callback above ────────────────────
app.use('/v1/*', authMiddleware)

// ── Authenticated routes ──────────────────────────────────────────────────────
app.route('/v1/feed',          feedRouter)
app.route('/v1/media',         mediaRouter)
app.route('/v1/mpesa',         mpesaRouter)   // /v1/mpesa/stk goes here
app.route('/v1/fcm',           fcmRouter)
app.route('/v1/claims',        claimsRouter)
app.route('/v1/nearby',        nearbyRouter)
app.route('/v1/notifications', notifRouter)
app.route('/v1/ai',            aiRouter)

// ── Admin routes (JWT + admin role) ──────────────────────────────────────────
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
