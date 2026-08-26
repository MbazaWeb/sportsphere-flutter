// vps/api/src/routes/notifications.ts
import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'
export const notifRouter = new Hono()

// GET  /v1/notifications?limit=50   — own notifications
notifRouter.get('/', async (c) => {
  const userId = c.get('userId') as string
  const limit  = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const { data, error } = await supabaseAdmin.rpc('my_notifications', { p_limit: limit })
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, notifications: data ?? [] })
})

// PATCH /v1/notifications/:id/read
notifRouter.patch('/:id/read', async (c) => {
  const userId = c.get('userId') as string
  const id     = c.req.param('id')
  await supabaseAdmin.from('Notification').update({ isRead: true })
    .eq('id', id).eq('userId', userId)
  return c.json({ ok: true })
})

// PATCH /v1/notifications/read-all
notifRouter.patch('/read-all', async (c) => {
  const userId = c.get('userId') as string
  await supabaseAdmin.from('Notification').update({ isRead: true })
    .eq('userId', userId).eq('isRead', false)
  return c.json({ ok: true })
})
