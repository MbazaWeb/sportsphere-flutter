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
import { newsRouter }     from './routes/news.js'
import { authRouter }     from './routes/auth.js'
import { shopRouter }     from './routes/shop.js'
import { realtimeRouter } from './routes/realtime.js'

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



// News: public read (guests)
app.route('/v1/news', newsRouter)

// Soketi channel auth (requires JWT inside handler)
app.route('/v1/realtime', realtimeRouter)

// M-Pesa callback — Safaricom sends no JWT, verified by BusinessShortCode
app.post('/v1/mpesa/callback', mpesaCallbackHandler)

// ── Public auth routes (no JWT required) ─────────────────────────────────────

// WebSocket stats — internal monitoring (no auth)
app.get('/v1/app/version', (c) => c.json({
  ok: true, version: '1.2.0', versionCode: 4,
  downloadUrl: 'https://playifysport.fun/downloads/playify.apk',
  releaseNotes: 'Bug fixes, improved feed, password reset, community features.',
  forceUpdate: false, minVersionCode: 1,
}))

app.get('/ws/stats', async (c) => {
  return c.json({ ok: true, ...getStats() })
})

// Search: public — guests can search without JWT
app.get('/v1/social/search', async (c) => {
  const { query: dbQuery } = await import('./lib/db.js')
  const q     = (c.req.query('q') ?? '').trim()
  const limit = Math.min(Number(c.req.query('limit') ?? 15), 50)
  if (!q) return c.json({ ok: true, results: [] })
  const pat = `%${q}%`

  const [profiles, leagues, teams, players] = await Promise.all([
    dbQuery(`SELECT id::text, handle, first_name, last_name, role, avatar_url FROM public.profiles WHERE handle ILIKE $1 OR first_name ILIKE $1 OR last_name ILIKE $1 LIMIT $2`, [pat, limit]),
    dbQuery(`SELECT id, name, country, type, season FROM public."League" WHERE name ILIKE $1 OR country ILIKE $1 LIMIT $2`, [pat, Math.floor(limit/3)]),
    dbQuery(`SELECT t.id, t.name, t.country, t.city, t."logoUrl", t."accountUserId" FROM public."Team" t WHERE t.name ILIKE $1 AND t."isActive"=true LIMIT $2`, [pat, Math.floor(limit/3)]),
    dbQuery(`SELECT p.id, p.name, p.position, p.nationality, p."accountUserId" FROM public."Player" p WHERE p.name ILIKE $1 AND p."isActive"=true LIMIT $2`, [pat, Math.floor(limit/3)]),
  ])

  // IDs already covered by profiles (entity accounts)
  const profileIds = new Set((profiles as any[]).map((r: any) => r.id))
  const seen = new Set<string>()
  const out: any[] = []

  const add = (r: any) => {
    const key = `${r.id}|${r.first_name}`
    if (seen.has(key)) return
    seen.add(key); out.push(r)
  }

  for (const r of profiles as any[]) {
    const kind = ['team','league','player','coach','organization'].includes(r.role) ? r.role : 'user'
    add({ ...r, _kind: kind, _subtitle: kind === 'user' ? `@${r.handle}` : r.role })
  }
  const leagueNames = new Set<string>()
  for (const r of leagues as any[]) {
    if (leagueNames.has(r.name)) continue; leagueNames.add(r.name)
    add({ id: r.id, handle: String(r.name||'').toLowerCase().replace(/ /g,'_'), first_name: r.name, last_name: '', role: 'league', avatar_url: null, _kind: 'league', _subtitle: `${r.country||''} · ${r.type||''}` })
  }
  for (const r of teams as any[]) {
    if (r.accountUserId && profileIds.has(r.accountUserId)) continue
    add({ id: r.id, handle: String(r.name||'').toLowerCase().replace(/ /g,'_'), first_name: r.name, last_name: '', role: 'team', avatar_url: r.logoUrl, _kind: 'team', _subtitle: `${r.city||''} · ${r.country||''}` })
  }
  for (const r of players as any[]) {
    if (r.accountUserId && profileIds.has(r.accountUserId)) continue
    add({ id: r.id, handle: String(r.name||'').toLowerCase().replace(/ /g,'_'), first_name: r.name, last_name: '', role: 'player', avatar_url: null, _kind: 'player', _subtitle: `${r.position||''} · ${r.nationality||''}` })
  }

  return c.json({ ok: true, results: out.slice(0, limit) })
})

