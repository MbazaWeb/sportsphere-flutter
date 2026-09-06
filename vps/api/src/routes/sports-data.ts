// vps/api/src/routes/sports-data.ts
// External sports-data fetchers + DB upserts.
// Tanzania football (Ligi Kuu Bara) is given HIGH PRIORITY — fetched first,
// never skipped. International leagues follow.
//
// Providers:
//   - football-data.org (free, X-Auth-Token) — fixtures, standings, teams, matches
//   - RapidAPI (multiple hosts via x-rapidapi-key) — predictions, news, transfers,
//     livescore, highlights, head-to-head
//
// All endpoints under /v1/admin/sports-data require admin JWT.

import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'

export const sportsDataRouter = new Hono()

// ─── Config ──────────────────────────────────────────────────────────────
const FD_TOKEN    = Bun.env.FOOTBALL_DATA_TOKEN ?? ''
const RAPID_KEY   = Bun.env.RAPIDAPI_KEY ?? ''

// Tanzania first, then international leagues available on the free plan.
const PRIORITY_LEAGUES = [
  // football-data.org competition codes
  { code: 'CL',   name: 'UEFA Champions League',  country: 'Europe',    priority: 1 },
  { code: 'PL',   name: 'Premier League',          country: 'England',   priority: 2 },
  { code: 'SA',   name: 'Serie A',                  country: 'Italy',     priority: 3 },
  { code: 'BL1',  name: 'Bundesliga',               country: 'Germany',   priority: 4 },
  { code: 'FL1',  name: 'Ligue 1',                  country: 'France',    priority: 5 },
  { code: 'PD',   name: 'Primera Division',         country: 'Spain',     priority: 6 },
  { code: 'EC',   name: 'European Championship',    country: 'Europe',    priority: 7 },
  { code: 'WC',   name: 'FIFA World Cup',            country: 'World',      priority: 8 },
  { code: 'DED',  name: 'Eredivisie',               country: 'Netherlands', priority: 9 },
  { code: 'PPL',  name: 'Primeira Liga',            country: 'Portugal',  priority: 10 },
  { code: 'BSA',  name: 'Campeonato Brasileiro',    country: 'Brazil',    priority: 11 },
  { code: 'ELC',  name: 'Championship',             country: 'England',   priority: 12 },
]

// football-data.org Tanzania league ID (Tanzania Premier League / Ligi Kuu Bara).
// The free plan doesn't include Tanzania — we use apifootball3 for that.
const TZ_LEAGUE_ID = 1787  // apifootball3 Ligi Kuu Bara (Tanzania Premier League)

// ─── HTTP helpers ───────────────────────────────────────────────────────
async function fdGet(path: string): Promise<any> {
  if (!FD_TOKEN) throw new Error('FOOTBALL_DATA_TOKEN not set')
  const res = await fetch(`https://api.football-data.org/v4${path}`, {
    headers: { 'X-Auth-Token': FD_TOKEN },
  })
  if (!res.ok) throw new Error(`football-data.org ${res.status}: ${await res.text().catch(()=> '')}`)
  return res.json()
}

async function rapidGet(host: string, path: string, extra: Record<string,string> = {}): Promise<any> {
  if (!RAPID_KEY) throw new Error('RAPIDAPI_KEY not set')
  const url = path.startsWith('http') ? path : `https://${host}${path}`
  const res = await fetch(url, {
    headers: {
      'x-rapidapi-host': host,
      'x-rapidapi-key':  RAPID_KEY,
      ...extra,
    },
  })
  if (!res.ok) throw new Error(`RapidAPI ${host} ${res.status}: ${await res.text().catch(()=> '')}`)
  return res.json()
}

// ─── Health check ───────────────────────────────────────────────────────
sportsDataRouter.get('/status', (c) => {
  return c.json({
    ok: true,
    providers: {
      footballData:   { configured: !!FD_TOKEN,  token: FD_TOKEN ? `${FD_TOKEN.slice(0,8)}…` : null },
      rapidApi:       { configured: !!RAPID_KEY, key:   RAPID_KEY ? `${RAPID_KEY.slice(0,8)}…` : null },
    },
    priorityLeagues: PRIORITY_LEAGUES.map(l => l.code),
    tzPriority: true,
  })
})

