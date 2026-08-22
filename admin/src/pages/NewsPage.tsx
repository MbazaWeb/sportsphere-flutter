import { useCallback, useEffect, useState } from 'react'
import { useTableRealtime } from '../lib/realtime'
import { listNews, createNews, deleteNews } from '../lib/api'
import type { NewsRow } from '../lib/supabase'

const NEWS_CATEGORIES = [
  'general', 'transfers', 'match-report', 'analysis',
  'interview', 'opinion', 'breaking', 'feature',
  'youth', 'women', 'futsal', 'business',
]

export function NewsPage() {
  const [news, setNews] = useState<NewsRow[]>([])
  const [err, setErr] = useState<string | null>(null)
  const [msg, setMsg] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)

  // Create form state
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [summary, setSummary] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [category, setCategory] = useState('general')
  const [tags, setTags] = useState('')
  const [source, setSource] = useState('')
  const [sourceUrl, setSourceUrl] = useState('')
  const [isBreaking, setIsBreaking] = useState(false)

  const [showForm, setShowForm] = useState(false)
  const [filter, setFilter] = useState('')

  const load = useCallback(async () => {
    try {
      setNews(await listNews(200))
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }, [])

  useEffect(() => { load() }, [load])
  useTableRealtime('NewsItem', load)

  const filtered = news.filter((n) => {
    const s = `${n.title} ${n.category} ${n.source} ${n.tags?.join(' ')}`.toLowerCase()
    return s.includes(filter.toLowerCase())
  })

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()
    if (!title.trim()) return
    setCreating(true)
    setErr(null)
    setMsg(null)
    try {
      const parsedTags = tags
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean)
      await createNews({
        title: title.trim(),
        body: body.trim() || undefined,
        summary: summary.trim() || undefined,
        imageUrl: imageUrl.trim() || undefined,
        category,
        tags: parsedTags.length > 0 ? parsedTags : undefined,
        source: source.trim() || undefined,
        source_url: sourceUrl.trim() || undefined,
        is_breaking: isBreaking,
      })
      setMsg('News article published')
      setTitle('')
      setBody('')
      setSummary('')
      setImageUrl('')
      setTags('')
      setSource('')
      setSourceUrl('')
      setIsBreaking(false)
      setShowForm(false)
      load()
    } catch (e: any) {
      setErr(e.message)
    } finally {
      setCreating(false)
    }
  }

  async function handleDelete(id: string) {
    try {
      await deleteNews(id)
      setMsg('News deleted')
      load()
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <div>
      <div className="row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1 className="page-title">News Management</h1>
          <p className="page-sub">Create, publish, and manage news articles across the platform.</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancel' : '+ Create News'}
        </button>
      </div>

      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}

      {/* ── Create Form ────────────────────────────────────── */}
      {showForm && (
        <form onSubmit={handleCreate} className="card stack" style={{ marginBottom: 18 }}>
          <h3 style={{ color: 'var(--text)', fontSize: 15, fontWeight: 600 }}>New Article</h3>
          <div className="grid grid-2" style={{ gap: 12 }}>
            <div className="stack" style={{ gridColumn: '1 / -1' }}>
              <label className="field-label">Title *</label>
              <input
                className="input"
                placeholder="Article headline"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
              />
            </div>
            <div className="stack" style={{ gridColumn: '1 / -1' }}>
              <label className="field-label">Summary</label>
              <input
                className="input"
                placeholder="Short summary (1-2 sentences)"
                value={summary}
                onChange={(e) => setSummary(e.target.value)}
              />
            </div>
            <div className="stack" style={{ gridColumn: '1 / -1' }}>
              <label className="field-label">Full Body</label>
              <textarea
                className="textarea"
                placeholder="Full article body (markdown supported)"
                value={body}
                onChange={(e) => setBody(e.target.value)}
                style={{ minHeight: 160 }}
              />
            </div>
            <div className="stack">
              <label className="field-label">Image URL</label>
              <input
                className="input"
                placeholder="https://..."
                value={imageUrl}
                onChange={(e) => setImageUrl(e.target.value)}
              />
            </div>
            <div className="stack">
              <label className="field-label">Category</label>
              <select className="select" value={category} onChange={(e) => setCategory(e.target.value)}>
                {NEWS_CATEGORIES.map((c) => (
                  <option key={c} value={c}>{c.replace(/-/g, ' ').replace(/\b\w/g, (ch) => ch.toUpperCase())}</option>
                ))}
              </select>
            </div>
            <div className="stack">
              <label className="field-label">Tags (comma-separated)</label>
              <input
                className="input"
                placeholder="e.g. Simba, transfer, Ligi Kuu"
                value={tags}
                onChange={(e) => setTags(e.target.value)}
              />
            </div>
            <div className="stack">
              <label className="field-label">Source</label>
              <input
                className="input"
                placeholder="e.g. BBC Sport"
                value={source}
                onChange={(e) => setSource(e.target.value)}
              />
            </div>
            <div className="stack">
              <label className="field-label">Source URL</label>
              <input
                className="input"
                placeholder="https://..."
                value={sourceUrl}
                onChange={(e) => setSourceUrl(e.target.value)}
              />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, gridColumn: '1 / -1' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={isBreaking}
                  onChange={(e) => setIsBreaking(e.target.checked)}
                />
                <span style={{ fontSize: 13 }}>Mark as Breaking News</span>
              </label>
            </div>
          </div>
          <div className="row" style={{ justifyContent: 'flex-end', marginTop: 8 }}>
            <button type="submit" className="btn btn-primary" disabled={creating}>
              {creating ? 'Publishing...' : 'Publish Article'}
            </button>
          </div>
        </form>
      )}

      {/* ── Filter ─────────────────────────────────────────── */}
      <div className="toolbar">
        <input
          className="input"
          placeholder="Filter by title, category, source…"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          style={{ minWidth: 260 }}
        />
        <button className="btn" onClick={load}>Refresh</button>
      </div>

      {/* ── News Table ─────────────────────────────────────── */}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Category</th>
              <th>Source</th>
              <th>Views</th>
              <th>Engagement</th>
              <th>Published</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 && (
              <tr>
                <td colSpan={7} className="muted">No news articles yet</td>
              </tr>
            )}
            {filtered.map((n) => (
              <tr key={n.id}>
                <td style={{ maxWidth: 300 }}>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <strong style={{ fontSize: 13 }}>
                      {n.is_breaking && <span style={{ color: 'var(--red)', marginRight: 4 }}>BREAKING</span>}
                      {n.title}
                    </strong>
                    {n.summary && (
                      <span className="muted" style={{ fontSize: 11, lineHeight: 1.3 }}>
                        {n.summary.slice(0, 100)}{n.summary.length > 100 ? '…' : ''}
                      </span>
                    )}
                  </div>
                </td>
                <td><span className="badge">{n.category ?? 'general'}</span></td>
                <td className="muted" style={{ maxWidth: 120 }}>{n.source ?? '—'}</td>
                <td className="muted">{n.viewCount ?? 0}</td>
                <td className="muted">
                  ♥{n.likeCount ?? 0} · 💬{n.commentCount ?? 0} · ↗{n.shareCount ?? 0}
                </td>
                <td className="muted" style={{ fontSize: 11 }}>
                  {n.publishedAt ? new Date(n.publishedAt).toLocaleString() : '—'}
                </td>
                <td>
                  <button
                    className="btn btn-sm btn-danger"
                    onClick={() => handleDelete(n.id)}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
