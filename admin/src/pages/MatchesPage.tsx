import { useEffect, useState } from 'react'
import { listMatches, updateMatchResult, postponeMatch, createMatch } from '../lib/api'
import type { MatchRow } from '../lib/supabase'

export function MatchesPage() {
  const [matches, setMatches] = useState<MatchRow[]>([])
  const [filter, setFilter] = useState('')
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [home, setHome] = useState('')
  const [away, setAway] = useState('')
  const [kickoff, setKickoff] = useState('')

  async function load() {
    try {
      setMatches(await listMatches(300))
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  const filtered = matches.filter((m) => {
    const s = `${m.homeTeam} ${m.awayTeam} ${m.status} ${m.league}`.toLowerCase()
    return s.includes(filter.toLowerCase())
  })

  async function saveResult(m: MatchRow, hs: string, as: string) {
    try {
      await updateMatchResult(m.id, Number(hs), Number(as), 'FT')
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
      await createMatch({
        id,
        homeTeam: home,
        awayTeam: away,
        kickoffAt: new Date(kickoff).toISOString(),
        league: 'Ligi Kuu Bara',
        season: '2026/2027',
        status: 'scheduled',
      })
      setMsg('Match created')
      setHome('')
      setAway('')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <div>
      <h1 className="page-title">Match Updates</h1>
      <p className="page-sub">Create matches, enter results, postpone, and track status for the app scores feed.</p>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      <div className="card stack" style={{ marginBottom: 16, maxWidth: 720 }}>
        <h3>Create match</h3>
        <div className="row">
          <input className="input" placeholder="Home team" value={home} onChange={(e) => setHome(e.target.value)} />
          <input className="input" placeholder="Away team" value={away} onChange={(e) => setAway(e.target.value)} />
          <input className="input" type="datetime-local" value={kickoff} onChange={(e) => setKickoff(e.target.value)} />
          <button className="btn btn-primary" onClick={create}>Create</button>
        </div>
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
      <td className="muted">{m.kickoffAt ? new Date(m.kickoffAt).toLocaleString() : '—'}</td>
      <td>
        <div className="row">
          {m.homeBadge && <img src={m.homeBadge} width={20} height={20} alt="" />}
          {m.homeTeam} <span className="muted">vs</span> {m.awayTeam}
          {m.awayBadge && <img src={m.awayBadge} width={20} height={20} alt="" />}
        </div>
      </td>
      <td><span className={`badge ${m.status === 'FT' ? 'ok' : m.status === 'postponed' ? 'warn' : ''}`}>{m.status}</span></td>
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
