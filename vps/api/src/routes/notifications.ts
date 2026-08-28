// vps/api/src/routes/notifications.ts
import { Hono } from 'hono'
import { query, execute } from '../lib/db.js'

export const notifRouter = new Hono()

notifRouter.get('/', async (c) => {
  const userId = c.get('userId') as string
  const limit  = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows   = await query(
    `SELECT * FROM public."Notification" WHERE "userId" = $1 ORDER BY "createdAt" DESC LIMIT $2`,
    [userId, limit]
  )
  return c.json({ ok: true, notifications: rows })
})

notifRouter.patch('/:id/read', async (c) => {
  const userId = c.get('userId') as string
  await execute(
    `UPDATE public."Notification" SET "isRead" = true WHERE id = $1 AND "userId" = $2`,
    [c.req.param('id'), userId]
  )
  return c.json({ ok: true })
})

notifRouter.patch('/read-all', async (c) => {
  const userId = c.get('userId') as string
  await execute(
    `UPDATE public."Notification" SET "isRead" = true WHERE "userId" = $1 AND "isRead" = false`,
    [userId]
  )
  return c.json({ ok: true })
})
