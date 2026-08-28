// vps/api/src/routes/news.ts
// Full news CRUD — replaces all Supabase calls in news_repository.dart
import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'

export const newsRouter = new Hono()

// GET /v1/news?category=&status=published&limit=40
newsRouter.get('/', async (c) => {
  const category = c.req.query('category')
  const status   = c.req.query('status') ?? 'published'
  const limit    = Math.min(Number(c.req.query('limit') ?? 40), 200)

  const params: unknown[] = [status, limit]
  let where = `WHERE n.status = $1`
  if (category) { params.splice(1, 0, category); where += ` AND n.category = $2`; params[params.length-1] = limit }

  const rows = await query(
    `SELECT n.*,
       COALESCE(n."likeCount",0)    as "likeCount",
       COALESCE(n."commentCount",0) as "commentCount",
       COALESCE(n."shareCount",0)   as "shareCount"
     FROM public."NewsItem" n
     ${category ? `WHERE n.status = $1 AND n.category = $2` : `WHERE n.status = $1`}
     ORDER BY n."publishedAt" DESC NULLS LAST, n."createdAt" DESC
     LIMIT $${category ? 3 : 2}`,
    category ? [status, category, limit] : [status, limit]
  )
  return c.json({ ok: true, news: rows })
})

// GET /v1/news/:id
newsRouter.get('/:id', async (c) => {
  const row = await queryOne(
    `SELECT * FROM public."NewsItem" WHERE id = $1`,
    [c.req.param('id')]
  )
  if (!row) return c.json({ error: 'Not found' }, 404)
  return c.json({ ok: true, news: row })
})

// GET /v1/news/:id/liked
newsRouter.get('/:id/liked', async (c) => {
  const userId = c.get('userId') as string
  const row    = await queryOne(
    `SELECT 1 FROM public.news_likes WHERE news_id=$1 AND user_id=$2`,
    [c.req.param('id'), userId]
  )
  return c.json({ ok: true, liked: !!row })
})

// POST /v1/news/:id/like
newsRouter.post('/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const newsId = c.req.param('id')
  await execute(
    `INSERT INTO public.news_likes(news_id, user_id, created_at)
     VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING`,
    [newsId, userId]
  )
  // trg_news_like_count trigger maintains likeCount
  const row = await queryOne<{ likeCount: number }>(
    `SELECT "likeCount" FROM public."NewsItem" WHERE id=$1`, [newsId]
  )
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

// DELETE /v1/news/:id/like
newsRouter.delete('/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const newsId = c.req.param('id')
  await execute(
    `DELETE FROM public.news_likes WHERE news_id=$1 AND user_id=$2`,
    [newsId, userId]
  )
  const row = await queryOne<{ likeCount: number }>(
    `SELECT "likeCount" FROM public."NewsItem" WHERE id=$1`, [newsId]
  )
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

// GET /v1/news/:id/comments
newsRouter.get('/:id/comments', async (c) => {
  const rows = await query(
    `SELECT nc.*, u.handle, u."avatarUrl", u.name
     FROM public.news_comments nc
     LEFT JOIN public."User" u ON u.id = nc.user_id
     WHERE nc.news_id=$1 ORDER BY nc.created_at ASC`,
    [c.req.param('id')]
  )
  return c.json({ ok: true, comments: rows })
})

// POST /v1/news/:id/comments
newsRouter.post('/:id/comments', async (c) => {
  const userId = c.get('userId') as string
  const newsId = c.req.param('id')
  const { content } = await c.req.json<{ content: string }>()
  if (!content?.trim()) return c.json({ error: 'content required' }, 400)
  const rows = await query(
    `INSERT INTO public.news_comments(id, news_id, user_id, content, created_at)
     VALUES(gen_random_uuid()::text,$1,$2,$3,NOW()) RETURNING *`,
    [newsId, userId, content.trim()]
  )
  return c.json({ ok: true, comment: rows[0] }, 201)
})

// POST /v1/news/:id/share
newsRouter.post('/:id/share', async (c) => {
  const newsId = c.req.param('id')
  await execute(
    `UPDATE public."NewsItem" SET "shareCount"=COALESCE("shareCount",0)+1 WHERE id=$1`,
    [newsId]
  )
  return c.json({ ok: true })
})
