// vps/api/src/lib/pusher_ws.ts
// Minimal Pusher-protocol WebSocket server for Bun.
import { createHmac } from 'crypto'

const APP_KEY    = Bun.env.SOKETI_APP_KEY ?? 'playify-app-key'
const APP_SECRET = Bun.env.SOKETI_SECRET  ?? 'playify-secret'

// In-memory state
const channelSockets = new Map<string, Set<string>>()   // channel → socket ids
const socketMap      = new Map<string, any>()            // socketId → ws

function genSocketId(): string {
  return `${Math.floor(Math.random()*999999)}.${Math.floor(Math.random()*999999)}`
}

// ── Public API ────────────────────────────────────────────────────────────────

export function broadcastToChannel(channel: string, event: string, data: unknown, excludeId?: string) {
  const ids = channelSockets.get(channel)
  if (!ids?.size) return
  const msg = JSON.stringify({ event, channel, data: JSON.stringify(data) })
  for (const id of ids) {
    if (id === excludeId) continue
    try { socketMap.get(id)?.send(msg) } catch (_) {}
  }
}

export function getStats() {
  const channels: Record<string, number> = {}
  for (const [ch, ids] of channelSockets) if (ids.size) channels[ch] = ids.size
  return { connections: socketMap.size, channels }
}

export function handlePusherAuth(socketId: string, channel: string, userId?: string): string {
  const toSign = userId && channel.startsWith('private:')
    ? `${socketId}:${channel}`
    : `${socketId}:${channel}`
  const sig  = createHmac('sha256', APP_SECRET).update(toSign).digest('hex')
  const auth = `${APP_KEY}:${sig}`
  if (channel.startsWith('presence:') && userId) {
    const channelData = JSON.stringify({ user_id: userId })
    const sig2 = createHmac('sha256', APP_SECRET)
      .update(`${socketId}:${channel}:${channelData}`).digest('hex')
    return JSON.stringify({ auth: `${APP_KEY}:${sig2}`, channel_data: channelData })
  }
  return JSON.stringify({ auth })
}

// ── Bun WebSocket handler ─────────────────────────────────────────────────────

export const wsHandler = {
  open(ws: any) {
    const socketId = genSocketId()
    ws.data = ws.data ?? {}
    ws.data.socketId  = socketId
    ws.data.channels  = new Set<string>()
    socketMap.set(socketId, ws)
    // Pusher handshake — client expects this immediately after 101
    ws.send(JSON.stringify({
      event: 'pusher:connection_established',
      data:  JSON.stringify({ socket_id: socketId, activity_timeout: 120 }),
    }))
    console.log(`[WS] open  socketId=${socketId} total=${socketMap.size}`)
  },

  message(ws: any, raw: string | Buffer) {
    let msg: any
    try { msg = JSON.parse(raw.toString()) } catch { return }

    switch (msg.event) {
      case 'pusher:ping':
        ws.send(JSON.stringify({ event: 'pusher:pong', data: '{}' }))
        break

      case 'pusher:subscribe': {
        let d: any = {}
        try { d = typeof msg.data === 'string' ? JSON.parse(msg.data) : msg.data } catch {}
        const channel = d.channel as string
        if (!channel) break
        const socketId = ws.data?.socketId as string
        ws.data.channels.add(channel)
        if (!channelSockets.has(channel)) channelSockets.set(channel, new Set())
        channelSockets.get(channel)!.add(socketId)
        ws.send(JSON.stringify({
          event: 'pusher_internal:subscription_succeeded',
          channel,
          data: '{}',
        }))
        console.log(`[WS] sub   channel=${channel} socketId=${socketId}`)
        break
      }

      case 'pusher:unsubscribe': {
        let d: any = {}
        try { d = typeof msg.data === 'string' ? JSON.parse(msg.data) : msg.data } catch {}
        const channel = d.channel as string
        if (!channel) break
        ws.data.channels?.delete(channel)
        channelSockets.get(channel)?.delete(ws.data?.socketId)
        break
      }

      default:
        // Client events (client-*) — relay to other subscribers
        if (msg.event?.startsWith('client-') && msg.channel) {
          broadcastToChannel(msg.channel, msg.event, msg.data ?? {}, ws.data?.socketId)
        }
    }
  },

  close(ws: any) {
    const socketId = ws.data?.socketId as string
    if (!socketId) return
    for (const ch of (ws.data?.channels ?? [])) {
      channelSockets.get(ch)?.delete(socketId)
    }
    socketMap.delete(socketId)
    console.log(`[WS] close socketId=${socketId} total=${socketMap.size}`)
  },

  error(ws: any, err: Error) {
    console.error('[WS] error', err.message)
  },
}
