// vps/api/src/middleware/auth.ts
// Verifies VPS JWT first, falls back to Supabase JWT during migration period
import type { MiddlewareHandler } from 'hono'
import { queryOne } from '../lib/db.js'

const JWT_SECRET = Bun.env.JWT_SECRET ?? ''

async function verifyVpsJwt(token: string): Promise<string | null> {
  if (!JWT_SECRET) return null
  try {
    const { jwtVerify } = await import('jose')
    const { payload } = await jwtVerify(token, new TextEncoder().encode(JWT_SECRET))
    return payload.sub as string ?? null
  } catch {
    return null
  }
}

async function verifySupabaseJwt(token: string): Promise<string | null> {
  try {
    const { verifyToken } = await import('../lib/supabase.js')
    const user = await verifyToken(token)
    return user?.id ?? null
  } catch {
    return null
  }
}

export const authMiddleware: MiddlewareHandler = async (c, next) => {
  const header = c.req.header('Authorization') ?? ''
  const token  = header.replace(/^Bearer\s+/i, '').trim()
  if (!token) return c.json({ error: 'Missing Authorization header' }, 401)

  // Try VPS JWT first (fast — no network call)
  let userId = await verifyVpsJwt(token)

  // Fall back to Supabase JWT (during migration — users still have Supabase tokens)
  if (!userId) {
    userId = await verifySupabaseJwt(token)
  }

  if (!userId) return c.json({ error: 'Invalid or expired token' }, 401)

  c.set('userId', userId)
  c.set('token',  token)
  return next()
}
