import { useEffect, useState } from 'react'
import { api } from '../lib/http'
export function SyncPage() {
  const [services, setServices] = useState<Record<string, boolean> | null>(null)
  const [error, setError] = useState('')
  useEffect(() => { api('/v1/admin/services').then(d => setServices(d.services)).catch(e => setError(e.message)) }, [])
  return <div><h1 className="page-title">Service Status</h1><p className="page-sub">The admin console and mobile app use the same VPS API and database.</p>{error && <p className="error">{error}</p>}<div className="card"><p>API: {window.location.origin}/v1</p>{services ? Object.entries(services).map(([name, ready]) => <p key={name}>{name}: {ready ? 'Configured' : 'Setup required'}</p>) : !error && <p>Checking services…</p>}<p className="hint">Configuration status does not confirm external provider delivery.</p></div></div>
}
