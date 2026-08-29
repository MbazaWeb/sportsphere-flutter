import { broadcast } from './realtime.js'
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
  const [users, posts, players, news, matches, teams, coaches, leagues] = await Promise.all([
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."User"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Post"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Player"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."NewsItem"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Match"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Team"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."Coach"`),
    queryOne<{count:string}>(`SELECT COUNT(*) as count FROM public."League"`),
  ])
  return c.json({ ok: true, stats: {
    users:        Number(users?.count   ?? 0),
    posts:        Number(posts?.count   ?? 0),
    players:      Number(players?.count ?? 0),
    news:         Number(news?.count    ?? 0),
    matches:      Number(matches?.count ?? 0),
    teams:        Number(teams?.count   ?? 0),
    coaches:      Number(coaches?.count ?? 0),
    competitions: Number(leagues?.count ?? 0),
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
  // Broadcast score update to all connected clients instantly
  const updated = await queryOne(`SELECT * FROM public."Match" WHERE id=$1`, [id])
  if (updated) {
    await broadcast('public:matches', 'score.updated', updated)
    await broadcast('public:matches', 'match.updated', updated)
  }
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

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN — FULL CRUD FOR ALL ENTITIES
// ══════════════════════════════════════════════════════════════════════════════

// ── USERS ─────────────────────────────────────────────────────────────────────

// POST /v1/admin/users — create user (admin creates on behalf)
adminRouter.post('/users', async (c) => {
  const { email, password, firstName, lastName, handle, role, avatarUrl } =
    await c.req.json<any>()
  if (!email || !password) return c.json({ error: 'email and password required' }, 400)

  const userId     = crypto.randomUUID()
  const hash       = await Bun.password.hash(password, { algorithm: 'bcrypt', cost: 12 })
  const userRole   = role ?? 'fan'
  const finalHandle = ((handle ?? email.split('@')[0]) as string)
    .toLowerCase().replace(/[^a-z0-9_]/g,'').slice(0,30) || 'user'
  const name       = [firstName, lastName].filter(Boolean).join(' ') || finalHandle

  await execute(
    `INSERT INTO public."User"(id,name,email,handle,role,"passwordHash","avatarUrl","emailVerified","registeredAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,true,NOW(),NOW())
     ON CONFLICT(email) DO NOTHING`,
    [userId, name, email.toLowerCase(), finalHandle, userRole, hash, avatarUrl??null]
  )
  await execute(
    `INSERT INTO public.profiles(id,handle,role,first_name,last_name,email,created_at,updated_at)
     VALUES($1::uuid,$2,$3,$4,$5,$6,NOW(),NOW()) ON CONFLICT(id) DO NOTHING`,
    [userId, finalHandle, userRole, firstName??'', lastName??'', email.toLowerCase()]
  )
  return c.json({ ok: true, id: userId, handle: finalHandle }, 201)
})

// PATCH /v1/admin/users/:id/verify
adminRouter.patch('/users/:id/verify', async (c) => {
  const { verified } = await c.req.json<{ verified: boolean }>()
  await execute(`UPDATE public."User" SET "isVerified"=$1,"updatedAt"=NOW() WHERE id=$2`, [verified, c.req.param('id')])
  await execute(`UPDATE public.profiles SET is_verified=$1,updated_at=NOW() WHERE id=$2::uuid`, [verified, c.req.param('id')])
  return c.json({ ok: true })
})

// ── TEAMS ─────────────────────────────────────────────────────────────────────

// POST /v1/admin/teams
adminRouter.post('/teams', async (c) => {
  const b = await c.req.json<any>()
  if (!b.name || !b.country) return c.json({ error: 'name and country required' }, 400)
  const rows = await query(
    `INSERT INTO public."Team"(id,name,slug,"shortName",city,country,"logoUrl","primaryColor",venue,"foundedYear",
       source,verified,"isActive","isClaimable","leagueId","sportId","accountUserId","identity_status",
       description,metadata,"createdAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'admin',true,true,true,$11,$12,$13,$14,$15,'{}'::jsonb,NOW(),NOW())
     ON CONFLICT(slug) DO UPDATE SET name=EXCLUDED.name, "updatedAt"=NOW()
     RETURNING *`,
    [b.id??`team-${Date.now()}`, b.name, b.slug??`${b.name.toLowerCase().replace(/\s+/g,'_')}_${Date.now()}`,
     b.shortName??null, b.city??null, b.country, b.logoUrl??null, b.primaryColor??'#168CFF',
     b.venue??null, b.foundedYear??null, b.leagueId??null, b.sportId??null,
     b.accountUserId??null, b.identity_status??'pending', b.description??null]
  )
  return c.json({ ok: true, team: rows[0] }, 201)
})

// PATCH /v1/admin/teams/:id
adminRouter.patch('/teams/:id', async (c) => {
  const id = c.req.param('id'); const b = await c.req.json<any>()
  const allowed = ['name','slug','shortName','city','country','logoUrl','primaryColor','venue',
    'foundedYear','leagueId','sportId','accountUserId','identity_status','isClaimable',
    'verified','isActive','description']
  const sets: string[] = []; const params: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (allowed.includes(k)) { params.push(v); sets.push(`"${k}"=$${params.length}`) }
  }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(id)
  await execute(`UPDATE public."Team" SET ${sets.join(',')}, "updatedAt"=NOW() WHERE id=$${params.length}`, params)
  return c.json({ ok: true })
})

// DELETE /v1/admin/teams/:id
adminRouter.delete('/teams/:id', async (c) => {
  await execute(`DELETE FROM public."Team" WHERE id=$1`, [c.req.param('id')])
  return c.json({ ok: true })
})

// ── PLAYERS ───────────────────────────────────────────────────────────────────

// GET /v1/admin/players?teamId=&limit=200
adminRouter.get('/players', async (c) => {
  const teamId = c.req.query('teamId')
  const limit  = Math.min(Number(c.req.query('limit')??200),500)
  const rows   = teamId
    ? await query(`SELECT * FROM public."Player" WHERE "teamId"=$1 ORDER BY name LIMIT $2`, [teamId, limit])
    : await query(`SELECT * FROM public."Player" WHERE "isActive"=true ORDER BY name LIMIT $1`, [limit])
  return c.json({ ok: true, players: rows })
})

// POST /v1/admin/players
adminRouter.post('/players', async (c) => {
  const b = await c.req.json<any>()
  if (!b.name || !b.position) return c.json({ error: 'name and position required' }, 400)
  const rows = await query(
    `INSERT INTO public."Player"(id,name,slug,"firstName","lastName",position,nationality,
       "photoUrl","dateOfBirth","heightCm","weightKg","shirtNumber","teamId","leagueId","sportId",
       "accountUserId","isClaimable","identity_status",verified,"isActive",metadata,"createdAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,false,true,'{}'::jsonb,NOW(),NOW())
     ON CONFLICT(slug) DO UPDATE SET name=EXCLUDED.name,"updatedAt"=NOW()
     RETURNING *`,
    [b.id??`player-${Date.now()}`, b.name,
     b.slug??`${b.name.toLowerCase().replace(/\s+/g,'_')}_${Date.now()}`,
     b.firstName??b.name.split(' ')[0], b.lastName??b.name.split(' ').slice(1).join(' '),
     b.position, b.nationality??null, b.photoUrl??null,
     b.dateOfBirth??null, b.heightCm??null, b.weightKg??null, b.shirtNumber??null,
     b.teamId??null, b.leagueId??null, b.sportId??null, b.accountUserId??null,
     b.isClaimable??true, b.identity_status??'pending']
  )
  return c.json({ ok: true, player: rows[0] }, 201)
})

// PATCH /v1/admin/players/:id
adminRouter.patch('/players/:id', async (c) => {
  const id = c.req.param('id'); const b = await c.req.json<any>()
  const allowed = ['name','firstName','lastName','position','nationality','photoUrl',
    'teamId','leagueId','sportId','accountUserId','identity_status','isClaimable',
    'shirtNumber','heightCm','weightKg','dateOfBirth','verified','isActive']
  const sets: string[] = []; const params: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (allowed.includes(k)) { params.push(v); sets.push(`"${k}"=$${params.length}`) }
  }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(id)
  await execute(`UPDATE public."Player" SET ${sets.join(',')}, "updatedAt"=NOW() WHERE id=$${params.length}`, params)
  return c.json({ ok: true })
})

// DELETE /v1/admin/players/:id
adminRouter.delete('/players/:id', async (c) => {
  await execute(`DELETE FROM public."Player" WHERE id=$1`, [c.req.param('id')])
  return c.json({ ok: true })
})

// ── COACHES ───────────────────────────────────────────────────────────────────

// GET /v1/admin/coaches
adminRouter.get('/coaches', async (c) => {
  const limit = Math.min(Number(c.req.query('limit')??200),500)
  const rows  = await query(`SELECT * FROM public."Coach" ORDER BY name LIMIT $1`, [limit])
  return c.json({ ok: true, coaches: rows })
})

// POST /v1/admin/coaches
adminRouter.post('/coaches', async (c) => {
  const b = await c.req.json<any>()
  if (!b.name) return c.json({ error: 'name required' }, 400)
  const rows = await query(
    `INSERT INTO public."Coach"(id,name,slug,"firstName","lastName",nationality,"photoUrl",
       role,"teamId","leagueId","sportId",verified,"isActive",metadata,"createdAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,false,true,'{}'::jsonb,NOW(),NOW())
     ON CONFLICT(slug) DO UPDATE SET name=EXCLUDED.name,"updatedAt"=NOW()
     RETURNING *`,
    [b.id??`coach-${Date.now()}`, b.name,
     b.slug??`${b.name.toLowerCase().replace(/\s+/g,'_')}_${Date.now()}`,
     b.firstName??b.name.split(' ')[0], b.lastName??b.name.split(' ').slice(1).join(' '),
     b.nationality??null, b.photoUrl??null, b.role??'head_coach',
     b.teamId??null, b.leagueId??null, b.sportId??null]
  )
  return c.json({ ok: true, coach: rows[0] }, 201)
})

// PATCH /v1/admin/coaches/:id
adminRouter.patch('/coaches/:id', async (c) => {
  const id = c.req.param('id'); const b = await c.req.json<any>()
  const allowed = ['name','firstName','lastName','nationality','photoUrl','role',
    'teamId','leagueId','sportId','verified','isActive']
  const sets: string[] = []; const params: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (allowed.includes(k)) { params.push(v); sets.push(`"${k}"=$${params.length}`) }
  }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(id)
  await execute(`UPDATE public."Coach" SET ${sets.join(',')}, "updatedAt"=NOW() WHERE id=$${params.length}`, params)
  return c.json({ ok: true })
})

// DELETE /v1/admin/coaches/:id
adminRouter.delete('/coaches/:id', async (c) => {
  await execute(`DELETE FROM public."Coach" WHERE id=$1`, [c.req.param('id')])
  return c.json({ ok: true })
})

// ── LEAGUES / COMPETITIONS ────────────────────────────────────────────────────

// GET /v1/admin/leagues
adminRouter.get('/leagues', async (c) => {
  const limit = Math.min(Number(c.req.query('limit')??200),500)
  const rows  = await query(`SELECT * FROM public."League" ORDER BY name LIMIT $1`, [limit])
  return c.json({ ok: true, leagues: rows })
})

// POST /v1/admin/leagues
adminRouter.post('/leagues', async (c) => {
  const b = await c.req.json<any>()
  if (!b.name) return c.json({ error: 'name required' }, 400)
  const rows = await query(
    `INSERT INTO public."League"(id,name,slug,country,"logoUrl",type,season,
       verified,"isActive",description,metadata,"createdAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,true,true,$8,'{}'::jsonb,NOW(),NOW())
     ON CONFLICT(slug) DO UPDATE SET name=EXCLUDED.name,"updatedAt"=NOW()
     RETURNING *`,
    [b.id??`league-${Date.now()}`, b.name,
     b.slug??`${b.name.toLowerCase().replace(/\s+/g,'_')}_${Date.now()}`,
     b.country??'Tanzania', b.logoUrl??null, b.type??'league',
     b.season??null, b.description??null]
  )
  return c.json({ ok: true, league: rows[0] }, 201)
})

// PATCH /v1/admin/leagues/:id
adminRouter.patch('/leagues/:id', async (c) => {
  const id = c.req.param('id'); const b = await c.req.json<any>()
  const allowed = ['name','slug','country','logoUrl','type','season','description',
    'verified','isActive','accountUserId','identity_status','isClaimable']
  const sets: string[] = []; const params: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (allowed.includes(k)) { params.push(v); sets.push(`"${k}"=$${params.length}`) }
  }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(id)
  await execute(`UPDATE public."League" SET ${sets.join(',')}, "updatedAt"=NOW() WHERE id=$${params.length}`, params)
  return c.json({ ok: true })
})

// DELETE /v1/admin/leagues/:id
adminRouter.delete('/leagues/:id', async (c) => {
  await execute(`DELETE FROM public."League" WHERE id=$1`, [c.req.param('id')])
  return c.json({ ok: true })
})

// ── NEWS ──────────────────────────────────────────────────────────────────────

// GET /v1/admin/news
adminRouter.get('/news', async (c) => {
  const limit = Math.min(Number(c.req.query('limit')??50),200)
  const rows  = await query(`SELECT * FROM public."NewsItem" ORDER BY "createdAt" DESC LIMIT $1`, [limit])
  return c.json({ ok: true, news: rows })
})

// POST /v1/admin/news
adminRouter.post('/news', async (c) => {
  const b = await c.req.json<any>()
  if (!b.title || !b.body) return c.json({ error: 'title and body required' }, 400)
  const rows = await query(
    `INSERT INTO public."NewsItem"(id,title,slug,body,summary,category,source,"imageUrl",
       status,"is_breaking","likeCount","commentCount","shareCount","viewCount","publishedAt","createdAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,'published',$9,0,0,0,0,NOW(),NOW(),NOW()) RETURNING *`,
    [b.id??`news-${Date.now()}`, b.title,
     b.slug??`${b.title.toLowerCase().replace(/\s+/g,'-').replace(/[^a-z0-9-]/g,'')}-${Date.now()}`,
     b.body, b.summary??b.body.slice(0,200), b.category??'updates',
     b.source??'Playify', b.imageUrl??null, b.is_breaking??false]
  )
  return c.json({ ok: true, news: rows[0] }, 201)
})

// DELETE /v1/admin/news/:id
adminRouter.delete('/news/:id', async (c) => {
  await execute(`DELETE FROM public."NewsItem" WHERE id=$1`, [c.req.param('id')])
  return c.json({ ok: true })
})

// ── POSTS (admin) ─────────────────────────────────────────────────────────────

// GET /v1/admin/posts
adminRouter.get('/posts', async (c) => {
  const limit = Math.min(Number(c.req.query('limit')??50),200)
  const rows  = await query(
    `SELECT p.*, u.handle, u.name FROM public."Post" p
     JOIN public."User" u ON u.id=p."userId"
     ORDER BY p."createdAt" DESC LIMIT $1`, [limit]
  )
  return c.json({ ok: true, posts: rows })
})

// DELETE /v1/admin/posts/:id
adminRouter.delete('/posts/:id', async (c) => {
  const id = c.req.param('id')
  await execute(`DELETE FROM public."PostLike" WHERE "postId"=$1`, [id])
  await execute(`DELETE FROM public."PostShare" WHERE "postId"=$1`, [id])
  await execute(`DELETE FROM public."Comment" WHERE "postId"=$1`, [id])
  await execute(`DELETE FROM public."Post" WHERE id=$1`, [id])
  return c.json({ ok: true })
})

// ── ENTITY IDENTITY ───────────────────────────────────────────────────────────
// Creates a User + profiles row for an entity (Team/Player/League)
// so they have a real profile that can be claimed

// POST /v1/admin/entities/identity
adminRouter.post('/entities/identity', async (c) => {
  const { entityType, entityId, displayName, handle, logoUrl } =
    await c.req.json<any>()
  if (!entityType || !entityId || !displayName || !handle) {
    return c.json({ error: 'entityType, entityId, displayName, handle required' }, 400)
  }

  // Generate email: handle@playify.app (internal, not real)
  const email    = `${handle}@entity.playifysport.fun`
  const userId   = crypto.randomUUID()
  const roleMap: Record<string,string> = {
    team:'team', player:'player', league:'league',
    coach:'coach', venue:'venue', competition:'league'
  }
  const role = roleMap[entityType] ?? entityType

  try {
    // Create User row (no password — can only be accessed via claim)
    await execute(
      `INSERT INTO public."User"(id,name,email,handle,role,"avatarUrl","emailVerified","registeredAt","updatedAt")
       VALUES($1,$2,$3,$4,$5,$6,false,NOW(),NOW())
       ON CONFLICT(email) DO NOTHING`,
      [userId, displayName, email, handle, role, logoUrl??null]
    )

    // Create profiles row
    await execute(
      `INSERT INTO public.profiles(id,handle,role,first_name,email,avatar_url,claim_status,created_at,updated_at)
       VALUES($1::uuid,$2,$3,$4,$5,$6,'unclaimed',NOW(),NOW())
       ON CONFLICT(id) DO NOTHING`,
      [userId, handle, role, displayName, email, logoUrl??null]
    )

    // Link entity to this account — use per-table column sets
    try {
      if (entityType === 'team') {
        await execute(`UPDATE public."Team" SET "accountUserId"=$1,"identity_status"='healthy',"isClaimable"=true,"updatedAt"=NOW() WHERE id=$2`, [userId, entityId])
      } else if (entityType === 'player') {
        await execute(`UPDATE public."Player" SET "accountUserId"=$1,"identity_status"='healthy',"isClaimable"=true,"updatedAt"=NOW() WHERE id=$2`, [userId, entityId])
      } else if (entityType === 'league') {
        // League may not have accountUserId — add it first
        await execute(`ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "accountUserId" text`, [])
        await execute(`ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "identity_status" text DEFAULT 'pending'`, [])
        await execute(`UPDATE public."League" SET "accountUserId"=$1,"identity_status"='healthy',"updatedAt"=NOW() WHERE id=$2`, [userId, entityId])
      } else if (entityType === 'coach') {
        // Coach may not have accountUserId — add it
        await execute(`ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "accountUserId" text`, [])
        await execute(`UPDATE public."Coach" SET "accountUserId"=$1,"updatedAt"=NOW() WHERE id=$2`, [userId, entityId])
      }
    } catch (linkErr) {
      console.warn('[identity] entity link failed (non-fatal):', linkErr)
    }

    return c.json({ ok: true, uid: userId, handle, email })
  } catch (e: any) {
    return c.json({ error: e.message ?? 'Identity creation failed' }, 500)
  }
})

// ── ENTITY COMMUNITY ──────────────────────────────────────────────────────────

// POST /v1/admin/entities/community
adminRouter.post('/entities/community', async (c) => {
  const { entityType, entityId, name, slug, description } = await c.req.json<any>()
  if (!name || !slug) return c.json({ error: 'name and slug required' }, 400)
  const rows = await query(
    `INSERT INTO public."Community"(id,name,description,topic,"memberCount","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,0,NOW())
     ON CONFLICT DO NOTHING RETURNING *`,
    [name, description??null, entityType??'team']
  )
  return c.json({ ok: true, community: rows[0] ?? null })
})

// ── PLAYER STATS ──────────────────────────────────────────────────────────────

// POST /v1/admin/players/:id/stats
adminRouter.post('/players/:id/stats', async (c) => {
  const playerId = c.req.param('id')
  const b = await c.req.json<any>()
  await execute(
    `INSERT INTO public."PlayerMatchStat"(id,"playerId","matchId",season,goals,assists,minutes,"yellowCards","redCards","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,$7,$8,NOW(),NOW())
     ON CONFLICT DO NOTHING`,
    [playerId, b.matchId??null, b.season??'2026/2027',
     b.goals??0, b.assists??0, b.minutesPlayed??90,
     b.yellowCards??0, b.redCards??0]
  )
  return c.json({ ok: true })
})

// ── BULK OPERATIONS ───────────────────────────────────────────────────────────

// POST /v1/admin/bulk/teams
adminRouter.post('/bulk/teams', async (c) => {
  const { rows } = await c.req.json<{ rows: any[] }>()
  let inserted = 0
  for (const r of (rows??[])) {
    try {
      const slug = `${(r.name??'').toLowerCase().replace(/\s+/g,'_')}_${Date.now()}_${inserted}`
      await execute(
        `INSERT INTO public."Team"(id,name,slug,country,city,"leagueId",source,verified,"isActive","isClaimable","createdAt","updatedAt")
         VALUES($1,$2,$3,$4,$5,$6,'admin',true,true,true,NOW(),NOW()) ON CONFLICT(slug) DO NOTHING`,
        [r.id??`team-${Date.now()}-${inserted}`, r.name, r.slug??slug,
         r.country??'Tanzania', r.city??null, r.leagueId??null]
      ); inserted++
    } catch (_) {}
  }
  return c.json({ ok: true, inserted })
})

// POST /v1/admin/bulk/players
adminRouter.post('/bulk/players', async (c) => {
  const { rows } = await c.req.json<{ rows: any[] }>()
  let inserted = 0
  for (const r of (rows??[])) {
    try {
      const slug = `${(r.name??'').toLowerCase().replace(/\s+/g,'_')}_${Date.now()}_${inserted}`
      await execute(
        `INSERT INTO public."Player"(id,name,slug,position,nationality,"teamId","isActive",verified,"isClaimable","createdAt","updatedAt")
         VALUES($1,$2,$3,$4,$5,$6,true,false,true,NOW(),NOW()) ON CONFLICT(slug) DO NOTHING`,
        [r.id??`player-${Date.now()}-${inserted}`, r.name, r.slug??slug,
         r.position??'Forward', r.nationality??null, r.teamId??null]
      ); inserted++
    } catch (_) {}
  }
  return c.json({ ok: true, inserted })
})

// POST /v1/admin/bulk/fixtures
adminRouter.post('/bulk/fixtures', async (c) => {
  const { rows } = await c.req.json<{ rows: any[] }>()
  let inserted = 0
  for (const r of (rows??[])) {
    try {
      await execute(
        `INSERT INTO public."Match"(id,"homeTeam","awayTeam",league,"kickoffAt",status,"homeBadge","awayBadge",season,"createdAt","updatedAt")
         VALUES(gen_random_uuid()::text,$1,$2,$3,$4,'upcoming',$5,$6,$7,NOW(),NOW())`,
        [r.homeTeam, r.awayTeam, r.league??'',
         r.kickoffAt??new Date().toISOString(),
         r.homeBadge??null, r.awayBadge??null, r.season??null]
      ); inserted++
    } catch (_) {}
  }
  return c.json({ ok: true, inserted })
})

// ── RECONCILE ─────────────────────────────────────────────────────────────────

// POST /v1/admin/reconcile — bulk identity creation for all unclaimed entities
adminRouter.post('/reconcile', async (c) => {
  const report: any[] = []
  const tables = [
    { table: 'Team',   type: 'team',   slug: 'slug', name: 'name', logo: 'logoUrl'  },
    { table: 'Player', type: 'player', slug: 'slug', name: 'name', logo: 'photoUrl' },
    { table: 'League', type: 'league', slug: 'slug', name: 'name', logo: 'logoUrl'  },
    { table: 'Coach',  type: 'coach',  slug: 'slug', name: 'name', logo: 'photoUrl' },
  ]
  for (const { table, type, slug: slugCol, name: nameCol, logo } of tables) {
    const rows = await query(
      `SELECT id, "${nameCol}", "${slugCol}", "${logo}", "accountUserId" FROM public."${table}"
       WHERE "accountUserId" IS NULL AND "isActive"=true LIMIT 100`
    )
    for (const row of rows) { const r = row as any;
      const handle = (r[slugCol]??r[nameCol]??'').toLowerCase().replace(/[^a-z0-9_]/g,'').slice(0,30)
      if (!handle || !r.id || !r[nameCol]) continue
      try {
        const email  = `${handle}@entity.playifysport.fun`
        const userId = crypto.randomUUID()
        const role   = type
        await execute(
          `INSERT INTO public."User"(id,name,email,handle,role,"avatarUrl","emailVerified","registeredAt","updatedAt")
           VALUES($1,$2,$3,$4,$5,$6,false,NOW(),NOW()) ON CONFLICT DO NOTHING`,
          [userId, r[nameCol], email, handle, role, r[logo]??null]
        )
        await execute(
          `INSERT INTO public.profiles(id,handle,role,first_name,email,avatar_url,claim_status,created_at,updated_at)
           VALUES($1::uuid,$2,$3,$4,$5,$6,'unclaimed',NOW(),NOW()) ON CONFLICT DO NOTHING`,
          [userId, handle, role, r[nameCol], email, r[logo]??null]
        )
        try {
          if (table === 'League') {
            await execute(`ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "accountUserId" text`, [])
            await execute(`ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "identity_status" text DEFAULT 'pending'`, [])
          } else if (table === 'Coach') {
            await execute(`ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "accountUserId" text`, [])
          }
          await execute(
            `UPDATE public."${table}" SET "accountUserId"=$1,"identity_status"='healthy',"updatedAt"=NOW() WHERE id=$2`,
            [userId, r.id]
          )
        } catch (updateErr) {
          console.warn('[reconcile] link failed:', updateErr)
        }
        report.push({ type, id: r.id, name: r[nameCol], uid: userId, status: 'created' })
      } catch (e: any) {
        report.push({ type, id: r.id, name: r[nameCol], status: 'failed', error: e.message })
      }
    }
  }
  return c.json({ ok: true, reconciled: report.length, report })
})

// ══════════════════════════════════════════════════════════════════════════════
// ADDITIONS — routes the Flutter admin client calls but were previously missing
// ══════════════════════════════════════════════════════════════════════════════

// DELETE /v1/admin/matches/:id — delete a match
adminRouter.delete('/matches/:id', async (c) => {
  const id = c.req.param('id')
  await execute(`DELETE FROM public."Match" WHERE id=$1`, [id])
  await broadcast('public:matches', 'match.updated', { id, deleted: true }).catch(() => {})
  return c.json({ ok: true })
})

// PATCH /v1/admin/news/:id — update a news article
adminRouter.patch('/news/:id', async (c) => {
  const id = c.req.param('id')
  const b  = await c.req.json<any>()
  const sets: string[] = []; const params: unknown[] = []
  const add = (col: string, val: unknown) => { params.push(val); sets.push(`"${col}"=$${params.length}`) }
  if (b.title       !== undefined) add('title', b.title)
  if (b.body        !== undefined) { add('body', b.body); if (b.summary === undefined) add('summary', String(b.body).slice(0, 200)) }
  if (b.summary     !== undefined) add('summary', b.summary)
  if (b.category    !== undefined) add('category', b.category)
  if (b.source      !== undefined) add('source', b.source)
  if (b.imageUrl    !== undefined) add('imageUrl', b.imageUrl)
  if (b.coverUrl    !== undefined) add('imageUrl', b.coverUrl)
  if (b.cover_url   !== undefined) add('imageUrl', b.cover_url)
  if (b.themeColor  !== undefined) add('themeColor', b.themeColor)
  if (b.theme_color !== undefined) add('themeColor', b.theme_color)
  if (b.isBreaking  !== undefined) add('is_breaking', !!b.isBreaking)
  if (b.is_breaking !== undefined) add('is_breaking', !!b.is_breaking)
  if (b.status      !== undefined) { add('status', b.status); if (b.status === 'published') add('publishedAt', new Date()) }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(id)
  const rows = await query(
    `UPDATE public."NewsItem" SET ${sets.join(',')}, "updatedAt"=NOW() WHERE id=$${params.length} RETURNING *`,
    params
  )
  if (!rows.length) return c.json({ error: 'News item not found' }, 404)
  return c.json({ ok: true, news: rows[0] })
})

// GET /v1/admin/role-requests?status=pending — list PRO role requests
adminRouter.get('/role-requests', async (c) => {
  const status = c.req.query('status') ?? 'pending'
  const limit  = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows   = await query(
    `SELECT r.*, p.handle, p.first_name, p.last_name, p.role AS "currentRole"
       FROM public."RoleRequest" r
       LEFT JOIN public.profiles p ON p.id::text = r."userId"
      WHERE r.status=$1
      ORDER BY r."createdAt" ASC LIMIT $2`,
    [status, limit]
  )
  return c.json({ ok: true, requests: rows })
})

// PATCH /v1/admin/role-requests/:id — approve / reject a PRO request
adminRouter.patch('/role-requests/:id', async (c) => {
  const id = c.req.param('id')
  const b  = await c.req.json<any>()
  const status = String(b.status ?? '')
  if (!['approved', 'rejected', 'pending'].includes(status)) {
    return c.json({ error: "status must be 'approved' | 'rejected' | 'pending'" }, 400)
  }
  const req = await queryOne<{ id: string; userId: string; requestedRole: string }>(
    `SELECT id,"userId","requestedRole" FROM public."RoleRequest" WHERE id=$1`, [id]
  )
  if (!req) return c.json({ error: 'Role request not found' }, 404)
  await execute(
    `UPDATE public."RoleRequest" SET status=$1, notes=COALESCE($2, notes), "reviewedAt"=NOW() WHERE id=$3`,
    [status, b.reviewNotes ?? b.notes ?? null, id]
  )
  // On approval, cascade the role to profiles + User (client never writes roles directly)
  if (status === 'approved') {
    const role = String(b.role ?? req.requestedRole)
    await execute(`UPDATE public.profiles SET role=$1 WHERE id::text=$2`, [role, req.userId]).catch(() => {})
    await execute(`UPDATE public."User" SET role=$1 WHERE id=$2`, [role, req.userId]).catch(() => {})
  }
  return c.json({ ok: true })
})
