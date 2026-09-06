import { describe, expect, test } from 'bun:test'
import { canAccessChannel, channelSignature, validSubscription } from '../src/lib/channel-auth'
import { Hono } from 'hono'
import { authRateLimit } from '../src/middleware/auth-rate-limit'

describe('private realtime authorization', () => {
  const user = '11111111-1111-4111-8111-111111111111'
  const other = '22222222-2222-4222-8222-222222222222'
  const stranger = '33333333-3333-4333-8333-333333333333'
  test('only channel owners can request signatures', () => {
    expect(canAccessChannel(`private:user-${user}`, user)).toBe(true)
    expect(canAccessChannel(`private:user-${other}`, user)).toBe(false)
    expect(canAccessChannel(`private-user-${user}`, user)).toBe(true)
    expect(canAccessChannel('presence:arbitrary', user)).toBe(false)
    expect(canAccessChannel('public:arbitrary', user)).toBe(false)
  })
  test('chat UUID parsing preserves participant IDs', () => {
    const chat = `private:chat-${user}-${other}`
    expect(canAccessChannel(chat, user)).toBe(true)
    expect(canAccessChannel(chat, other)).toBe(true)
    expect(canAccessChannel(chat, stranger)).toBe(false)
  })
  test('signatures bind to both socket and channel; unsigned private subscriptions fail', () => {
    Bun.env.SOKETI_APP_SECRET = 'test-only-secret'
    const channel = `private:user-${user}`
    const auth = channelSignature('123.456', channel)
    expect(validSubscription('123.456', channel, auth)).toBe(true)
    expect(validSubscription('987.654', channel, auth)).toBe(false)
    expect(validSubscription('123.456', `private:user-${other}`, auth)).toBe(false)
    expect(validSubscription('123.456', channel, undefined)).toBe(false)
    expect(validSubscription('123.456', channel, 'forged')).toBe(false)
    expect(validSubscription('123.456', 'public:matches', undefined)).toBe(true)
    expect(validSubscription('123.456', 'public:feed', undefined)).toBe(true)
    expect(validSubscription('123.456', 'public:secrets', undefined)).toBe(false)
  })
})
test('recovery attempts are limited and clients receive a retry time', async () => {
  const app = new Hono().use('*', authRateLimit).post('/recover', c => c.json({ ok: true }))
  for (let n = 0; n < 10; n++) expect((await app.request('/recover', { method: 'POST' })).status).toBe(200)
  const blocked = await app.request('/recover', { method: 'POST' })
  expect(blocked.status).toBe(429)
  expect(Number(blocked.headers.get('Retry-After'))).toBeGreaterThan(0)
})
