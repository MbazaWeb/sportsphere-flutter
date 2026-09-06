// vps/api/src/routes/realtime.ts
// Soketi channel authentication + server-side broadcast helper
// Soketi uses the Pusher protocol for private/presence channel auth.

import { Hono } from 'hono'
import { channelSignature, canAccessChannel } from '../lib/channel-auth.js'
import { authMiddleware } from '../middleware/auth.js'
import { query } from '../lib/db.js'

export const realtimeRouter = new Hono()
realtimeRouter.use('*', authMiddleware)


// ── POST /v1/realtime/auth ─────────────────────────────────────────────────────
// Called by the Flutter Pusher client to authenticate private/presence channels.
// Requires a valid VPS JWT (userId set by authMiddleware).
realtimeRouter.post('/auth', async (c) => {
  const userId       = c.get('userId') as string
  const body         = await c.req.parseBody()
  const socketId     = body['socket_id']    as string | undefined
  const channelName  = body['channel_name'] as string | undefined

  if (!socketId || !channelName) {
    return c.json({ error: 'socket_id and channel_name required' }, 400)
  }

  if (!canAccessChannel(channelName, userId)) return c.json({ error: 'Forbidden: channel access denied' }, 403)
  return c.json({ auth: channelSignature(socketId, channelName) })
})

// ── Broadcast helper — uses global registry set by index.ts ──────────────────
// index.ts sets globalThis.__wsBroadcast after creating the inline WS handler
export function broadcast(channel: string, event: string, data: unknown): Promise<void> {
  try {
    const fn = (globalThis as any).__wsBroadcast
    if (fn) fn(channel, event, data)
  } catch (e) {
    console.warn('[WS] broadcast failed:', e)
  }
  return Promise.resolve()
}

// ── GET /v1/realtime/status ────────────────────────────────────────────────────
realtimeRouter.get('/status', (c) => {
  const fn = (globalThis as any).__wsStats
  return c.json({ ok: true, ws: fn ? fn() : { connections: 0, channels: {} } })
})
