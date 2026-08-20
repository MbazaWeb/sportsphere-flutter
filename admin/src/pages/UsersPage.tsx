import { useEffect, useState } from 'react'
import { listProfiles, listClaims, resolveClaim, verifyProfile, updateProfile } from '../lib/api'
import type { Profile } from '../lib/supabase'

export function UsersPage() {
  const [users, setUsers] = useState<Profile[]>([])
  const [claims, setClaims] = useState<any[]>([])
  const [q, setQ] = useState('')
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  async function load() {
    try {
      setUsers(await listProfiles())
      setClaims(await listClaims())
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }

  useEffect(() => { load() }, [])

  const filtered = users.filter((u) => {
    const s = `${u.handle} ${u.email} ${u.role} ${u.first_name} ${u.last_name}`.toLowerCase()
    return s.includes(q.toLowerCase())
  })

  async function toggleVerify(u: Profile) {
    try {
      await verifyProfile(u.id, !u.is_verified)
      setMsg(`Updated verification for @${u.handle}`)
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  async function setRole(u: Profile, role: string) {
    try {
      await updateProfile(u.id, { role })
      setMsg(`Role set to ${role}`)
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <div>
      <h1 className="page-title">User Management</h1>
      <p className="page-sub">All role users — verify, edit role, review claims.</p>
      <div className="toolbar">
        <input className="input" placeholder="Search handle, email, role…" value={q} onChange={(e) => setQ(e.target.value)} style={{ minWidth: 260 }} />
        <button className="btn" onClick={load}>Refresh</button>
      </div>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      <div className="table-wrap" style={{ marginBottom: 24 }}>
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Role</th>
              <th>Country</th>
              <th>Verified</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((u) => (
              <tr key={u.id}>
                <td>
                  <strong>@{u.handle ?? '—'}</strong>
                  <div className="muted">{u.email}</div>
                </td>
                <td>
                  <select className="select" value={u.role ?? 'fan'} onChange={(e) => setRole(u, e.target.value)}>
                    {['fan','player','team','coach','scout','agent','analyst','journalist','creator','official','organization','admin'].map((r) => (
                      <option key={r} value={r}>{r}</option>
                    ))}
                  </select>
                </td>
                <td>{u.country ?? '—'}</td>
                <td>
                  <span className={`badge ${u.is_verified ? 'ok' : 'warn'}`}>
                    {u.is_verified ? 'Verified' : 'Unverified'}
                  </span>
                </td>
                <td className="row">
                  <button className="btn btn-sm" onClick={() => toggleVerify(u)}>
                    {u.is_verified ? 'Unverify' : 'Verify'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2 style={{ fontSize: 16 }}>Claim requests</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Entity</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {claims.length === 0 && (
              <tr><td colSpan={4} className="muted">No claims yet</td></tr>
            )}
            {claims.map((c) => (
              <tr key={c.id}>
                <td className="muted">{String(c.id).slice(0, 8)}</td>
                <td>{c.entityType} · {c.entityId}</td>
                <td><span className={`badge ${c.status === 'pending' ? 'warn' : c.status === 'approved' ? 'ok' : 'err'}`}>{c.status}</span></td>
                <td className="row">
                  {c.status === 'pending' && (
                    <>
                      <button className="btn btn-sm btn-primary" onClick={async () => { await resolveClaim(c.id, 'approved'); load() }}>Approve</button>
                      <button className="btn btn-sm btn-danger" onClick={async () => { await resolveClaim(c.id, 'rejected'); load() }}>Reject</button>
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
