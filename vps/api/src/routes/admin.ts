// vps/api/src/routes/admin.ts
// All routes here are protected by adminMiddleware (role check already done)
import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'
export const adminRouter = new Hono()

// DELETE /v1/admin/users/:id
adminRouter.delete('/users/:id', async (c) => {
  const callerId = c.get('userId') as string
  const targetId = c.req.param('id')
  if (targetId === callerId) return c.json({ error: 'Cannot delete own account' }, 400)
  const { error } = await supabaseAdmin.auth.admin.deleteUser(targetId)
  if (error) return c.json({ error: error.message }, 500)
  // Cascade cleanup (trigger handles it, this is a fallback)
  await supabaseAdmin.from('User').delete().eq('id', targetId).catch(() => {})
  return c.json({ ok: true, deleted: targetId })
})

// GET /v1/admin/stats
adminRouter.get('/stats', async (c) => {
  const [users, posts, players, news] = await Promise.all([
    supabaseAdmin.from('User').select('*', { count: 'exact', head: true }),
    supabaseAdmin.from('Post').select('*', { count: 'exact', head: true }),
    supabaseAdmin.from('Player').select('*', { count: 'exact', head: true }),
    supabaseAdmin.from('NewsItem').select('*', { count: 'exact', head: true }),
  ])
  return c.json({ ok: true, stats: {
    users:   users.count   ?? 0,
    posts:   posts.count   ?? 0,
    players: players.count ?? 0,
    news:    news.count    ?? 0,
  }})
})

// GET /v1/admin/claims?status=pending
adminRouter.get('/claims', async (c) => {
  const status = c.req.query('status') ?? 'pending'
  const { data, error } = await supabaseAdmin.from('ClaimRequest')
    .select('*').eq('status', status).order('submittedAt', { ascending: false })
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, claims: data ?? [] })
})

// PATCH /v1/admin/users/:id/role
adminRouter.patch('/users/:id/role', async (c) => {
  const userId = c.req.param('id')
  const { role } = await c.req.json<{ role: string }>()
  if (!role) return c.json({ error: 'role required' }, 400)
  const { error } = await supabaseAdmin.rpc('admin_set_profile_role', {
    p_profile_id: userId, p_role: role,
  })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true })
})
