// vps/api/src/routes/matches.ts — direct PostgreSQL
import { Hono } from 'hono'
import { query } from '../lib/db.js'

export const matchRouter = new Hono()

const LIVE  = ['live','in_play','ht','1h','2h','Live','HT']
const DONE  = ['ft','finished','full time','FT','Finished']

const liveIn  = LIVE.map((_,i) => `$${i+1}`).join(',')
const doneIn  = DONE.map((_,i) => `$${i+1}`).join(',')

matchRouter.get('/live', async (c) => {
  const rows = await query(
    `SELECT * FROM public."Match" WHERE status = ANY($1) ORDER BY "kickoffAt"`,
    [LIVE]
  )
  return c.json({ ok: true, matches: rows })
})

matchRouter.get('/today', async (c) => {
  const rows = await query(
    `SELECT * FROM public."Match"
     WHERE "kickoffAt" >= DATE_TRUNC('day', NOW())
       AND "kickoffAt" <  DATE_TRUNC('day', NOW()) + INTERVAL '1 day'
     ORDER BY "kickoffAt"`,
    []
  )
  return c.json({ ok: true, matches: rows })
})

matchRouter.get('/upcoming', async (c) => {
  const limit  = Math.min(Number(c.req.query('limit')  ?? 200), 1000)
  const offset = Number(c.req.query('offset') ?? 0)
  const from   = c.req.query('from')  // optional: ISO date filter from
  const to     = c.req.query('to')    // optional: ISO date filter to
  const league = c.req.query('league') ?? ''

  let sql = `SELECT * FROM public."Match"
     WHERE "kickoffAt" > NOW()
       AND status NOT IN ('ft','finished','full time','FT','Finished','cancelled')`
  const params: unknown[] = []

  if (from) { params.push(from); sql += ` AND "kickoffAt" >= $${params.length}` }
  if (to)   { params.push(to);   sql += ` AND "kickoffAt" <= $${params.length}` }
  if (league) { params.push(league); sql += ` AND league ILIKE $${params.length}` }

  params.push(limit, offset)
  sql += ` ORDER BY "kickoffAt" ASC LIMIT $${params.length-1} OFFSET $${params.length}`

  const rows = await query(sql, params)
  return c.json({ ok: true, matches: rows, limit, offset })
})

matchRouter.get('/results', async (c) => {
  const limit  = Math.min(Number(c.req.query('limit')  ?? 200), 1000)
  const offset = Number(c.req.query('offset') ?? 0)
  const from   = c.req.query('from')   // optional: ISO date filter from
  const to     = c.req.query('to')     // optional: ISO date filter to
  const league = c.req.query('league') ?? ''

  let sql = `SELECT * FROM public."Match" WHERE status = ANY($1)`
  const params: unknown[] = [DONE]

  if (from)   { params.push(from);   sql += ` AND "kickoffAt" >= $${params.length}` }
  if (to)     { params.push(to);     sql += ` AND "kickoffAt" <= $${params.length}` }
  if (league) { params.push(league); sql += ` AND league ILIKE $${params.length}` }

  params.push(limit, offset)
  sql += ` ORDER BY "kickoffAt" DESC LIMIT $${params.length-1} OFFSET $${params.length}`

  const rows = await query(sql, params)
  return c.json({ ok: true, matches: rows, limit, offset })
})

matchRouter.get('/standings', async (c) => {
  const league = c.req.query('league') ?? ''
  const rows   = await query(
    `SELECT * FROM public."Match" WHERE league = $1 AND status = ANY($2) ORDER BY "kickoffAt" DESC`,
    [league, DONE]
  )
  const table: Record<string, {p:number,w:number,d:number,l:number,gf:number,ga:number}> = {}
  for (const m of rows as any[]) {
    for (const [team,gs,gc] of [[m.homeTeam,m.homeScore??0,m.awayScore??0],[m.awayTeam,m.awayScore??0,m.homeScore??0]] as [string,number,number][]) {
      table[team] ??= {p:0,w:0,d:0,l:0,gf:0,ga:0}
      table[team].p++; table[team].gf+=gs; table[team].ga+=gc
      if (gs>gc) table[team].w++; else if (gs===gc) table[team].d++; else table[team].l++
    }
  }
  const standings = Object.entries(table)
    .map(([team,s])=>({team,...s,pts:s.w*3+s.d,gd:s.gf-s.ga}))
    .sort((a,b)=>b.pts-a.pts||b.gd-a.gd||b.gf-a.gf)
    .map((r,i)=>({...r,pos:i+1}))
  return c.json({ ok: true, standings })
})

// GET /v1/matches/all?limit=200
matchRouter.get('/all', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 200), 500)
  const rows  = await query(
    `SELECT * FROM public."Match" ORDER BY "kickoffAt" DESC LIMIT $1`, [limit]
  )
  return c.json({ ok: true, matches: rows })
})

// GET /v1/matches/leagues?sport= — distinct league names filtered by sport
matchRouter.get('/leagues', async (c) => {
  const sport = (c.req.query('sport') ?? c.req.query('sportSlug') ?? '').trim().toLowerCase()
  let rows: { league: string }[]
  if (sport && sport !== 'all' && sport !== 'football') {
    // Non-football sport: check if we have matches for it
    rows = await query<{ league: string }>(
      `SELECT DISTINCT league FROM public."Match"
       WHERE league IS NOT NULL AND league != ''
         AND (LOWER("sportSlug") = $1 OR LOWER("sport_slug") = $1)
       ORDER BY league`,
      [sport]
    )
  } else if (sport === '' || sport === 'football' || sport === 'all') {
    // Default: football or no filter
    rows = await query<{ league: string }>(
      `SELECT DISTINCT league FROM public."Match"
       WHERE league IS NOT NULL AND league != ''
       ORDER BY league`
    )
  } else {
    rows = []
  }
  return c.json({ ok: true, leagues: rows.map((r: any) => r.league) })
})

// GET /v1/matches/:id
matchRouter.get('/:id', async (c) => {
  const rows = await query(`SELECT * FROM public."Match" WHERE id = $1`, [c.req.param('id')])
  if (!rows.length) return c.json({ error: 'Match not found' }, 404)
  return c.json({ ok: true, match: rows[0] })
})
