import { useState } from 'react'
import { api } from '../lib/http'
import { createNews } from '../lib/api'

const MODES = [
  { id: 'news', label: 'Write news' },
  { id: 'article', label: 'Long article' },
  { id: 'moderate', label: 'Moderate text' },
  { id: 'chat', label: 'Chat assistant' },
  { id: 'caption', label: 'Image caption / post' },
] as const

export default function AiAssistantPage() {
  const [mode, setMode] = useState<typeof MODES[number]['id']>('news')
  const [prompt, setPrompt] = useState('')
  const [out, setOut] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [provider, setProvider] = useState<'anthropic' | 'deepseek'>('deepseek')

  async function run() {
    setLoading(true)
    setError(null)
    setOut('')
    try {
      const data = await api('/v1/ai', 'POST', { mode, prompt, provider })
      setOut(typeof data?.text === 'string' ? data.text : JSON.stringify(data, null, 2))
    } catch (e: any) {
      setError(e?.message ?? String(e))
      setOut('')
    } finally {
      setLoading(false)
    }
  }

  async function publishAsNews() {
    if (!out.trim()) return
    try {
      await createNews({ title: out.split('\n')[0].slice(0,120) || 'AI draft', body: out, summary: out.slice(0,180), category: 'updates', source: 'Playify AI' })
      setError(null)
    } catch (e) { setError(e instanceof Error ? e.message : 'Publishing failed') }
  }

  return (
    <div style={{ padding: 24, maxWidth: 900 }}>
      <h1 style={{ marginTop: 0 }}>AI Assistant</h1>
      <p style={{ opacity: 0.75 }}>
        Generate news, articles, moderation notes, and post captions. Keys stay on the server (Edge Function secrets) — never in the APK.
      </p>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
        {MODES.map((m) => (
          <button key={m.id} onClick={() => setMode(m.id)} style={{ fontWeight: mode === m.id ? 700 : 400 }}>
            {m.label}
          </button>
        ))}
      </div>
      <div style={{ marginBottom: 12 }}>
        <label>
          Provider{' '}
          <select value={provider} onChange={(e) => setProvider(e.target.value as any)}>
            <option value="deepseek">DeepSeek</option>
            <option value="anthropic">Anthropic Claude</option>
          </select>
        </label>
      </div>
      <textarea
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        rows={6}
        placeholder="e.g. Write a Ligi Kuu Bara match preview for Simba vs Yanga..."
        style={{ width: '100%', background: '#0B1626', color: '#fff', borderRadius: 8, padding: 12 }}
      />
      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <button onClick={run} disabled={loading || !prompt.trim()}>
          {loading ? 'Generating…' : 'Generate'}
        </button>
        <button onClick={publishAsNews} disabled={!out.trim()}>
          Publish as NewsItem
        </button>
      </div>
      {error && <p style={{ color: '#FF3B61' }}>{error}</p>}
      <pre style={{ marginTop: 16, whiteSpace: 'pre-wrap', background: '#061525', padding: 16, borderRadius: 8 }}>
        {out || 'Output appears here.'}
      </pre>
    </div>
  )
}
