// vps/api/src/routes/realtime.ts
// Soketi channel authentication + server-side broadcast helper
// Soketi uses the Pusher protocol for private/presence channel auth.

import { Hono } from 'hono'
import { createHmac } from 'crypto'
import { query } from '../lib/db.js'

export const realtimeRouter = new Hono()


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

  // Validate channel access
  if (channelName.startsWith('private:user-')) {
    // Only allow auth if the channel belongs to this user
    const channelUserId = channelName.replace('private:user-', '')
    if (channelUserId !== userId) {
      return c.json({ error: 'Forbidden: channel not yours' }, 403)
    }
  } else if (channelName.startsWith('private:chat-')) {
    // Allow if user is participant in this thread
    // thread id format: chat-{userId1}-{userId2} sorted
    const parts = channelName.replace('private:chat-', '').split('-')
    if (!parts.includes(userId)) {
      return c.json({ error: 'Forbidden: not a participant' }, 403)
    }
  } else if (channelName.startsWith('presence:')) {
    // Allow all authenticated users in presence channels
  } else if (!channelName.startsWith('public:')) {
    return c.json({ error: 'Unknown channel type' }, 400)
  }

  // Generate Pusher-compatible auth signature
  const toSign = `${socketId}:${channelName}`
  const auth   = `${SOKETI_APP_KEY}:${createHmac('sha256', SOKETI_SECRET).update(toSign).digest('hex')}`

  // For presence channels, include user data
  const channelData = channelName.startsWith('presence:')
    ? JSON.stringify({ user_id: userId })
    : undefined

  return c.json({ auth, ...(channelData ? { channel_data: channelData } : {}) })
})

// ── Broadcast helper — in-process WebSocket broadcast ────────────────────────
import { broadcastToChannel } from '../lib/pusher_ws.js'

export function broadcast(channel: string, event: string, data: unknown): Promise<void> {
  try {
    broadcastToChannel(channel, event, data)
  } catch (e) {
    console.warn('[WS] broadcast failed:', e)
  }
  return Promise.resolve()
}

// ── GET /v1/realtime/status ────────────────────────────────────────────────────
realtimeRouter.get('/status', async (c) => {
  const { getStats } = await import('../lib/pusher_ws.js')
  return c.json({ ok: true, ws: getStats() })
})
