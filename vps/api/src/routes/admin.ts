// vps/api/src/routes/admin.ts — admin routes (JWT + admin role required)
import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'
import { createClient } from '@supabase/supabase-js'

export const adminRouter = new Hono()

// Admin client for user deletion (only admin operation needing Supabase Auth)
function getAdminClient() {
  return createClient(Bun.env.SUPABASE_URL!, Bun.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

// GET /v1/admin/stats
adminRouter.get('/stats', async (c) => {
  const [users, posts, players, news, matches] = await Promise.all([
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."User"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Post"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Player"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."NewsItem"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Match"`),
  ])
  return c.json({ ok: true, stats: {
    users:   Number(users?.count   ?? 0),
    posts:   Number(posts?.count   ?? 0),
    players: Number(players?.count ?? 0),
    news:    Number(news?.count    ?? 0),
    matches: Number(matches?.count ?? 0),
  }})
})

// GET /v1/admin/claims?status=pending
adminRouter.get('/claims', async (c) => {
  const status = c.req.query('status') ?? 'pending'
  const rows   = await query(
    `SELECT * FROM public."ClaimRequest" WHERE status = $1 ORDER BY "submittedAt" DESC`,
    [status]
  )
  return c.json({ ok: true, claims: rows })
})

// GET /v1/admin/users?role=fan&limit=50
adminRouter.get('/users', async (c) => {
  const role   = c.req.query('role')
  const limit  = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const search = c.req.query('search') ?? ''

  let sql = `SELECT id, name, email, handle, role, "isVerified", "registeredAt" FROM public."User"`
  const params: unknown[] = []
  const where: string[] = []

  if (role) { params.push(role); where.push(`role = $${params.length}`) }
  if (search) { params.push(`%${search}%`); where.push(`(handle ILIKE $${params.length} OR email ILIKE $${params.length} OR name ILIKE $${params.length})`) }
  if (where.length) sql += ` WHERE ${where.join(' AND ')}`
  params.push(limit); sql += ` ORDER BY "registeredAt" DESC LIMIT $${params.length}`

  const rows = await query(sql, params)
  return c.json({ ok: true, users: rows })
})

// PATCH /v1/admin/users/:id/role
adminRouter.patch('/users/:id/role', async (c) => {
  const userId = c.req.param('id')
  const { role } = await c.req.json<{role:string}>()
  const valid = ['fan','player','team','coach','scout','agent','analyst','journalist','creator','official','moderator','admin','organization','media_broadcast','sponsor','commercial_partner','venue','academy','league','competition','community','business','support_staff','commentator']
  if (!valid.includes(role)) return c.json({ error: `Invalid role: ${role}` }, 400)

  await execute(`UPDATE public.profiles SET role=$1, updated_at=NOW() WHERE id=$2::uuid`, [role, userId])
  await execute(`UPDATE public."User" SET role=$1, "updatedAt"=NOW() WHERE id=$2`, [role, userId])
  return c.json({ ok: true })
})

// DELETE /v1/admin/users/:id
adminRouter.delete('/users/:id', async (c) => {
  const callerId = c.get('userId') as string
  const targetId = c.req.param('id')
  if (targetId === callerId) return c.json({ error: 'Cannot delete own account' }, 400)

  // Delete from Supabase Auth (only remaining Supabase dependency)
  if (Bun.env.SUPABASE_SERVICE_ROLE_KEY) {
    const { error } = await getAdminClient().auth.admin.deleteUser(targetId)
    if (error) return c.json({ error: error.message }, 500)
  }
  // Cascade cleanup on VPS PostgreSQL
  await execute(`DELETE FROM public."User" WHERE id = $1`, [targetId])
  await execute(`DELETE FROM public.profiles WHERE id = $1::uuid`, [targetId])
  return c.json({ ok: true, deleted: targetId })
})

// GET /v1/admin/matches — list all matches
adminRouter.get('/matches', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows  = await query(`SELECT * FROM public."Match" ORDER BY "kickoffAt" DESC LIMIT $1`, [limit])
  return c.json({ ok: true, matches: rows })
})

// POST /v1/admin/matches — create match
adminRouter.post('/matches', async (c) => {
  const b = await c.req.json<any>()
  const rows = await query(
    `INSERT INTO public."Match"(id,"homeTeam","awayTeam",league,"kickoffAt",status,"homeBadge","awayBadge",season,country,"createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),NOW()) RETURNING *`,
    [b.homeTeam,b.awayTeam,b.league??'',b.kickoffAt??new Date(),b.status??'upcoming',b.homeBadge??null,b.awayBadge??null,b.season??null,b.country??'Tanzania']
  )
  return c.json({ ok: true, match: rows[0] })
})

// PATCH /v1/admin/matches/:id — update match score/status
adminRouter.patch('/matches/:id', async (c) => {
  const id = c.req.param('id')
  const b  = await c.req.json<any>()
  const sets: string[] = []; const params: unknown[] = []
  const add = (col: string, val: unknown) => { params.push(val); sets.push(`"${col}"=$${params.length}`) }
  if (b.homeScore  !== undefined) add('homeScore', b.homeScore)
  if (b.awayScore  !== undefined) add('awayScore', b.awayScore)
  if (b.status     !== undefined) add('status', b.status)
  if (b.minute     !== undefined) add('minute', b.minute)
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(id)
  await execute(`UPDATE public."Match" SET ${sets.join(',')}, "updatedAt"=NOW() WHERE id=$${params.length}`, params)
  return c.json({ ok: true })
})

// GET /v1/admin/teams?limit=200
adminRouter.get('/teams', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 200), 500)
  const rows  = await query(
    `SELECT id, name, "logoUrl", "accountUserId", slug, city, country, "isActive"
     FROM public."Team" WHERE "isActive"=true ORDER BY name LIMIT $1`,
    [limit]
  )
  return c.json({ ok: true, teams: rows })
})

// GET /v1/admin/players/search?q=&limit=20
adminRouter.get('/players/search', async (c) => {
  const q     = c.req.query('q') ?? ''
  const limit = Math.min(Number(c.req.query('limit') ?? 20), 100)
  const rows  = await query(
    `SELECT id, name, slug, "teamId", position
     FROM public."Player"
     WHERE name ILIKE $1 AND "isActive"=true
     ORDER BY name LIMIT $2`,
    [`%${q}%`, limit]
  )
  return c.json({ ok: true, players: rows })
})

// POST /v1/shop/orders — create order (authenticated, non-admin)
