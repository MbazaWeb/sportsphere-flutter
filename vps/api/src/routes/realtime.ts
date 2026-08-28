// vps/api/src/routes/realtime.ts
// Soketi channel authentication + server-side broadcast helper
// Soketi uses the Pusher protocol for private/presence channel auth.

import { Hono } from 'hono'
import { createHmac } from 'crypto'
import { query } from '../lib/db.js'

export const realtimeRouter = new Hono()

const SOKETI_APP_ID  = Bun.env.SOKETI_APP_ID  ?? 'playify-app'
const SOKETI_APP_KEY = Bun.env.SOKETI_APP_KEY  ?? 'playify-app-key'
const SOKETI_SECRET  = Bun.env.SOKETI_SECRET   ?? 'playify-secret'
const SOKETI_HOST    = Bun.env.SOKETI_HOST     ?? 'localhost'
const SOKETI_PORT    = Number(Bun.env.SOKETI_PORT ?? 6001)

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

// ── Broadcast helper — used internally by other routes ─────────────────────────
export async function broadcast(channel: string, event: string, data: unknown) {
  try {
    const body = JSON.stringify({
      name:     event,
      channels: [channel],
      data:     JSON.stringify(data),
    })
    const timestamp  = Math.floor(Date.now() / 1000).toString()
    const bodyMd5    = Bun.hash(body).toString(16).padStart(32,'0')
    const toSign     = `POST\n/apps/${SOKETI_APP_ID}/events\n` +
      `auth_key=${SOKETI_APP_KEY}&auth_timestamp=${timestamp}&auth_version=1.0&body_md5=${bodyMd5}`
    const signature  = createHmac('sha256', SOKETI_SECRET).update(toSign).digest('hex')
    const url = `http://${SOKETI_HOST}:${SOKETI_PORT}/apps/${SOKETI_APP_ID}/events?` +
      `auth_key=${SOKETI_APP_KEY}&auth_timestamp=${timestamp}&auth_version=1.0&body_md5=${bodyMd5}&auth_signature=${signature}`

    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    })
  } catch (e) {
    // Non-fatal — clients fall back to polling
    console.warn('[Soketi] broadcast failed:', e)
  }
}

// ── GET /v1/realtime/status ────────────────────────────────────────────────────
realtimeRouter.get('/status', async (c) => {
  try {
    const res = await fetch(`http://${SOKETI_HOST}:${SOKETI_PORT}/apps/${SOKETI_APP_ID}/channels`, {
      headers: { 'Content-Type': 'application/json' }
    })
    const data = await res.json()
    return c.json({ ok: true, soketi: data })
  } catch (e) {
    return c.json({ ok: false, error: String(e) })
  }
})
