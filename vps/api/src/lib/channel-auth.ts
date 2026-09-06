import { createHmac, timingSafeEqual } from 'crypto'
export const publicChannels = new Set(['public:matches', 'public:feed'])
const uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
export function canAccessChannel(channel: string, userId: string): boolean {
  if (!userId) return false
  if (publicChannels.has(channel)) return true
  if (channel === `private:user-${userId}` || channel === `private-user-${userId}`) return true
  const match = channel.match(new RegExp(`^private[:-]chat-(${uuid})-(${uuid})$`, 'i'))
  return !!match && (match[1] === userId || match[2] === userId)
}
export function channelSignature(socketId: string, channel: string): string {
  const secret = Bun.env.SOKETI_APP_SECRET ?? Bun.env.SOKETI_SECRET ?? Bun.env.JWT_SECRET
  if (!secret) throw new Error('Realtime signing secret is not configured')
  const key = Bun.env.SOKETI_APP_KEY ?? 'playify-app-key'
  return `${key}:${createHmac('sha256', secret).update(`${socketId}:${channel}`).digest('hex')}`
}
export function validSubscription(socketId: string, channel: unknown, auth: unknown): boolean {
  if (typeof channel !== 'string' || channel.length > 200) return false
  if (publicChannels.has(channel)) return true
  if (!/^private[:-](user|chat)-/.test(channel) || typeof auth !== 'string') return false
  const expected = Buffer.from(channelSignature(socketId, channel))
  const provided = Buffer.from(auth)
  return expected.length === provided.length && timingSafeEqual(expected, provided)
}
