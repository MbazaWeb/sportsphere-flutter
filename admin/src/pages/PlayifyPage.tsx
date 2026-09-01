import { useState } from 'react'
import { createOfficialPost } from '../lib/api'

export function PlayifyPage() {
  const [content, setContent] = useState('')
  const [mediaUrl, setMediaUrl] = useState('')
  const [type, setType] = useState('text')
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  async function publish() {
    try {
      setErr(null)
      await createOfficialPost(content, mediaUrl ? [mediaUrl] : [], type)
      setMsg('Published to playify feed')
      setContent('')
      setMediaUrl('')
    } catch (e: any) {
      setErr(e.message)
    }
  }

  return (
    <div>
      <h1 className="page-title">playify Official</h1>
      <p className="page-sub">Create posts, polls, and predictions from the official account.</p>

      <div className="card stack" style={{ maxWidth: 640 }}>
        <label className="muted">Type</label>
        <select className="select" value={type} onChange={(e) => setType(e.target.value)}>
          <option value="text">Post</option>
          <option value="poll">Poll</option>
          <option value="prediction">Prediction</option>
          <option value="welcome">Welcome</option>
        </select>
        <label className="muted">Content</label>
        <textarea className="textarea" value={content} onChange={(e) => setContent(e.target.value)} placeholder="Write the official update…" />
        <label className="muted">Media URL (optional logo / image)</label>
        <input className="input" value={mediaUrl} onChange={(e) => setMediaUrl(e.target.value)} placeholder="https://…/media/teams/simba-sc.png" />
        <div className="row">
          <button className="btn btn-primary" onClick={publish} disabled={!content.trim()}>Publish</button>
        </div>
        {msg && <div className="success">{msg}</div>}
        {err && <div className="error">{err}</div>}
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <h3>Official accounts</h3>
        <p className="hint">
          Use <strong>official@playify.app</strong> (playify Official) for platform posts.
          Team accounts created at seed can post as clubs after claim approval.
        </p>
      </div>
    </div>
  )
}
