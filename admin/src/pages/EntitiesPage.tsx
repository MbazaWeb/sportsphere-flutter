import { useEffect, useState } from 'react'
import { listTeams, upsertTeam } from '../lib/api'
import type { TeamRow } from '../lib/supabase'
import { supabase } from '../lib/supabase'

export function EntitiesPage() {
  const [teams, setTeams] = useState<TeamRow[]>([])
  const [leagues, setLeagues] = useState<any[]>([])
  const [name, setName] = useState('')
  const [city, setCity] = useState('')
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  async function load() {
    try {
      setTeams(await listTeams())
      const { data } = await supabase.from('League').select('*').order('name')
      setLeagues(data ?? [])
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  async function createTeam() {
    if (!name.trim()) return
    const id = `tm-${name.toLowerCase().replace(/\s+/g, '-').slice(0, 40)}`
    try {
      await upsertTeam({
        id,
        name: name.trim(),
        shortName: name.trim().split(' ')[0],
        city: city || null,
        leagueId: 'lg-nbc-pl',
        verified: true,
        isActive: true as any,
      } as any)
      setMsg(`Created ${name}`)
      setName('')
      setCity('')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <div>
      <h1 className="page-title">League · Team · Player</h1>
      <p className="page-sub">Create and manage sports entities shared with the mobile app.</p>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      <div className="grid grid-2" style={{ marginBottom: 18 }}>
        <div className="card">
          <h3>Leagues</h3>
          <ul style={{ margin: '10px 0 0', paddingLeft: 18 }}>
            {leagues.map((l) => (
              <li key={l.id} style={{ marginBottom: 6 }}>
                {l.name} <span className="muted">· {l.id}</span>
              </li>
            ))}
            {leagues.length === 0 && <li className="muted">No leagues loaded (check RLS)</li>}
          </ul>
        </div>
        <div className="card stack">
          <h3>Create team</h3>
          <input className="input" placeholder="Team name" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="input" placeholder="City" value={city} onChange={(e) => setCity(e.target.value)} />
          <button className="btn btn-primary" onClick={createTeam}>Create team</button>
        </div>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Team</th>
              <th>City</th>
              <th>League</th>
              <th>Verified</th>
              <th>Account</th>
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
                <td>{t.city ?? '—'}</td>
                <td className="muted">{t.leagueId}</td>
                <td><span className={`badge ${t.verified ? 'ok' : 'warn'}`}>{t.verified ? 'Yes' : 'No'}</span></td>
                <td className="muted">{t.accountUserId ? String(t.accountUserId).slice(0, 8) + '…' : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
