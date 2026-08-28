// vps/api/src/lib/pusher_ws.ts
// Pure Bun WebSocket server implementing Pusher protocol.
// Replaces Soketi — runs inside the same Bun process, zero external dependency.
// Compatible with pusher_channels_flutter client.

import { createHmac } from 'crypto'

const APP_KEY    = Bun.env.SOKETI_APP_KEY ?? 'playify-app-key'
const APP_SECRET = Bun.env.SOKETI_SECRET  ?? 'playify-secret'

interface WsData {
  socketId:   string
  channels:   Set<string>
}

// Channel → Set of socket IDs
const channelSockets = new Map<string, Set<string>>()
// Socket ID → WebSocket
const socketMap      = new Map<string, ServerWebSocket<WsData>>()

function genSocketId() {
  return `${Math.floor(Math.random()*999999)}.${Math.floor(Math.random()*999999)}`
}

function subscribe(ws: ServerWebSocket<WsData>, channel: string) {
  ws.data.channels.add(channel)
  if (!channelSockets.has(channel)) channelSockets.set(channel, new Set())
  channelSockets.get(channel)!.add(ws.data.socketId)
  ws.send(JSON.stringify({ event: 'pusher_internal:subscription_succeeded', channel, data: '{}' }))
}

function unsubscribe(ws: ServerWebSocket<WsData>, channel: string) {
  ws.data.channels.delete(channel)
  channelSockets.get(channel)?.delete(ws.data.socketId)
}

// Broadcast to all sockets on a channel
export function broadcastToChannel(channel: string, event: string, data: unknown, excludeSocketId?: string) {
  const sockets = channelSockets.get(channel)
  if (!sockets?.size) return
  const msg = JSON.stringify({ event, channel, data: typeof data === 'string' ? data : JSON.stringify(data) })
  for (const sid of sockets) {
    if (sid === excludeSocketId) continue
    socketMap.get(sid)?.send(msg)
  }
}

// HTTP handler for Pusher channel auth (/ws/auth)
export function handlePusherAuth(socketId: string, channelName: string, userId?: string): string {
  if (channelName.startsWith('private:') && userId) {
    const toSign = `${socketId}:${channelName}`
    const auth   = `${APP_KEY}:${createHmac('sha256', APP_SECRET).update(toSign).digest('hex')}`
    return JSON.stringify({ auth })
  }
  if (channelName.startsWith('presence:') && userId) {
    const channelData = JSON.stringify({ user_id: userId })
    const toSign      = `${socketId}:${channelName}:${channelData}`
    const auth        = `${APP_KEY}:${createHmac('sha256', APP_SECRET).update(toSign).digest('hex')}`
    return JSON.stringify({ auth, channel_data: channelData })
  }
  return JSON.stringify({ auth: `${APP_KEY}:public` })
}

// Stats
export function getStats() {
  const channels: Record<string, number> = {}
  for (const [ch, sockets] of channelSockets) channels[ch] = sockets.size
  return { connections: socketMap.size, channels }
}

type ServerWebSocket<T> = Parameters<NonNullable<Parameters<typeof Bun.serve>[0]['websocket']>['open']>[0] & { data: T }

export const wsHandler = {
  open(ws: ServerWebSocket<WsData>) {
    ws.data.socketId = genSocketId()
    ws.data.channels = new Set()
    socketMap.set(ws.data.socketId, ws as any)
    // Pusher connection established event
    ws.send(JSON.stringify({
      event: 'pusher:connection_established',
      data:  JSON.stringify({ socket_id: ws.data.socketId, activity_timeout: 30 }),
    }))
  },

  message(ws: ServerWebSocket<WsData>, raw: string | Buffer) {
    try {
      const msg = JSON.parse(raw.toString()) as { event: string; channel?: string; data?: string }
      switch (msg.event) {
        case 'pusher:ping':
          ws.send(JSON.stringify({ event: 'pusher:pong', data: '{}' }))
          break
        case 'pusher:subscribe': {
          const d       = msg.data ? JSON.parse(msg.data as string) : {}
          const channel = d.channel as string
          if (!channel) break
          subscribe(ws, channel)
          break
        }
        case 'pusher:unsubscribe': {
          const d       = msg.data ? JSON.parse(msg.data as string) : {}
          const channel = d.channel as string
          if (channel) unsubscribe(ws, channel)
          break
        }
        default:
          // Client events: broadcast to channel
          if (msg.event?.startsWith('client-') && msg.channel) {
            broadcastToChannel(msg.channel, msg.event, msg.data ?? {}, ws.data.socketId)
          }
      }
    } catch (_) {}
  },

  close(ws: ServerWebSocket<WsData>) {
    for (const channel of ws.data.channels) {
      channelSockets.get(channel)?.delete(ws.data.socketId)
    }
    socketMap.delete(ws.data.socketId)
  },
}