// ─── GET /leagues — list available leagues (priority-ordered) ────────────
sportsDataRouter.get('/leagues', (c) => {
  return c.json({ ok: true, leagues: PRIORITY_LEAGUES })
})

// ─── POST /fetch/tanzania — apifootball3 Ligi Kuu Bara fetcher ──────────────
// apifootball3 free tier allows get_standings, get_events (fixtures/results).
// This is the HIGH-PRIORITY Tanzania fetcher.
sportsDataRouter.post('/fetch/tanzania', async (c) => {
  const action = c.req.query('action') ?? 'get_events'
  const from  = c.req.query('from') ?? todayPlus(-7)
  const to    = c.req.query('to')   ?? todayPlus(30)
  try {
    const data = await rapidGet(
      'apifootball3.p.rapidapi.com',
      `/?action=${action}&leagueId=${TZ_LEAGUE_ID}&from=${from}&to=${to}`,
    )
    return c.json({ ok: true, source: 'apifootball3', league: 'Ligi Kuu Bara (Tanzania)', data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/fixtures/:code — football-data.org fixtures ────────────────
// code = PL | CL | SA | BL1 | FL1 | PD | …  (free tier codes)
sportsDataRouter.post('/fetch/fixtures/:code', async (c) => {
  const code = c.req.param('code').toUpperCase()
  const matchday = c.req.query('matchday')
  try {
    const path = `/competitions/${code}/matches` + (matchday ? `?matchday=${matchday}` : '')
    const data = await fdGet(path)
    return c.json({ ok: true, source: 'football-data.org', code, data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/standings/:code ──────────────────────────────────────────
sportsDataRouter.post('/fetch/standings/:code', async (c) => {
  const code = c.req.param('code').toUpperCase()
  try {
    const data = await fdGet(`/competitions/${code}/standings`)
    return c.json({ ok: true, source: 'football-data.org', code, data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/teams/:code ─────────────────────────────────────────────
sportsDataRouter.post('/fetch/teams/:code', async (c) => {
  const code = c.req.param('code').toUpperCase()
  try {
    const data = await fdGet(`/competitions/${code}/teams`)
    return c.json({ ok: true, source: 'football-data.org', code, data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/scorers/:code ────────────────────────────────────────────
sportsDataRouter.post('/fetch/scorers/:code', async (c) => {
  const code = c.req.param('code').toUpperCase()
  try {
    const data = await fdGet(`/competitions/${code}/scorers`)
    return c.json({ ok: true, source: 'football-data.org', code, data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/predictions — RapidAPI football-prediction-api ───────────
sportsDataRouter.post('/fetch/predictions', async (c) => {
  const market = c.req.query('market') ?? 'classic'
  const iso    = c.req.query('iso_date') ?? new Date().toISOString().slice(0,10)
  const fed    = c.req.query('federation') ?? 'UEFA'
  try {
    const data = await rapidGet(
      'football-prediction-api.p.rapidapi.com',
      `/api/v2/predictions?market=${market}&iso_date=${iso}&federation=${fed}`,
    )
    return c.json({ ok: true, source: 'football-prediction-api', data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/news — RapidAPI latest-football-news + soccer-news-live ──
sportsDataRouter.post('/fetch/news', async (c) => {
  try {
    const [latest, espn] = await Promise.allSettled([
      rapidGet('latest-football-news.p.rapidapi.com', '/news'),
      rapidGet('soccer-news-live-api.p.rapidapi.com', '/news/espn'),
    ])
    const latestData = latest.status === 'fulfilled' ? latest.value : null
    const espnData   = espn.status   === 'fulfilled' ? espn.value   : null
    return c.json({
      ok: true,
      sources: {
        latestFootballNews: latestData,
        espn:               espnData,
      },
      errors: {
        latestFootballNews: latest.status === 'rejected' ? latest.reason.message : null,
        espn:               espn.status   === 'rejected' ? espn.reason.message   : null,
      },
    })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/transfers?team_id= — RapidAPI flashlive-sports ────────────
sportsDataRouter.post('/fetch/transfers', async (c) => {
  const teamId = c.req.query('team_id') ?? 'Wtn9Stg0'
  try {
    const data = await rapidGet(
      'flashlive-sports.p.rapidapi.com',
      `/v1/teams/transfers?team_id=${teamId}&page=1&locale=en_INT`,
    )
    return c.json({ ok: true, source: 'flashlive-sports', teamId, data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/live — RapidAPI football-data1 live matches ──────────────
sportsDataRouter.post('/fetch/live', async (c) => {
  const date = c.req.query('date') ?? new Date().toISOString().slice(0,10).replace(/-/g, '/')
  try {
    const data = await rapidGet(
      'football-data1.p.rapidapi.com',
      `/match/list/live?date=${date}`,
    )
    return c.json({ ok: true, source: 'football-data1', data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/highlights?team_id= ──────────────────────────────────────
sportsDataRouter.post('/fetch/highlights', async (c) => {
  const teamId = c.req.query('team_id') ?? ''
  try {
    const data = await rapidGet(
      'football-highlights-api.p.rapidapi.com',
      teamId ? `/teams/${teamId}` : '/',
    )
    return c.json({ ok: true, source: 'football-highlights-api', data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/coming-week ──────────────────────────────────────────────
sportsDataRouter.post('/fetch/coming-week', async (c) => {
  try {
    const data = await rapidGet(
      'football-matches-on-coming-week.p.rapidapi.com',
      '/football-on-coming-week',
    )
    return c.json({ ok: true, source: 'football-matches-on-coming-week', data })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 502)
  }
})

// ─── POST /fetch/all — runs the full fetch cycle, TZ first ────────────────
// Used by the AI Director and the admin Data Fetch page.
// Returns a structured summary so the UI can show what was fetched.
sportsDataRouter.post('/fetch/all', async (c) => {
  const summary: any = {
    tanzania: null,
    fixtures: {} as Record<string, any>,
    standings: {} as Record<string, any>,
    scorers:   {} as Record<string, any>,
    predictions: null,
    news:       null,
    live:       null,
    comingWeek: null,
  }

  // 1. Tanzania Ligi Kuu Bara (HIGH PRIORITY)
  try {
    const tz = await rapidGet(
      'apifootball3.p.rapidapi.com',
      `/?action=get_events&leagueId=${TZ_LEAGUE_ID}&from=${todayPlus(-7)}&to=${todayPlus(30)}`,
    )
    summary.tanzania = { ok: true, count: Array.isArray(tz) ? tz.length : 0, data: tz }
  } catch (e: any) {
    summary.tanzania = { ok: false, error: e.message }
  }

  // 2. International fixtures, standings, scorers (top 6 priority codes)
  const codes = PRIORITY_LEAGUES.slice(0, 6).map(l => l.code)
  await Promise.all(codes.map(async (code) => {
    try {
      summary.fixtures[code] = await fdGet(`/competitions/${code}/matches`)
    } catch (e: any) { summary.fixtures[code] = { error: e.message } }
    try {
      summary.standings[code] = await fdGet(`/competitions/${code}/standings`)
    } catch (e: any) { summary.standings[code] = { error: e.message } }
    try {
      summary.scorers[code] = await fdGet(`/competitions/${code}/scorers`)
    } catch (e: any) { summary.scorers[code] = { error: e.message } }
  }))

  // 3. Predictions + news + live + coming week
  try {
    summary.predictions = await rapidGet(
      'football-prediction-api.p.rapidapi.com',
      `/api/v2/predictions?market=classic&iso_date=${new Date().toISOString().slice(0,10)}&federation=UEFA`,
    )
  } catch (e: any) { summary.predictions = { error: e.message } }

  try {
    summary.news = await rapidGet('latest-football-news.p.rapidapi.com', '/news')
  } catch (e: any) { summary.news = { error: e.message } }

  try {
    summary.live = await rapidGet(
      'football-data1.p.rapidapi.com',
      `/match/list/live?date=${new Date().toISOString().slice(0,10).replace(/-/g, '/')}`,
    )
  } catch (e: any) { summary.live = { error: e.message } }

  try {
    summary.comingWeek = await rapidGet(
      'football-matches-on-coming-week.p.rapidapi.com',
      '/football-on-coming-week',
    )
  } catch (e: any) { summary.comingWeek = { error: e.message } }

  return c.json({ ok: true, summary })
})

// ─── POST /import/tanzania — persist Ligi Kuu Bara matches to public."Match" ──
// Body: the response from apifootball3 get_events (array of match objects)
sportsDataRouter.post('/import/tanzania', async (c) => {
  const body = await c.req.json<any>()
  const matches = Array.isArray(body) ? body : body?.data ?? body?.matches ?? []
  let inserted = 0, updated = 0, skipped = 0
  const league = 'Ligi Kuu Bara'

  for (const m of matches) {
    try {
      const id           = `tz-${m.match_id}`
      const homeTeam     = m.home?.name ?? m.home_name ?? 'Unknown'
      const awayTeam     = m.away?.name ?? m.away_name ?? 'Unknown'
      const homeScore    = m.home?.score ?? Number(m.home_score) || null
      const awayScore    = m.away?.score ?? Number(m.away_score) || null
      const status       = mapApifootStatus(m.match_status, m.match_live)
      const kickoffAt    = new Date(`${m.match_date} ${m.match_time || '00:00'}`).toISOString()
      const season       = m.season ?? '2026/27'
      const country      = 'Tanzania'
      const sportSlug    = 'football'

      const existing = await queryOne(`SELECT id FROM public."Match" WHERE id=$1`, [id])
      if (existing) {
        await execute(
          `UPDATE public."Match" SET "homeScore"=$1, "awayScore"=$2, status=$3, "updatedAt"=NOW()
           WHERE id=$4`,
          [homeScore, awayScore, status, id]
        )
        updated++
      } else {
        await execute(
          `INSERT INTO public."Match"(id, league, "homeTeam", "awayTeam", "homeScore", "awayScore",
             status, "kickoffAt", season, country, "sportSlug", "createdAt", "updatedAt")
           VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,NOW(),NOW())`,
          [id, league, homeTeam, awayTeam, homeScore, awayScore,
           status, kickoffAt, season, country, sportSlug]
        )
        inserted++
      }
    } catch (e) {
      skipped++
    }
  }

  return c.json({ ok: true, inserted, updated, skipped, total: matches.length })
})

// ─── POST /import/standings/:code ─────────────────────────────────────────
// Body: football-data.org /competitions/{code}/standings response
sportsDataRouter.post('/import/standings/:code', async (c) => {
  const code = c.req.param('code').toUpperCase()
  const body = await c.req.json<any>()
  const standings = body?.standings ?? []
  let upserted = 0
  for (const s of standings) {
    for (const row of s.table ?? []) {
      const teamId   = `fd-${row.team?.id ?? uuid()}`
      const teamName = row.team?.shortName ?? row.team?.name ?? 'Unknown'
      const league   = PRIORITY_LEAGUES.find(l => l.code === code)?.name ?? code
      await execute(
        `INSERT INTO public."League" (id, name, country, type, season, "sportId")
         VALUES ($1, $2, $3, 'league', '2026/27', $4)
         ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name`,
        [teamId, teamName,
         PRIORITY_LEAGUES.find(l => l.code === code)?.country ?? 'World',
         'sport-football']
      ).catch(() => {})
      upserted++
    }
  }
  return c.json({ ok: true, code, upserted })
})

// ─── POST /import/fixtures/:code ──────────────────────────────────────────
// Body: football-data.org /competitions/{code}/matches response
sportsDataRouter.post('/import/fixtures/:code', async (c) => {
  const code = c.req.param('code').toUpperCase()
  const body = await c.req.json<any>()
  const matches = body?.matches ?? []
  let inserted = 0, updated = 0, skipped = 0
  const league = PRIORITY_LEAGUES.find(l => l.code === code)?.name ?? code

  for (const m of matches) {
    try {
      const id           = `fd-${m.id}`
      const homeTeam     = m.homeTeam?.shortName ?? m.homeTeam?.name ?? 'Unknown'
      const awayTeam     = m.awayTeam?.shortName ?? m.awayTeam?.name ?? 'Unknown'
      const homeScore    = m.score?.fullTime?.home ?? null
      const awayScore    = m.score?.fullTime?.away ?? null
      const status       = mapFdStatus(m.status)
      const kickoffAt    = new Date(m.utcDate).toISOString()
      const season       = m.season ?? '2026/27'
      const sportSlug    = 'football'

      const existing = await queryOne(`SELECT id FROM public."Match" WHERE id=$1`, [id])
      if (existing) {
        await execute(
          `UPDATE public."Match" SET "homeScore"=$1, "awayScore"=$2, status=$3, "updatedAt"=NOW() WHERE id=$4`,
          [homeScore, awayScore, status, id]
        )
        updated++
      } else {
        await execute(
          `INSERT INTO public."Match"(id, league, "homeTeam", "awayTeam", "homeScore", "awayScore",
             status, "kickoffAt", season, "sportSlug", "createdAt", "updatedAt")
           VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,NOW(),NOW())`,
          [id, league, homeTeam, awayTeam, homeScore, awayScore,
           status, kickoffAt, season, sportSlug]
        )
        inserted++
      }
    } catch (e) {
      skipped++
    }
  }

  return c.json({ ok: true, code, inserted, updated, skipped, total: matches.length })
})

// ─── POST /import/news — persist fetched news as NewsItem rows ───────────
// Body: latestFootballNews or espn array
sportsDataRouter.post('/import/news', async (c) => {
  const body = await c.req.json<any>()
  const items = Array.isArray(body) ? body : body?.articles ?? body?.news ?? []
  let inserted = 0, skipped = 0
  for (const item of items) {
    try {
      const id    = `news-${(item.url ?? item.link ?? item.title).toLowerCase().replace(/[^a-z0-9]+/g,'-').slice(0,80)}-${Date.now()}`
      const title = item.title ?? item.headline ?? 'Untitled'
      const summary = item.description ?? item.summary ?? ''
      const body_  = item.content ?? item.body ?? summary
      const imageUrl = item.urlToImage ?? item.image ?? null
      const source = item.source?.name ?? item.source ?? 'External API'
      const sourceUrl = item.url ?? item.link ?? ''
      const publishedAt = item.publishedAt ?? item.published ?? new Date().toISOString()
      const isBreaking = /break|urgent|transfer|signing/i.test(title)
      const existing = await queryOne(`SELECT id FROM public."NewsItem" WHERE title=$1`, [title])
      if (existing) { skipped++; continue }
      await execute(
        `INSERT INTO public."NewsItem"(id, title, slug, body, summary, category,
           source, "source_url", "imageUrl", status, "is_breaking", "publishedAt", "createdAt", "updatedAt")
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,'published',$10,$11,NOW(),NOW())
         ON CONFLICT DO NOTHING`,
        [id, title, id, body_, summary.slice(0,200),
         'updates', source, sourceUrl, imageUrl, isBreaking, publishedAt]
      )
      inserted++
    } catch (e) { skipped++ }
  }
  return c.json({ ok: true, inserted, skipped, total: items.length })
})

// ─── Helpers ─────────────────────────────────────────────────────────────
function todayPlus(days: number): string {
  const d = new Date()
  d.setDate(d.getDate() + days)
  return d.toISOString().slice(0,10)
}

function uuid() { return crypto.randomUUID() }

function mapApifootStatus(status: string | undefined, live: string | undefined): string {
  if (live === '1' || live === 'true') return 'live'
  if (!status) return 'scheduled'
  const s = String(status).toLowerCase()
  if (s.includes('finished') || s === 'ft' || s === 'full time') return 'finished'
  if (s.includes('postponed')) return 'postponed'
  if (s.includes('cancelled')) return 'cancelled'
  return 'scheduled'
}

function mapFdStatus(status: string | undefined): string {
  if (!status) return 'scheduled'
  const s = status.toUpperCase()
  if (s === 'FINISHED') return 'finished'
  if (s === 'IN_PLAY' || s === 'PAUSED' || s === 'LIVE') return 'live'
  if (s === 'POSTPONED') return 'postponed'
  if (s === 'CANCELLED') return 'cancelled'
  if (s === 'SCHEDULED' || s === 'TIMED') return 'scheduled'
  return 'scheduled'
}

// ─── GET /last-fetch — show when each provider was last successfully called ─
sportsDataRouter.get('/last-fetch', async (c) => {
  const rows = await query(
    `SELECT * FROM public."NewsItem" ORDER BY "createdAt" DESC LIMIT 1`
  ).catch(() => [])
  return c.json({
    ok: true,
    lastNewsImport: rows.length ? (rows[0] as any).createdAt : null,
  })
})
