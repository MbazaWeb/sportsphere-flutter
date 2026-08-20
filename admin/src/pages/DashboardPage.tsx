import { useEffect, useState } from 'react'
import { fetchDashboardStats, healthCheck } from '../lib/api'
import { Bar, BarChart, ResponsiveContainer, Tooltip, XAxis, YAxis, CartesianGrid } from 'recharts'

export function DashboardPage() {
  const [stats, setStats] = useState({ users: 0, teams: 0, matches: 0, posts: 0, pendingClaims: 0, errors: [] as string[] })
  const [health, setHealth] = useState<{ ok: boolean; latencyMs: number; error: string | null } | null>(null)

  useEffect(() => {
    fetchDashboardStats().then(setStats).catch((e) => setStats((s) => ({ ...s, errors: [String(e)] })))
    healthCheck().then(setHealth)
  }, [])

  const chart = [
    { name: 'Users', value: stats.users },
    { name: 'Teams', value: stats.teams },
    { name: 'Matches', value: stats.matches },
    { name: 'Posts', value: stats.posts },
    { name: 'Claims', value: stats.pendingClaims },
  ]

  return (
    <div>
      <h1 className="page-title">Dashboard</h1>
      <p className="page-sub">App summary, operations snapshot, and database health.</p>

      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <div className="card"><h3>Users</h3><div className="value">{stats.users}</div><div className="hint">profiles table</div></div>
        <div className="card"><h3>Teams</h3><div className="value">{stats.teams}</div><div className="hint">seeded + claimed</div></div>
        <div className="card"><h3>Fixtures</h3><div className="value">{stats.matches}</div><div className="hint">Ligi Kuu Bara & more</div></div>
        <div className="card"><h3>Pending claims</h3><div className="value">{stats.pendingClaims}</div><div className="hint">need review</div></div>
      </div>

      <div className="grid grid-2">
        <div className="card" style={{ height: 320 }}>
          <h3>Operations overview</h3>
          <ResponsiveContainer width="100%" height="90%">
            <BarChart data={chart}>
              <CartesianGrid stroke="rgba(255,255,255,0.06)" vertical={false} />
              <XAxis dataKey="name" stroke="#8b9bb4" fontSize={12} />
              <YAxis stroke="#8b9bb4" fontSize={12} />
              <Tooltip contentStyle={{ background: '#0b1626', border: '1px solid rgba(255,255,255,0.08)' }} />
              <Bar dataKey="value" fill="#168cff" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card">
          <h3>Database & network health</h3>
          {health ? (
            <>
              <p>
                Status:{' '}
                <span className={`badge ${health.ok ? 'ok' : 'err'}`}>
                  {health.ok ? 'Healthy' : 'Issue'}
                </span>
              </p>
              <p className="hint">Latency: {health.latencyMs} ms</p>
              {health.error && <p className="error">{health.error}</p>}
              <p className="hint" style={{ marginTop: 16 }}>
                Connected to Supabase project used by the Flutter app. Match results, profiles, posts, and claims share the same tables.
              </p>
            </>
          ) : (
            <p className="muted">Checking…</p>
          )}
          {stats.errors.length > 0 && (
            <div style={{ marginTop: 12 }}>
              {stats.errors.map((e) => (
                <div key={e} className="error">{e}</div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
