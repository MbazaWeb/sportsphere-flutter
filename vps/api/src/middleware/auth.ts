// vps/api/src/middleware/auth.ts
import type { MiddlewareHandler } from 'hono'
import { verifyToken } from '../lib/supabase.js'

export const authMiddleware: MiddlewareHandler = async (c, next) => {
  const header = c.req.header('Authorization') ?? ''
  const token  = header.replace(/^Bearer\s+/i, '').trim()

  if (!token) {
    return c.json({ error: 'Missing Authorization header' }, 401)
  }

  const user = await verifyToken(token)
  if (!user) {
    return c.json({ error: 'Invalid or expired token' }, 401)
  }

  // Attach to context for downstream handlers
  c.set('userId',    user.id)
  c.set('userEmail', user.email ?? '')
  c.set('token',     token)

  return next()
}
