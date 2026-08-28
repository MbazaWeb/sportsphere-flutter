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
  const rows = await query(
    `SELECT * FROM public."Match"
     WHERE "kickoffAt" > NOW() AND status NOT IN ('ft','finished','full time','FT','Finished')
     ORDER BY "kickoffAt" LIMIT 100`,
    []
  )
  return c.json({ ok: true, matches: rows })
})

matchRouter.get('/results', async (c) => {
  const rows = await query(
    `SELECT * FROM public."Match"
     WHERE status = ANY($1)
     ORDER BY "kickoffAt" DESC LIMIT 100`,
    [DONE]
  )
  return c.json({ ok: true, matches: rows })
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

// GET /v1/matches/:id
matchRouter.get('/:id', async (c) => {
  const rows = await query(`SELECT * FROM public."Match" WHERE id = $1`, [c.req.param('id')])
  if (!rows.length) return c.json({ error: 'Match not found' }, 404)
  return c.json({ ok: true, match: rows[0] })
})

// GET /v1/matches/all?limit=200
matchRouter.get('/all', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 200), 500)
  const rows  = await query(
    `SELECT * FROM public."Match" ORDER BY "kickoffAt" DESC LIMIT $1`, [limit]
  )
  return c.json({ ok: true, matches: rows })
})

// GET /v1/matches/leagues — distinct league names from all matches
matchRouter.get('/leagues', async (c) => {
  const rows = await query<{ league: string }>(
    `SELECT DISTINCT league FROM public."Match"
     WHERE league IS NOT NULL AND league != ''
     ORDER BY league`
  )
  return c.json({ ok: true, leagues: rows.map(r => r.league) })
})
