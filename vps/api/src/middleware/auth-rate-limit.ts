import type { MiddlewareHandler } from 'hono'
const attempts = new Map<string, { count: number; until: number }>()
export const authRateLimit: MiddlewareHandler = async (c, next) => {
  // Nginx overwrites X-Real-IP; the API binds to loopback only.
  const key = `${c.req.path}:${c.req.header('X-Real-IP') ?? 'local'}`
  const now = Date.now()
  for (const [k, value] of attempts) if (value.until <= now) attempts.delete(k)
  const bucket = attempts.get(key) ?? { count: 0, until: now + 15 * 60_000 }
  if (bucket.count >= 10 || (!attempts.has(key) && attempts.size >= 10000)) {
    c.header('Retry-After', String(Math.max(1, Math.ceil((bucket.until - now) / 1000))))
    return c.json({ error: 'Too many attempts. Please try again later.' }, 429)
  }
  bucket.count++
  attempts.set(key, bucket)
  return next()
}
