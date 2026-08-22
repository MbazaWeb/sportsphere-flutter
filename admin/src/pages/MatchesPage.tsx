import { useCallback, useEffect, useState } from 'react'
import { useTableRealtime } from '../lib/realtime'
import { listMatches, updateMatchResult, postponeMatch, createMatch, listLeagues, listTeams } from '../lib/api'
import type { MatchRow, LeagueRow, TeamRow } from '../lib/supabase'

export function MatchesPage() {
  const [matches, setMatches] = useState<MatchRow[]>([])
  const [leagues, setLeagues] = useState<LeagueRow[]>([])
  const [teams, setTeams] = useState<TeamRow[]>([])
  const [filter, setFilter] = useState('')
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  // Create form
  const [home, setHome] = useState('')
  const [away, setAway] = useState('')
  const [homeId, setHomeId] = useState('')
  const [awayId, setAwayId] = useState('')
  const [kickoff, setKickoff] = useState('')
  const [league, setLeague] = useState('Ligi Kuu Bara')
  const [leagueId, setLeagueId] = useState('')
  const [season, setSeason] = useState('2026/2027')
  const [venue, setVenue] = useState('')
  const [continent, setContinent] = useState('Africa')
  const [country, setCountry] = useState('Tanzania')

  const load = useCallback(async () => {
    try {
      const [m, l, t] = await Promise.all([
        listMatches(300),
        listLeagues(),
        listTeams(),
      ])
      setMatches(m)
      setLeagues(l)
      setTeams(t)
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }, [])

  useEffect(() => { load() }, [load])
  useTableRealtime('Match', load)

  const filtered = matches.filter((m) => {
    const s = `${m.homeTeam} ${m.awayTeam} ${m.status} ${m.league}`.toLowerCase()
    return s.includes(filter.toLowerCase())
  })

  async function saveResult(m: MatchRow, hs: string, as: string) {
    try {
      await updateMatchResult(m.id, Number(hs), Number(as), 'finished')
      setMsg(`Result saved: ${m.homeTeam} ${hs}-${as} ${m.awayTeam}`)
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  async function postpone(m: MatchRow) {
    try {
      await postponeMatch(m.id, 'Admin postponed')
      setMsg(`Postponed ${m.homeTeam} vs ${m.awayTeam}`)
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  async function create() {
    if (!home || !away || !kickoff) return
    try {
      const id = `adm-${Date.now()}`
      const selectedLeague = leagues.find((l) => l.id === leagueId)
      await createMatch({
        id,
        homeTeam: homeId ? teams.find((t) => t.id === homeId)?.name || home : home,
        awayTeam: awayId ? teams.find((t) => t.id === awayId)?.name || away : away,
        kickoffAt: new Date(kickoff).toISOString(),
        league: selectedLeague?.name || league,
        season,
        venue: venue || undefined,
        continent: continent || undefined,
        country: country || undefined,
        status: 'scheduled',
      })
      setMsg('Match created')
      setHome(''); setAway(''); setKickoff(''); setVenue('')
      setHomeId(''); setAwayId(''); setLeagueId('')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  function selectHomeTeam(teamId: string) {
    setHomeId(teamId)
    const t = teams.find((tm) => tm.id === teamId)
    if (t) setHome(t.name)
  }

  function selectAwayTeam(teamId: string) {
    setAwayId(teamId)
    const t = teams.find((tm) => tm.id === teamId)
    if (t) setAway(t.name)
  }

  function selectLeague(leagueIdVal: string) {
    setLeagueId(leagueIdVal)
    const l = leagues.find((lg) => lg.id === leagueIdVal)
    if (l) setLeague(l.name)
  }

  return (
    <div>
      <h1 className="page-title">Match Updates</h1>
      <p className="page-sub">Create matches, enter results, postpone, and track status for the app scores feed.</p>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      <div className="card stack" style={{ marginBottom: 16, maxWidth: '100%' }}>
        <h3>Create match</h3>
        <div className="grid grid-3" style={{ gap: 10 }}>
          <select className="select" value={homeId} onChange={(e) => selectHomeTeam(e.target.value)}>
            <option value="">Select home team</option>
            {teams.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </select>
          <input className="input" placeholder="Or type home team name" value={home} onChange={(e) => { setHome(e.target.value); if (!homeId) {} }} />
          <select className="select" value={awayId} onChange={(e) => selectAwayTeam(e.target.value)}>
            <option value="">Select away team</option>
            {teams.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </select>
          <input className="input" placeholder="Or type away team name" value={away} onChange={(e) => { setAway(e.target.value); if (!awayId) {} }} />
          <input className="input" type="datetime-local" value={kickoff} onChange={(e) => setKickoff(e.target.value)} />
          <select className="select" value={leagueId} onChange={(e) => selectLeague(e.target.value)}>
            <option value="">Select league</option>
            {leagues.map((l) => (
              <option key={l.id} value={l.id}>{l.name}</option>
            ))}
          </select>
          <input className="input" placeholder="Season" value={season} onChange={(e) => setSeason(e.target.value)} />
          <input className="input" placeholder="Venue / Stadium" value={venue} onChange={(e) => setVenue(e.target.value)} />
          <input className="input" placeholder="Country" value={country} onChange={(e) => setCountry(e.target.value)} />
        </div>
        <button className="btn btn-primary" onClick={create} style={{ alignSelf: 'flex-end' }}>Create Match</button>
      </div>

      <div className="toolbar">
        <input className="input" placeholder="Filter team or status…" value={filter} onChange={(e) => setFilter(e.target.value)} style={{ minWidth: 240 }} />
        <button className="btn" onClick={load}>Refresh</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Kickoff</th>
              <th>Fixture</th>
              <th>League</th>
              <th>Status</th>
              <th>Score</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.slice(0, 80).map((m) => (
              <MatchRowEditor key={m.id} m={m} onSave={saveResult} onPostpone={postpone} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function MatchRowEditor({
  m,
  onSave,
  onPostpone,
}: {
  m: MatchRow
  onSave: (m: MatchRow, hs: string, as: string) => void
  onPostpone: (m: MatchRow) => void
}) {
  const [hs, setHs] = useState(String(m.homeScore ?? 0))
  const [ascore, setAscore] = useState(String(m.awayScore ?? 0))
  return (
    <tr>
      <td className="muted" style={{ fontSize: 11 }}>{m.kickoffAt ? new Date(m.kickoffAt).toLocaleString() : '—'}</td>
      <td>
        <div className="row">
          {m.homeBadge && <img src={m.homeBadge} width={20} height={20} alt="" />}
          {m.homeTeam} <span className="muted">vs</span> {m.awayTeam}
          {m.awayBadge && <img src={m.awayBadge} width={20} height={20} alt="" />}
        </div>
      </td>
      <td className="muted" style={{ fontSize: 11 }}>{m.league ?? '—'}</td>
      <td><span className={`badge ${m.status === 'FT' || m.status === 'finished' ? 'ok' : m.status === 'postponed' ? 'warn' : ''}`}>{m.status}</span></td>
      <td className="row">
        <input className="input" style={{ width: 56 }} value={hs} onChange={(e) => setHs(e.target.value)} />
        <span>-</span>
        <input className="input" style={{ width: 56 }} value={ascore} onChange={(e) => setAscore(e.target.value)} />
      </td>
      <td className="row">
        <button className="btn btn-sm btn-primary" onClick={() => onSave(m, hs, ascore)}>Save FT</button>
        <button className="btn btn-sm" onClick={() => onPostpone(m)}>Postpone</button>
      </td>
    </tr>
  )
}