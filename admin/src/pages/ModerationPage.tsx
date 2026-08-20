import { useCallback, useEffect, useState } from 'react'
import { useTableRealtime } from '../lib/realtime'
import { listPosts, deletePost } from '../lib/api'
import type { PostRow } from '../lib/supabase'

export function ModerationPage() {
  const [posts, setPosts] = useState<PostRow[]>([])
  const [err, setErr] = useState<string | null>(null)
  const [msg, setMsg] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setPosts(await listPosts(150))
      setErr(null)
    } catch (e: any) {
      setErr(e.message)
    }
  }, [])

  useEffect(() => { load() }, [load])
  useTableRealtime('Post', load)

  return (
    <div>
      <h1 className="page-title">Posts & News Moderation</h1>
      <p className="page-sub">Review, edit policy, and delete posts across the platform.</p>
      {msg && <p className="success">{msg}</p>}
      {err && <p className="error">{err}</p>}
      <div className="toolbar">
        <button className="btn" onClick={load}>Refresh</button>
      </div>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Content</th>
              <th>Engagement</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {posts.map((p) => (
              <tr key={p.id}>
                <td><span className="badge">{p.postType ?? 'post'}</span></td>
                <td style={{ maxWidth: 420 }}>
                  <div style={{ whiteSpace: 'pre-wrap' }}>{p.content?.slice(0, 180)}</div>
                  {p.mediaUrls?.[0] && (
                    <img src={p.mediaUrls[0]} alt="" height={48} style={{ marginTop: 6, objectFit: 'contain' }} />
                  )}
                </td>
                <td className="muted">{p.likeCount ?? 0} likes · {p.commentCount ?? 0} comments</td>
                <td className="muted">{p.createdAt ? new Date(p.createdAt).toLocaleString() : '—'}</td>
                <td>
                  <button
                    className="btn btn-sm btn-danger"
                    onClick={async () => {
                      await deletePost(p.id)
                      setMsg('Post deleted')
                      load()
                    }}
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
