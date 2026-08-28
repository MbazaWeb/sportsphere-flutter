// vps/api/src/routes/feed.ts
import { Hono } from 'hono'
import { query, execute } from '../lib/db.js'

export const feedRouter = new Hono()

// GET /v1/feed?limit=40
feedRouter.get('/', async (c) => {
  const userId = c.get('userId') as string
  const limit  = Math.min(Number(c.req.query('limit') ?? 40), 100)

  const posts = await query(`
    WITH sports AS (
      SELECT s.slug FROM public."UserSport" us
      JOIN public."Sport" s ON s.id = us."sportId"
      WHERE us."userId" = $1
    ),
    followed AS (
      SELECT "followingId" AS uid FROM public."Follow" WHERE "followerId" = $1
    )
    SELECT
      p.id, p."userId", p.content, p."postType", p."mediaUrls",
      p."hashtags", p."teamTag", p."sportTag", p."likeCount",
      p."commentCount", p."shareCount", p."createdAt",
      u.handle, u."avatarUrl", u.name,
      (1.0
        + CASE WHEN COALESCE(p."sportTag",'') IN (SELECT slug FROM sports) THEN 4.0 ELSE 0 END
        + CASE WHEN p."userId" IN (SELECT uid FROM followed) THEN 5.0 ELSE 0 END
        + LEAST(COALESCE(p."likeCount",0), 50) * 0.05
        + LEAST(COALESCE(p."commentCount",0), 30) * 0.08
        + CASE WHEN p."postType" = 'live_coverage' THEN 2.0 ELSE 0 END
        + CASE WHEN p."createdAt" > NOW() - INTERVAL '6 hours' THEN 3.0
               WHEN p."createdAt" > NOW() - INTERVAL '2 days' THEN 1.5
               ELSE 0.2 END
      )::numeric AS score
    FROM public."Post" p
    JOIN public."User" u ON u.id = p."userId"
    ORDER BY score DESC, p."createdAt" DESC
    LIMIT $2
  `, [userId, limit])

  return c.json({ ok: true, posts, count: posts.length })
})

// POST /v1/feed/view
feedRouter.post('/view', async (c) => {
  const { postId } = await c.req.json<{ postId: string }>()
  if (!postId) return c.json({ error: 'postId required' }, 400)
  await execute(
    `UPDATE public."Post" SET "viewCount" = COALESCE("viewCount",0) + 1 WHERE id = $1`,
    [postId]
  )
  return c.json({ ok: true })
})

// GET /v1/feed/trending?limit=30
feedRouter.get('/trending', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 30), 100)
  const posts = await query(
    `SELECT p.*, u.handle, u."avatarUrl", u.name
     FROM public."Post" p
     JOIN public."User" u ON u.id = p."userId"
     ORDER BY p."likeCount" DESC, p."createdAt" DESC
     LIMIT $1`,
    [limit]
  )
  return c.json({ ok: true, posts })
})
