import { useEffect, useState } from 'react'
import { api } from '../lib/http'

// ─── Types ────────────────────────────────────────────────────────────
type Status = 'idle' | 'fetching' | 'ok' | 'error'

interface FetchResult {
  ok: boolean
  source?: string
  data?: any
  error?: string
  summary?: any
}

// Priority order — Tanzania FIRST, then international leagues
const FD_LEAGUES = [
  { code: 'CL',  label: 'UEFA Champions League' },
  { code: 'PL',  label: 'Premier League (England)' },
  { code: 'SA',  label: 'Serie A (Italy)' },
  { code: 'BL1', label: 'Bundesliga (Germany)' },
  { code: 'FL1', label: 'Ligue 1 (France)' },
  { code: 'PD',  label: 'La Liga (Spain)' },
]

const AI_CAPABILITIES = [
  { id: 'auto-run',              label: '🤖 Auto-run full content cycle',     bodyHint: 'Topic (optional)' },
  { id: 'generate-news',         label: '📰 Generate news article',         bodyHint: 'Topic (Tanzania priority)' },
  { id: 'generate-rumor',        label: '🔁 Generate transfer rumor',       bodyHint: 'Topic (optional)' },
  { id: 'generate-post',         label: '✍️ Generate fan post',             bodyHint: 'Topic (Tanzania priority)' },
  { id: 'generate-poll',         label: '📊 Generate fan poll',              bodyHint: 'Topic (Tanzania priority)' },
  { id: 'generate-prediction',   label: '🔮 Predict match result',          bodyHint: 'homeTeam, awayTeam JSON' },
  { id: 'respond-comment',      label: '💬 Auto-reply to comment',         bodyHint: 'Comment text' },
  { id: 'update-fixture',        label: '⚽ Extract fixture from text',     bodyHint: 'Match description' },
  { id: 'team-profile',          label: '👥 Generate team profile',        bodyHint: 'Team name' },
  { id: 'player-profile',        label: '🏃 Generate player profile',       bodyHint: 'Player name' },
  { id: 'match-analysis',        label: '📊 Match analysis (by matchId)',    bodyHint: 'Match ID' },
  { id: 'manage-scores',         label: '⏱️ Manage scores (update/finalize)', bodyHint: 'matchId, action' },
  { id: 'manage-unclaimed',      label: '📣 Post for unclaimed team',        bodyHint: 'teamHandle, topic' },
  { id: 'research',              label: '🔬 Deep research (TZ football)',    bodyHint: 'Topic' },
  { id: 'chat',                  label: '💬 Chat with AI assistant',        bodyHint: 'Question' },
] as const

