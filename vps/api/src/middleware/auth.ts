// vps/api/src/middleware/auth.ts
// Verifies VPS JWT (HS256). 
// Supabase fallback kept ONLY during transition — remove after all clients updated.
import type { MiddlewareHandler } from 'hono'

const JWT_SECRET = Bun.env.JWT_SECRET ?? ''

async function verifyVpsJwt(token: string): Promise<string | null> {
  if (!JWT_SECRET) return null
  try {
    const { jwtVerify } = await import('jose')
    const { payload } = await jwtVerify(token, new TextEncoder().encode(JWT_SECRET))
    return (payload.sub as string) ?? null
  } catch {
    return null
  }
}

async function verifySupabaseJwt(token: string): Promise<string | null> {
  // Transition fallback — existing Supabase sessions still work
  // Remove this block once all users have re-logged in with VPS auth
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

  // VPS JWT first (fast — pure local crypto, no network)
  let userId = await verifyVpsJwt(token)

  // Supabase fallback for existing logged-in users (transition period)
  if (!userId) userId = await verifySupabaseJwt(token)

  if (!userId) return c.json({ error: 'Invalid or expired token' }, 401)

  c.set('userId', userId)
  c.set('token',  token)
  return next()
}
