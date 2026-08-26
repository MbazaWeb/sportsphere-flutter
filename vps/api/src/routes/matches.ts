// vps/api/src/routes/matches.ts
// GET /v1/matches/live
// GET /v1/matches/today
// GET /v1/matches/upcoming
// GET /v1/matches/results
// GET /v1/matches/standings?league=ligi-kuu-bara
// All public — no JWT required

import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'

export const matchRouter = new Hono()

const LIVE_STATUSES     = ['live','in_play','ht','1h','2h','Live','HT']
const FINISHED_STATUSES = ['ft','finished','full time','FT','Finished']

matchRouter.get('/live', async (c) => {
  const liveOr = LIVE_STATUSES.map(s => `status.eq.${s}`).join(',')
  const { data, error } = await supabaseAdmin
    .from('Match').select('*').or(liveOr).order('kickoffAt')
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, matches: data ?? [] })
})

matchRouter.get('/today', async (c) => {
  const start = new Date(); start.setUTCHours(0,0,0,0)
  const end   = new Date(); end.setUTCHours(23,59,59,999)
  const { data, error } = await supabaseAdmin.from('Match').select('*')
    .gte('kickoffAt', start.toISOString())
    .lte('kickoffAt', end.toISOString())
    .order('kickoffAt')
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, matches: data ?? [] })
})

matchRouter.get('/upcoming', async (c) => {
  const notFinished = FINISHED_STATUSES.map(s => `status.neq.${s}`).join(',')
  const { data, error } = await supabaseAdmin.from('Match').select('*')
    .gte('kickoffAt', new Date().toISOString())
    .order('kickoffAt').limit(100)
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, matches: data ?? [] })
})

matchRouter.get('/results', async (c) => {
  const finishedOr = FINISHED_STATUSES.map(s => `status.eq.${s}`).join(',')
  const { data, error } = await supabaseAdmin.from('Match').select('*')
    .or(finishedOr).order('kickoffAt', { ascending: false }).limit(100)
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ ok: true, matches: data ?? [] })
})

matchRouter.get('/standings', async (c) => {
  const league = c.req.query('league') ?? ''
  const { data, error } = await supabaseAdmin.from('Match').select('*')
    .eq('league', league).order('kickoffAt', { ascending: false })
  if (error) return c.json({ error: error.message }, 500)
  // Compute standings from results
  const table: Record<string, { p:number,w:number,d:number,l:number,gf:number,ga:number }> = {}
  for (const m of (data ?? []) as any[]) {
    if (!FINISHED_STATUSES.includes(m.status)) continue
    for (const [team, opp, gs, gc] of [
      [m.homeTeam, m.awayTeam, m.homeScore??0, m.awayScore??0],
      [m.awayTeam, m.homeTeam, m.awayScore??0, m.homeScore??0],
    ] as [string,string,number,number][]) {
      table[team] ??= { p:0,w:0,d:0,l:0,gf:0,ga:0 }
      table[team].p++; table[team].gf += gs; table[team].ga += gc
      if (gs > gc) table[team].w++
      else if (gs === gc) table[team].d++
      else table[team].l++
    }
  }
  const standings = Object.entries(table)
    .map(([team, s]) => ({ team, ...s, pts: s.w*3 + s.d, gd: s.gf - s.ga }))
    .sort((a,b) => b.pts - a.pts || b.gd - a.gd || b.gf - a.gf)
    .map((r,i) => ({ ...r, pos: i + 1 }))
  return c.json({ ok: true, standings })
})