export function DataFetchPage() {
  const [providerStatus, setProviderStatus] = useState<any>(null)
  const [activeTab, setActiveTab] = useState<'data' | 'ai'>('data')

  // Data fetch state
  const [busy, setBusy] = useState<string | null>(null)
  const [results, setResults] = useState<Record<string, FetchResult>>({})
  const [autoImport, setAutoImport] = useState(true)

  // AI Director state
  const [aiAction, setAiAction] = useState<string>('auto-run')
  const [aiInput, setAiInput] = useState('')
  const [aiOutput, setAiOutput] = useState('')
  const [aiLoading, setAiLoading] = useState(false)
  const [aiError, setAiError] = useState<string | null>(null)

  // Load provider status on mount
  useEffect(() => {
    api('/v1/admin/sports-data/status').then(setProviderStatus).catch(() => {})
  }, [])

  // ─── Data fetch helper ────────────────────────────────────────────────
  async function fetchData(key: string, path: string, method = 'POST', body?: any) {
    setBusy(key)
    setResults(prev => ({ ...prev, [key]: { ok: false, data: null } }))
    try {
      const res = await api(path, method, body)
      setResults(prev => ({ ...prev, [key]: { ok: true, data: res } }))
      // Auto-import if requested
      if (autoImport && res?.ok) {
        if (key === 'tanzania') {
          await api('/v1/admin/sports-data/import/tanzania', 'POST', res.data).catch(() => {})
        } else if (key.startsWith('fixtures-') && res?.data) {
          const code = key.split('-')[1]
          await api(`/v1/admin/sports-data/import/fixtures/${code}`, 'POST', res.data).catch(() => {})
        } else if (key.startsWith('standings-') && res?.data) {
          const code = key.split('-')[1]
          await api(`/v1/admin/sports-data/import/standings/${code}`, 'POST', res.data).catch(() => {})
        } else if (key === 'news' && res?.sources) {
          // Try latestFootballNews first, then espn
          if (res.sources.latestFootballNews) {
            await api('/v1/admin/sports-data/import/news', 'POST', res.sources.latestFootballNews).catch(() => {})
          }
          if (res.sources.espn) {
            await api('/v1/admin/sports-data/import/news', 'POST', res.sources.espn).catch(() => {})
          }
        }
      }
    } catch (e: any) {
      setResults(prev => ({ ...prev, [key]: { ok: false, error: e.message } }))
    } finally {
      setBusy(null)
    }
  }

  async function fetchAll() {
    setBusy('all')
    setResults(prev => ({ ...prev, all: { ok: false } }))
    try {
      const summary = await api('/v1/admin/sports-data/fetch/all', 'POST', {})
      setResults(prev => ({ ...prev, all: { ok: true, summary } }))
      if (autoImport && summary?.tanzania?.ok) {
        await api('/v1/admin/sports-data/import/tanzania', 'POST', summary.tanzania.data).catch(() => {})
      }
    } catch (e: any) {
      setResults(prev => ({ ...prev, all: { ok: false, error: e.message } }))
    } finally {
      setBusy(null)
    }
  }

  // ─── AI Director runner ────────────────────────────────────────────────
  async function runAi() {
    setAiLoading(true)
    setAiError(null)
    setAiOutput('')
    try {
      // Parse input as JSON if it looks like JSON; otherwise send as a single string field
      let body: any
      const trimmed = aiInput.trim()
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        body = JSON.parse(trimmed)
      } else if (aiAction === 'respond-comment') {
        body = { comment: trimmed }
      } else if (aiAction === 'chat') {
        body = { message: trimmed }
      } else if (aiAction === 'research') {
        body = { topic: trimmed }
      } else if (aiAction === 'team-profile') {
        body = { teamName: trimmed }
      } else if (aiAction === 'player-profile') {
        body = { playerName: trimmed }
      } else if (aiAction === 'match-analysis' || aiAction === 'manage-scores') {
        body = { matchId: trimmed }
      } else if (aiAction === 'manage-unclaimed') {
        body = { teamHandle: trimmed }
      } else if (aiAction === 'update-fixture') {
        body = { text: trimmed }
      } else {
        body = { topic: trimmed }
      }
      body.autoPublish = true
      const res = await api(`/v1/admin/ai-director/${aiAction}`, 'POST', body)
      setAiOutput(JSON.stringify(res, null, 2))
    } catch (e: any) {
      setAiError(e instanceof Error ? e.message : String(e))
    } finally {
      setAiLoading(false)
    }
  }

  // ─── Render ────────────────────────────────────────────────────────────
  return (
    <div style={{ padding: 24, maxWidth: 1100 }}>
      <h1 style={{ marginTop: 0 }}>Data Fetch & AI Director</h1>
      <p style={{ opacity: 0.75 }}>
        Fetch live fixtures, standings, predictions, and news from external providers.
        Tanzania football (Ligi Kuu Bara) is given <strong style={{ color: '#168CFF' }}>HIGH PRIORITY</strong> and fetched first.
        The AI Director analyzes the data and posts, polls, predictions, and news automatically.
      </p>

      {/* Provider status */}
      <div className="card" style={{ marginBottom: 16, padding: 16 }}>
        <h3 style={{ marginTop: 0 }}>Provider Status</h3>
        {providerStatus ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 12 }}>
            <div>
              <strong>football-data.org</strong>: {providerStatus.providers?.footballData?.configured
                ? <span style={{ color: '#27e87a' }}>✓ configured ({providerStatus.providers.footballData.token})</span>
                : <span style={{ color: '#FF3B61' }}>✗ not set (set FOOTBALL_DATA_TOKEN in .env)</span>}
            </div>
            <div>
              <strong>RapidAPI</strong>: {providerStatus.providers?.rapidApi?.configured
                ? <span style={{ color: '#27e87a' }}>✓ configured ({providerStatus.providers.rapidApi.key})</span>
                : <span style={{ color: '#FF3B61' }}>✗ not set (set RAPIDAPI_KEY in .env)</span>}
            </div>
            <div>
              <strong>TZ Priority</strong>: {providerStatus.tzPriority
                ? <span style={{ color: '#27e87a' }}>✓ enabled (Ligi Kuu Bara fetched first)</span>
                : 'disabled'}
            </div>
          </div>
        ) : (
          <p className="muted">Loading provider status…</p>
        )}
      </div>

      {/* Auto-import toggle */}
      <div style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
        <input
          id="autoImport"
          type="checkbox"
          checked={autoImport}
          onChange={e => setAutoImport(e.target.checked)}
        />
        <label htmlFor="autoImport">Auto-import fetched data into the app (matches, news) — the AI Director can then act on it.</label>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, borderBottom: '1px solid #1a2c42' }}>
        <button
          onClick={() => setActiveTab('data')}
          style={{ fontWeight: activeTab === 'data' ? 700 : 400, padding: '8px 16px', borderBottom: activeTab === 'data' ? '2px solid #168CFF' : 'none' }}
        >
          📡 Data Fetch
        </button>
        <button
          onClick={() => setActiveTab('ai')}
          style={{ fontWeight: activeTab === 'ai' ? 700 : 400, padding: '8px 16px', borderBottom: activeTab === 'ai' ? '2px solid #168CFF' : 'none' }}
        >
          🤖 AI Director
        </button>
      </div>

      {activeTab === 'data' && (
        <div>
          {/* Big "fetch everything" button */}
          <div className="card" style={{ marginBottom: 16, padding: 16, background: 'linear-gradient(135deg, #0d2137 0%, #102945 100%)' }}>
            <h3 style={{ marginTop: 0 }}>🇹🇿 Full Cycle Fetch (Tanzania first)</h3>
            <p style={{ opacity: 0.75 }}>Fetches Tanzania Ligi Kuu Bara + 6 international leagues + predictions + news + live matches + coming-week fixtures in one call.</p>
            <button onClick={fetchAll} disabled={busy === 'all'}>
              {busy === 'all' ? 'Fetching…' : '▶ Fetch everything'}
            </button>
            {results.all?.ok && results.all.summary && (
              <div style={{ marginTop: 12 }}>
                <ResultSummary summary={results.all.summary} />
              </div>
            )}
            {results.all?.error && <p style={{ color: '#FF3B61' }}>{results.all.error}</p>}
          </div>

          {/* Tanzania-specific fetch */}
          <div className="card" style={{ marginBottom: 16, padding: 16, borderColor: '#168CFF' }}>
            <h3 style={{ marginTop: 0, color: '#168CFF' }}>🇹🇿 Tanzania — Ligi Kuu Bara (HIGH PRIORITY)</h3>
            <p style={{ opacity: 0.75 }}>Source: apifootball3 via RapidAPI. Fetches events for the last 7 days + next 30 days.</p>
            <button onClick={() => fetchData('tanzania', '/v1/admin/sports-data/fetch/tanzania')} disabled={busy === 'tanzania'}>
              {busy === 'tanzania' ? 'Fetching Tanzania…' : '▶ Fetch Ligi Kuu Bara'}
            </button>
            <ResultView result={results.tanzania} />
          </div>

          {/* International league fixtures */}
          <h3>International leagues (football-data.org)</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 12, marginBottom: 16 }}>
            {FD_LEAGUES.map(l => (
              <div key={l.code} className="card" style={{ padding: 12 }}>
                <h4 style={{ margin: 0 }}>{l.label}</h4>
                <p style={{ fontSize: 12, opacity: 0.6 }}>code: {l.code}</p>
                <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  <button onClick={() => fetchData(`fixtures-${l.code}`, `/v1/admin/sports-data/fetch/fixtures/${l.code}`)} disabled={busy === `fixtures-${l.code}`}>
                    {busy === `fixtures-${l.code}` ? '…' : 'Fixtures'}
                  </button>
                  <button onClick={() => fetchData(`standings-${l.code}`, `/v1/admin/sports-data/fetch/standings/${l.code}`)} disabled={busy === `standings-${l.code}`}>
                    {busy === `standings-${l.code}` ? '…' : 'Standings'}
                  </button>
                  <button onClick={() => fetchData(`scorers-${l.code}`, `/v1/admin/sports-data/fetch/scorers/${l.code}`)} disabled={busy === `scorers-${l.code}`}>
                    {busy === `scorers-${l.code}` ? '…' : 'Scorers'}
                  </button>
                </div>
                <ResultView result={results[`fixtures-${l.code}`]} compact />
                <ResultView result={results[`standings-${l.code}`]} compact />
                <ResultView result={results[`scorers-${l.code}`]} compact />
              </div>
            ))}
          </div>

          {/* Other providers */}
          <h3>Predictions · News · Live · Highlights · Transfers</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
            <button onClick={() => fetchData('predictions', '/v1/admin/sports-data/fetch/predictions')} disabled={busy === 'predictions'}>
              {busy === 'predictions' ? 'Fetching…' : '🔮 Predictions (RapidAPI)'}
            </button>
            <button onClick={() => fetchData('news', '/v1/admin/sports-data/fetch/news')} disabled={busy === 'news'}>
              {busy === 'news' ? 'Fetching…' : '📰 News (latest + ESPN)'}
            </button>
            <button onClick={() => fetchData('live', '/v1/admin/sports-data/fetch/live')} disabled={busy === 'live'}>
              {busy === 'live' ? 'Fetching…' : '📺 Live matches today'}
            </button>
            <button onClick={() => fetchData('comingWeek', '/v1/admin/sports-data/fetch/coming-week')} disabled={busy === 'comingWeek'}>
              {busy === 'comingWeek' ? 'Fetching…' : '📅 Coming-week fixtures'}
            </button>
            <button onClick={() => fetchData('transfers', '/v1/admin/sports-data/fetch/transfers')} disabled={busy === 'transfers'}>
              {busy === 'transfers' ? 'Fetching…' : '🔁 Transfers (team=Wtn9Stg0)'}
            </button>
            <button onClick={() => fetchData('highlights', '/v1/admin/sports-data/fetch/highlights')} disabled={busy === 'highlights'}>
              {busy === 'highlights' ? 'Fetching…' : '🎬 Highlights'}
            </button>
          </div>

          {/* Show each result */}
          <div style={{ marginTop: 16 }}>
            {Object.entries(results).filter(([k]) => !['all', 'tanzania'].includes(k)).map(([k, r]) => (
              <ResultView key={k} result={r} label={k} />
            ))}
          </div>
        </div>
      )}

      {activeTab === 'ai' && (
        <div>
          <div className="card" style={{ padding: 16, marginBottom: 16 }}>
            <h3 style={{ marginTop: 0 }}>AI Director — 15 capabilities</h3>
            <p style={{ opacity: 0.75 }}>
              Pick a capability and provide the input. The AI Director uses DeepSeek (default) or Anthropic Claude (if configured)
              and auto-publishes the result to the app as a post, news article, poll, or prediction.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 8, marginBottom: 16 }}>
              {AI_CAPABILITIES.map(cap => (
                <button
                  key={cap.id}
                  onClick={() => { setAiAction(cap.id); setAiInput(''); setAiOutput('') }}
                  style={{
                    textAlign: 'left',
                    padding: 10,
                    background: aiAction === cap.id ? '#168CFF' : '#0B1626',
                    color: aiAction === cap.id ? '#fff' : '#c9d4e0',
                    border: aiAction === cap.id ? '1px solid #168CFF' : '1px solid #1a2c42',
                    fontWeight: aiAction === cap.id ? 700 : 400,
                  }}
                >
                  {cap.label}
                </button>
              ))}
            </div>

            <div style={{ marginBottom: 8 }}>
              <p className="muted" style={{ margin: 0 }}>{AI_CAPABILITIES.find(c => c.id === aiAction)?.bodyHint}</p>
            </div>

            <textarea
              value={aiInput}
              onChange={e => setAiInput(e.target.value)}
              rows={5}
              placeholder={`Input for ${aiAction}…`}
              style={{ width: '100%', background: '#0B1626', color: '#fff', borderRadius: 8, padding: 12, fontFamily: 'monospace' }}
            />
            <div style={{ marginTop: 8, display: 'flex', gap: 8 }}>
              <button onClick={runAi} disabled={aiLoading || !aiInput.trim()}>
                {aiLoading ? 'Running…' : '▶ Run + auto-publish'}
              </button>
              <button onClick={() => { setAiInput(''); setAiOutput(''); setAiError(null) }}>Clear</button>
            </div>
          </div>

          {aiError && <p style={{ color: '#FF3B61', padding: '0 16px' }}>{aiError}</p>}

          {aiOutput && (
            <div style={{ padding: '0 16px' }}>
              <h4>Output</h4>
              <pre style={{ whiteSpace: 'pre-wrap', background: '#061525', padding: 16, borderRadius: 8, maxHeight: 500, overflow: 'auto' }}>
                {aiOutput}
              </pre>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// ─── Sub-components ────────────────────────────────────────────────────

function ResultView({ result, label, compact }: { result?: FetchResult; label?: string; compact?: boolean }) {
  if (!result) return null
  if (compact && !result.ok) return null
  return (
    <div style={{ marginTop: 8, padding: 8, background: '#061525', borderRadius: 6, fontSize: 13 }}>
      {label && <strong style={{ color: '#168CFF' }}>{label}: </strong>}
      {result.ok ? (
        <span style={{ color: '#27e87a' }}>✓ {result.source ?? 'OK'}</span>
      ) : (
        <span style={{ color: '#FF3B61' }}>✗ {result.error ?? 'failed'}</span>
      )}
      {!compact && result.data && (
        <pre style={{ marginTop: 6, whiteSpace: 'pre-wrap', maxHeight: 200, overflow: 'auto', fontSize: 12 }}>
          {JSON.stringify(result.data, null, 2).slice(0, 2000)}
        </pre>
      )}
    </div>
  )
}

function ResultSummary({ summary }: { summary: any }) {
  if (!summary) return null
  const items = []
  if (summary.tanzania)    items.push(['🇹🇿 Tanzania', summary.tanzania.ok ? `✓ ${summary.tanzania.count} matches` : `✗ ${summary.tanzania.error}`])
  if (summary.fixtures)    Object.entries(summary.fixtures).forEach(([code, v]: any) => items.push([`Fixtures ${code}`, v?.matches ? `✓ ${v.matches.length} matches` : `✗ ${(v as any)?.error}`]))
  if (summary.standings)   Object.entries(summary.standings).forEach(([code, v]: any) => items.push([`Standings ${code}`, v?.standings ? `✓` : `✗ ${(v as any)?.error}`]))
  if (summary.predictions) items.push(['🔮 Predictions', summary.predictions?.data ? '✓' : `✗ ${summary.predictions?.error ?? ''}`])
  if (summary.news)        items.push(['📰 News', summary.news ? '✓' : `✗ ${summary.news?.error ?? ''}`])
  if (summary.live)        items.push(['📺 Live', summary.live ? '✓' : `✗ ${summary.live?.error ?? ''}`])
  if (summary.comingWeek)  items.push(['📅 Coming week', summary.comingWeek ? '✓' : `✗ ${summary.comingWeek?.error ?? ''}`])
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 6, fontSize: 13 }}>
      {items.map(([k, v]) => (
        <div key={k}>
          <strong>{k}</strong>: <span style={{ color: v.startsWith('✓') ? '#27e87a' : '#FF3B61' }}>{v}</span>
        </div>
      ))}
    </div>
  )
}

export default DataFetchPage
