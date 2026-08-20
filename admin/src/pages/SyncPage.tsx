export function SyncPage() {
  const base = import.meta.env.VITE_SUPABASE_URL as string

  const endpoints = [
    { name: 'Profiles', method: 'GET', path: '/rest/v1/profiles?select=*' },
    { name: 'Teams', method: 'GET', path: '/rest/v1/Team?select=*' },
    { name: 'Matches', method: 'GET', path: '/rest/v1/Match?select=*&order=kickoffAt.asc' },
    { name: 'Posts', method: 'GET', path: '/rest/v1/Post?select=*&order=createdAt.desc' },
    { name: 'Claims', method: 'GET', path: '/rest/v1/ClaimRequest?select=*' },
    { name: 'Leagues', method: 'GET', path: '/rest/v1/League?select=*' },
    { name: 'Update match result', method: 'PATCH', path: '/rest/v1/Match?id=eq.{id}' },
    { name: 'Auth signup', method: 'POST', path: '/auth/v1/signup' },
    { name: 'Storage media', method: 'GET', path: '/storage/v1/object/public/media/teams/{slug}.png' },
  ]

  return (
    <div>
      <h1 className="page-title">Data Sync & API Integrations</h1>
      <p className="page-sub">
        The Flutter app and this admin console share the same Supabase REST + Auth APIs.
      </p>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3>API base</h3>
        <code style={{ fontSize: 13 }}>{base}</code>
        <p className="hint" style={{ marginTop: 10 }}>
          Auth header: <code>apikey</code> + <code>Authorization: Bearer {'{anon_or_user_jwt}'}</code>
        </p>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Integration</th>
              <th>Method</th>
              <th>Path</th>
            </tr>
          </thead>
          <tbody>
            {endpoints.map((e) => (
              <tr key={e.name}>
                <td>{e.name}</td>
                <td><span className="badge">{e.method}</span></td>
                <td className="muted"><code>{e.path}</code></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <h3>External data sync (planned)</h3>
        <ul className="muted">
          <li>Flashscore / SofaScore logo + fixture pulls via <code>scripts/fetch_team_logos.py</code></li>
          <li>Admin-triggered re-sync of Ligi Kuu Bara fixtures JSON</li>
          <li>Post-match stats ingestion into <code>Match.stats</code> / <code>Match.events</code></li>
        </ul>
      </div>
    </div>
  )
}