// ── Auth middleware — all /v1/* EXCEPT public auth endpoints ─────────────────
app.use('/v1/*', async (c, next) => {
  const path = new URL(c.req.url).pathname
  const publicPaths = [
    '/v1/auth/register',
    '/v1/auth/login',
    '/v1/auth/refresh',
    '/v1/auth/forgot-password',
    '/v1/auth/resend-confirmation',
    '/v1/auth/reset-password',
    '/v1/app/version',
    '/v1/auth/otp/send',
    '/v1/auth/verify-identity',
    '/v1/auth/set-password',
    '/v1/feed/trending',
    '/v1/feed',
    '/v1/social/communities',
    '/v1/social/search',
    '/v1/social/sports',
    '/v1/social/polls',
    '/v1/social/predictions',
    '/v1/social/posts',
    '/v1/nearby',
  ]
  // Also allow community membership checks without auth — return {isMember:false}
  if (path.startsWith('/v1/social/communities/') && path.endsWith('/membership')) {
    return next()
  }
  if (path.startsWith('/v1/social/communities/') && path.endsWith('/member')) {
    return next()
  }
  if (publicPaths.includes(path)) return next()
  return authMiddleware(c, next)
})

// ── All auth routes (public ones skip middleware above) ────────────────────────
app.route('/v1/auth', authRouter)

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
app.route('/v1/shop',          shopRouter)
app.route('/v1/realtime',      realtimeRouter)
// news mounted above in public section

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

// ── Inline WebSocket server (Pusher protocol) ────────────────────────────────
// Inlined to avoid module export/import issues with Bun 1.4
const _chSockets = new Map<string, Set<string>>()
const _sockMap   = new Map<string, any>()

function broadcastToChannel(channel: string, event: string, data: unknown, excludeId?: string) {
  const ids = _chSockets.get(channel)
  if (!ids?.size) return
  const msg = JSON.stringify({ event, channel, data: JSON.stringify(data) })
  for (const id of ids) {
    if (id === excludeId) continue
    try { _sockMap.get(id)?.send(msg) } catch (_) {}
  }
}

function getStats() {
  const channels: Record<string,number> = {}
  for (const [ch, ids] of _chSockets) if (ids.size) channels[ch] = ids.size
  return { connections: _sockMap.size, channels }
}

const wsHandler = {
  open(ws: any) {
    const sid = `${Math.floor(Math.random()*999999)}.${Math.floor(Math.random()*999999)}`
    if (!ws.data) ws.data = {}
    ws.data.socketId = sid
    ws.data.channels = new Set<string>()
    _sockMap.set(sid, ws)
    ws.send(JSON.stringify({
      event: 'pusher:connection_established',
      data:  JSON.stringify({ socket_id: sid, activity_timeout: 120 }),
    }))
    console.log(`[WS] open sid=${sid} total=${_sockMap.size}`)
  },
  message(ws: any, raw: string | Buffer) {
    let msg: any
    try { msg = JSON.parse(raw.toString()) } catch { return }
    if (msg.event === 'pusher:ping') {
      ws.send(JSON.stringify({ event: 'pusher:pong', data: '{}' })); return
    }
    if (msg.event === 'pusher:subscribe') {
      let d: any = {}
      try { d = typeof msg.data==='string' ? JSON.parse(msg.data) : msg.data } catch {}
      const ch = d.channel as string; if (!ch) return
      ws.data.channels.add(ch)
      if (!_chSockets.has(ch)) _chSockets.set(ch, new Set())
      _chSockets.get(ch)!.add(ws.data.socketId)
      ws.send(JSON.stringify({ event: 'pusher_internal:subscription_succeeded', channel: ch, data: '{}' }))
      console.log(`[WS] sub ch=${ch} sid=${ws.data.socketId}`)
      return
    }
    if (msg.event === 'pusher:unsubscribe') {
      let d: any = {}
      try { d = typeof msg.data==='string' ? JSON.parse(msg.data) : msg.data } catch {}
      const ch = d.channel as string; if (!ch) return
      ws.data.channels?.delete(ch); _chSockets.get(ch)?.delete(ws.data?.socketId); return
    }
    if (msg.event?.startsWith('client-') && msg.channel) {
      broadcastToChannel(msg.channel, msg.event, msg.data ?? {}, ws.data?.socketId)
    }
  },
  close(ws: any) {
    const sid = ws.data?.socketId as string; if (!sid) return
    for (const ch of (ws.data?.channels ?? [])) _chSockets.get(ch)?.delete(sid)
    _sockMap.delete(sid)
    console.log(`[WS] close sid=${sid} total=${_sockMap.size}`)
  },
}

// Register broadcast functions globally so routes can use them
;(globalThis as any).__wsBroadcast = broadcastToChannel
;(globalThis as any).__wsStats     = getStats

// Bun server: handles HTTP (Hono) + WebSocket (Pusher protocol)
const honoFetch = app.fetch.bind(app)
export default {
  port: 3000,
  async fetch(req: Request, server: any) {
    const path = new URL(req.url).pathname
    // Intercept /app/* — always try WebSocket upgrade first
    if (path.startsWith('/app/')) {
      const ok = server.upgrade(req, { data: { socketId: '', channels: new Set<string>() } })
      if (ok) return undefined
      // Not a WS request — return 404
      return new Response('{"error":"WebSocket endpoint"}', {
        status: 400, headers: { 'Content-Type': 'application/json' }
      })
    }
    return honoFetch(req, server)
  },
  websocket: wsHandler,
}
