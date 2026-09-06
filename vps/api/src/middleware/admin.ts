// vps/api/src/middleware/admin.ts
// Admin check using VPS PostgreSQL.
import type { MiddlewareHandler } from 'hono'
import { queryOne } from '../lib/db.js'

async function isAdmin(userId: string): Promise<boolean> {
  const row = await queryOne<{ role: string }>(
    `SELECT role FROM public.profiles WHERE id = $1`, [userId]
  )
  return ['admin','moderator'].includes(String(row?.role ?? '').toLowerCase())
}

export const adminMiddleware: MiddlewareHandler = async (c, next) => {
  const userId = c.get('userId') as string
  if (!userId) return c.json({ error: 'Unauthorized' }, 401)
  const ok = await isAdmin(userId)
  if (!ok) return c.json({ error: 'Admin access required' }, 403)
  return next()
}
