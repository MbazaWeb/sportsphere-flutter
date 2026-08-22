import { useEffect, useState } from 'react'
import { listTeams, upsertTeam, listLeagues, createLeague, listPlayers, createPlayer, listCoaches, createCoach } from '../lib/api'
import type { TeamRow, LeagueRow, PlayerRow, CoachRow } from '../lib/supabase'
import { supabase } from '../lib/supabase'

type Tab = 'teams' | 'leagues' | 'players' | 'coaches'

export function EntitiesPage() {
  const [tab, setTab] = useState<Tab>('teams')
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  return (
    <div>
      <h1 className="page-title">League · Team · Player · Coach</h1>
      <p className="page-sub">Create and manage sports entities shared with the mobile app.</p>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      <div className="toolbar" style={{ marginBottom: 18 }}>
        {(['teams', 'leagues', 'players', 'coaches'] as Tab[]).map((t) => (
          <button
            key={t}
            className={`btn ${tab === t ? 'btn-primary' : ''}`}
            onClick={() => setTab(t)}
          >
            {t.charAt(0).toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

      {tab === 'teams' && <TeamsTab setMsg={setMsg} setErr={setErr} />}
      {tab === 'leagues' && <LeaguesTab setMsg={setMsg} setErr={setErr} />}
      {tab === 'players' && <PlayersTab setMsg={setMsg} setErr={setErr} />}
      {tab === 'coaches' && <CoachesTab setMsg={setMsg} setErr={setErr} />}
    </div>
  )
}

// ═══════════════════════════════════════════════════════════════
// TEAMS TAB
// ═══════════════════════════════════════════════════════════════

function TeamsTab({ setMsg, setErr }: { setMsg: (m: string | null) => void; setErr: (e: string | null) => void }) {
  const [teams, setTeams] = useState<TeamRow[]>([])
  const [leagues, setLeagues] = useState<LeagueRow[]>([])
  const [name, setName] = useState('')
  const [shortName, setShortName] = useState('')
  const [city, setCity] = useState('')
  const [country, setCountry] = useState('Tanzania')
  const [leagueId, setLeagueId] = useState('')
  const [venue, setVenue] = useState('')

  async function load() {
    try {
      setTeams(await listTeams())
      setLeagues(await listLeagues())
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  async function createTeam() {
    if (!name.trim()) return
    const id = `tm-${name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '').slice(0, 40)}`
    try {
      await upsertTeam({
        id,
        name: name.trim(),
        shortName: shortName.trim() || name.trim().split(' ')[0],
        city: city || null,
        country: country || null,
        leagueId: leagueId || null,
        venue: venue || null,
        verified: true,
      } as any)
      setMsg(`Created team: ${name}`)
      setName(''); setShortName(''); setCity(''); setCountry('Tanzania'); setLeagueId(''); setVenue('')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <>
      <div className="card stack" style={{ marginBottom: 18 }}>
        <h3>Create Team</h3>
        <div className="grid grid-3" style={{ gap: 10 }}>
          <input className="input" placeholder="Team name *" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="input" placeholder="Short name" value={shortName} onChange={(e) => setShortName(e.target.value)} />
          <input className="input" placeholder="City" value={city} onChange={(e) => setCity(e.target.value)} />
          <input className="input" placeholder="Country" value={country} onChange={(e) => setCountry(e.target.value)} />
          <select className="select" value={leagueId} onChange={(e) => setLeagueId(e.target.value)}>
            <option value="">Select league (optional)</option>
            {leagues.map((l) => (
              <option key={l.id} value={l.id}>{l.name}</option>
            ))}
          </select>
          <input className="input" placeholder="Venue / Stadium" value={venue} onChange={(e) => setVenue(e.target.value)} />
        </div>
        <button className="btn btn-primary" onClick={createTeam} style={{ alignSelf: 'flex-end' }}>Create Team</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Team</th>
              <th>Short</th>
              <th>City</th>
              <th>Country</th>
              <th>League</th>
              <th>Verified</th>
            </tr>
          </thead>
          <tbody>
            {teams.map((t) => (
              <tr key={t.id}>
                <td>
                  <div className="row">
                    {t.logoUrl && <img src={t.logoUrl} alt="" width={28} height={28} style={{ objectFit: 'contain' }} />}
                    <strong>{t.name}</strong>
                  </div>
                </td>
                <td>{t.shortName ?? '—'}</td>
                <td>{t.city ?? '—'}</td>
                <td>{(t as any).country ?? '—'}</td>
                <td className="muted">{t.leagueId}</td>
                <td><span className={`badge ${t.verified ? 'ok' : 'warn'}`}>{t.verified ? 'Yes' : 'No'}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

// ═══════════════════════════════════════════════════════════════
// LEAGUES TAB
// ═══════════════════════════════════════════════════════════════

function LeaguesTab({ setMsg, setErr }: { setMsg: (m: string | null) => void; setErr: (e: string | null) => void }) {
  const [leagues, setLeagues] = useState<LeagueRow[]>([])
  const [name, setName] = useState('')
  const [country, setCountry] = useState('Tanzania')
  const [division, setDivision] = useState('')
  const [season, setSeason] = useState('2026/2027')
  const [leagueType, setLeagueType] = useState('league')

  async function load() {
    try {
      setLeagues(await listLeagues())
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  async function create() {
    if (!name.trim()) return
    const id = `lg-${name.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '').slice(0, 40)}`
    try {
      await createLeague({
        id,
        name: name.trim(),
        slug: name.toLowerCase().replace(/\s+/g, '-'),
        country: country || null,
        division: division || null,
        season: season || null,
        type: leagueType,
        verified: true,
      } as any)
      setMsg(`Created league: ${name}`)
      setName(''); setCountry('Tanzania'); setDivision(''); setSeason('2026/2027')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <>
      <div className="card stack" style={{ marginBottom: 18 }}>
        <h3>Create League</h3>
        <div className="grid grid-3" style={{ gap: 10 }}>
          <input className="input" placeholder="League name *" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="input" placeholder="Country" value={country} onChange={(e) => setCountry(e.target.value)} />
          <input className="input" placeholder="Division" value={division} onChange={(e) => setDivision(e.target.value)} />
          <input className="input" placeholder="Season" value={season} onChange={(e) => setSeason(e.target.value)} />
          <select className="select" value={leagueType} onChange={(e) => setLeagueType(e.target.value)}>
            <option value="league">League</option>
            <option value="cup">Cup</option>
            <option value="tournament">Tournament</option>
            <option value="friendly">Friendly Competition</option>
          </select>
        </div>
        <button className="btn btn-primary" onClick={create} style={{ alignSelf: 'flex-end' }}>Create League</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>League</th>
              <th>Country</th>
              <th>Type</th>
              <th>Division</th>
              <th>Season</th>
              <th>ID</th>
            </tr>
          </thead>
          <tbody>
            {leagues.map((l) => (
              <tr key={l.id}>
                <td>
                  <div className="row">
                    {l.logoUrl && <img src={l.logoUrl} alt="" width={24} height={24} style={{ objectFit: 'contain' }} />}
                    <strong>{l.name}</strong>
                  </div>
                </td>
                <td>{l.country ?? '—'}</td>
                <td><span className="badge">{l.type ?? 'league'}</span></td>
                <td>{l.division ?? '—'}</td>
                <td>{l.season ?? '—'}</td>
                <td className="muted">{l.id}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

// ═══════════════════════════════════════════════════════════════
// PLAYERS TAB
// ═══════════════════════════════════════════════════════════════

function PlayersTab({ setMsg, setErr }: { setMsg: (m: string | null) => void; setErr: (e: string | null) => void }) {
  const [players, setPlayers] = useState<PlayerRow[]>([])
  const [teams, setTeams] = useState<TeamRow[]>([])
  const [leagues, setLeagues] = useState<LeagueRow[]>([])
  // Form fields
  const [name, setName] = useState('')
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [position, setPosition] = useState('')
  const [nationality, setNationality] = useState('')
  const [teamId, setTeamId] = useState('')
  const [leagueId, setLeagueId] = useState('')
  const [shirtNumber, setShirtNumber] = useState('')
  const [heightCm, setHeightCm] = useState('')
  const [weightKg, setWeightKg] = useState('')

  async function load() {
    try {
      setPlayers(await listPlayers())
      setTeams(await listTeams())
      setLeagues(await listLeagues())
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  async function create() {
    if (!name.trim()) return
    const id = `pl-${Date.now()}`
    try {
      await createPlayer({
        id,
        name: name.trim(),
        firstName: firstName.trim() || null,
        lastName: lastName.trim() || null,
        position: position || null,
        nationality: nationality || null,
        teamId: teamId || null,
        leagueId: leagueId || null,
        shirtNumber: shirtNumber ? parseInt(shirtNumber) : null,
        heightCm: heightCm ? parseFloat(heightCm) : null,
        weightKg: weightKg ? parseFloat(weightKg) : null,
      } as any)
      setMsg(`Created player: ${name}`)
      setName(''); setFirstName(''); setLastName(''); setPosition('');
      setNationality(''); setTeamId(''); setLeagueId('');
      setShirtNumber(''); setHeightCm(''); setWeightKg('')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <>
      <div className="card stack" style={{ marginBottom: 18 }}>
        <h3>Create Player</h3>
        <div className="grid grid-3" style={{ gap: 10 }}>
          <input className="input" placeholder="Full name *" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="input" placeholder="First name" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
          <input className="input" placeholder="Last name" value={lastName} onChange={(e) => setLastName(e.target.value)} />
          <select className="select" value={position} onChange={(e) => setPosition(e.target.value)}>
            <option value="">Position</option>
            {['Goalkeeper', 'Centre-Back', 'Right-Back', 'Left-Back', 'Defensive Midfielder', 'Central Midfielder', 'Attacking Midfielder', 'Right Winger', 'Left Winger', 'Striker', 'Second Striker'].map((p) => (
              <option key={p} value={p}>{p}</option>
            ))}
          </select>
          <input className="input" placeholder="Nationality" value={nationality} onChange={(e) => setNationality(e.target.value)} />
          <input className="input" placeholder="Shirt #" type="number" value={shirtNumber} onChange={(e) => setShirtNumber(e.target.value)} />
          <select className="select" value={teamId} onChange={(e) => setTeamId(e.target.value)}>
            <option value="">Select team</option>
            {teams.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </select>
          <select className="select" value={leagueId} onChange={(e) => setLeagueId(e.target.value)}>
            <option value="">Select league</option>
            {leagues.map((l) => (
              <option key={l.id} value={l.id}>{l.name}</option>
            ))}
          </select>
          <input className="input" placeholder="Height (cm)" type="number" value={heightCm} onChange={(e) => setHeightCm(e.target.value)} />
          <input className="input" placeholder="Weight (kg)" type="number" value={weightKg} onChange={(e) => setWeightKg(e.target.value)} />
        </div>
        <button className="btn btn-primary" onClick={create} style={{ alignSelf: 'flex-end' }}>Create Player</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Player</th>
              <th>Position</th>
              <th>Nationality</th>
              <th>Team</th>
              <th>#</th>
            </tr>
          </thead>
          <tbody>
            {players.map((p) => (
              <tr key={p.id}>
                <td>
                  <div className="row">
                    {p.photoUrl && <img src={p.photoUrl} alt="" width={24} height={24} style={{ objectFit: 'contain', borderRadius: '50%' }} />}
                    <strong>{p.name}</strong>
                    <span className="muted">{p.slug}</span>
                  </div>
                </td>
                <td><span className="badge">{p.position ?? '—'}</span></td>
                <td>{p.nationality ?? '—'}</td>
                <td className="muted">{(p as any).Team?.name ?? p.teamId ?? '—'}</td>
                <td>{p.shirtNumber ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

// ═══════════════════════════════════════════════════════════════
// COACHES TAB
// ═══════════════════════════════════════════════════════════════

function CoachesTab({ setMsg, setErr }: { setMsg: (m: string | null) => void; setErr: (e: string | null) => void }) {
  const [coaches, setCoaches] = useState<CoachRow[]>([])
  const [teams, setTeams] = useState<TeamRow[]>([])
  // Form fields
  const [name, setName] = useState('')
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [nationality, setNationality] = useState('')
  const [teamId, setTeamId] = useState('')
  const [coachingRole, setCoachingRole] = useState('')
  const [license, setLicense] = useState('')
  const [yearsCoaching, setYearsCoaching] = useState('')

  async function load() {
    try {
      setCoaches(await listCoaches())
      setTeams(await listTeams())
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  async function create() {
    if (!name.trim()) return
    const id = `co-${Date.now()}`
    try {
      await createCoach({
        id,
        name: name.trim(),
        firstName: firstName.trim() || null,
        lastName: lastName.trim() || null,
        nationality: nationality || null,
        teamId: teamId || null,
        coachingRole: coachingRole || null,
        license: license || null,
        yearsCoaching: yearsCoaching ? parseFloat(yearsCoaching) : null,
      } as any)
      setMsg(`Created coach: ${name}`)
      setName(''); setFirstName(''); setLastName(''); setNationality('');
      setTeamId(''); setCoachingRole(''); setLicense(''); setYearsCoaching('')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <>
      <div className="card stack" style={{ marginBottom: 18 }}>
        <h3>Create Coach</h3>
        <div className="grid grid-3" style={{ gap: 10 }}>
          <input className="input" placeholder="Full name *" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="input" placeholder="First name" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
          <input className="input" placeholder="Last name" value={lastName} onChange={(e) => setLastName(e.target.value)} />
          <select className="select" value={coachingRole} onChange={(e) => setCoachingRole(e.target.value)}>
            <option value="">Coaching Role</option>
            {['Head Coach', 'Assistant Coach', 'Goalkeeping Coach', 'Fitness Coach', 'Technical Director', 'Youth Coach', 'Interim Coach'].map((r) => (
              <option key={r} value={r}>{r}</option>
            ))}
          </select>
          <input className="input" placeholder="Nationality" value={nationality} onChange={(e) => setNationality(e.target.value)} />
          <input className="input" placeholder="License / Certification" value={license} onChange={(e) => setLicense(e.target.value)} />
          <select className="select" value={teamId} onChange={(e) => setTeamId(e.target.value)}>
            <option value="">Select team</option>
            {teams.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </select>
          <input className="input" placeholder="Years coaching" type="number" value={yearsCoaching} onChange={(e) => setYearsCoaching(e.target.value)} />
        </div>
        <button className="btn btn-primary" onClick={create} style={{ alignSelf: 'flex-end' }}>Create Coach</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Coach</th>
              <th>Role</th>
              <th>Nationality</th>
              <th>Team</th>
              <th>License</th>
            </tr>
          </thead>
          <tbody>
            {coaches.map((c) => (
              <tr key={c.id}>
                <td>
                  <div className="row">
                    {c.photoUrl && <img src={c.photoUrl} alt="" width={24} height={24} style={{ objectFit: 'contain', borderRadius: '50%' }} />}
                    <strong>{c.name}</strong>
                  </div>
                </td>
                <td><span className="badge">{c.coachingRole ?? '—'}</span></td>
                <td>{c.nationality ?? '—'}</td>
                <td className="muted">{(c as any).Team?.name ?? c.teamId ?? '—'}</td>
                <td className="muted">{c.license ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}
