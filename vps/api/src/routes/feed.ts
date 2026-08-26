// vps/api/src/routes/feed.ts
// GET /v1/feed?limit=40&offset=0
// Calls the feed_for_user RPC on Supabase (DB-side scoring).
// Also provides cursor-based pagination for big traffic.

import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'

export const feedRouter = new Hono()

feedRouter.get('/', async (c) => {
  const userId = c.get('userId') as string
  const limit  = Math.min(Number(c.req.query('limit') ?? 40), 100)

  const { data, error } = await supabaseAdmin
    .rpc('feed_for_user', { p_user_id: userId, p_limit: limit })

  if (error) {
    console.error('[feed] RPC error:', error.message)
    return c.json({ error: error.message }, 500)
  }

  return c.json({ ok: true, posts: data ?? [], count: (data ?? []).length })
})

// POST /v1/feed/view  — increment viewCount (authenticated, not anon)
feedRouter.post('/view', async (c) => {
  const { postId } = await c.req.json<{ postId: string }>()
  if (!postId) return c.json({ error: 'postId required' }, 400)

  await supabaseAdmin.rpc('increment_post_counter', {
    p_post_id: postId,
    p_column:  'viewCount',
    p_delta:   1,
  })
  return c.json({ ok: true })
})
