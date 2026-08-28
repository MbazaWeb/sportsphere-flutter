// vps/api/src/middleware/admin.ts
import type { MiddlewareHandler } from 'hono'
import { isAdmin } from '../lib/supabase.js'

export const adminMiddleware: MiddlewareHandler = async (c, next) => {
  const userId = c.get('userId') as string | undefined
  if (!userId) return c.json({ error: 'Unauthenticated' }, 401)
  const ok = await isAdmin(userId)
  if (!ok) return c.json({ error: 'Forbidden: admin role required' }, 403)
  return next()
}
