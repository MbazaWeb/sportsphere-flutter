// vps/api/src/routes/social.ts
// Handles: posts, likes, comments, follows, fans, communities, profiles
import { Hono } from 'hono'
import { query, queryOne, execute, transaction } from '../lib/db.js'

export const socialRouter = new Hono()

// ── PROFILE ───────────────────────────────────────────────────────────────────

// GET /v1/social/profile/:handleOrId
socialRouter.get('/profile/:handleOrId', async (c) => {
  const key = c.req.param('handleOrId')
  const row = await queryOne(`
    SELECT u.*, p.bio, p.avatar_url, p.cover_url, p.dob, p.theme_color,
           p.is_verified, p.follower_count, p.following_count, p.post_count,
           p.latitude, p.longitude
    FROM public."User" u
    LEFT JOIN public.profiles p ON p.id::text = u.id
    WHERE u.handle = $1 OR u.id = $1
  `, [key.replace('@','')])
  if (!row) return c.json({ error: 'User not found' }, 404)
  return c.json({ ok: true, user: row })
})

// PATCH /v1/social/profile — update own profile
socialRouter.patch('/profile', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  const allowed = ['first_name','last_name','handle','bio','country','dob','avatar_url','cover_url','theme_color','website','phone']
  const sets: string[] = []; const params: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (allowed.includes(k)) { params.push(v); sets.push(`"${k}"=$${params.length}`) }
  }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(userId)
  await execute(`UPDATE public.profiles SET ${sets.join(',')}, updated_at=NOW() WHERE id=$${params.length}::uuid`, params)
  // Sync to User table
  const userMap: Record<string,string> = {first_name:'name',handle:'handle',avatar_url:'avatarUrl',cover_url:'coverUrl',bio:'bio',country:'currentCountry'}
  const uSets: string[] = []; const uParams: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (userMap[k]) { uParams.push(v); uSets.push(`"${userMap[k]}"=$${uParams.length}`) }
  }
  if (uSets.length) {
    uParams.push(userId)
    await execute(`UPDATE public."User" SET ${uSets.join(',')}, "updatedAt"=NOW() WHERE id=$${uParams.length}`, uParams)
  }
  return c.json({ ok: true })
})

// ── POSTS ─────────────────────────────────────────────────────────────────────

// GET /v1/social/posts/user/:userId
socialRouter.get('/posts/user/:uid', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 20), 100)
  const rows = await query(
    `SELECT p.*, u.handle, u."avatarUrl", u.name
     FROM public."Post" p JOIN public."User" u ON u.id=p."userId"
     WHERE p."userId"=$1 ORDER BY p."createdAt" DESC LIMIT $2`,
    [c.req.param('uid'), limit]
  )
  return c.json({ ok: true, posts: rows })
})

// POST /v1/social/posts — create post
socialRouter.post('/posts', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"postType","mediaUrls","hashtags","teamTag","sportTag","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,$7,NOW(),NOW()) RETURNING *`,
    [userId, b.content??'', b.postType??'post', JSON.stringify(b.mediaUrls??[]), JSON.stringify(b.hashtags??[]), b.teamTag??null, b.sportTag??null]
  )
  // Update post count
  await execute(`UPDATE public.profiles SET post_count=post_count+1 WHERE id=$1::uuid`, [userId])
  return c.json({ ok: true, post: rows[0] }, 201)
})

// DELETE /v1/social/posts/:id
socialRouter.delete('/posts/:id', async (c) => {
  const userId = c.get('userId') as string
  const postId = c.req.param('id')
  await execute(`DELETE FROM public."Post" WHERE id=$1 AND "userId"=$2`, [postId, userId])
  return c.json({ ok: true })
})

// ── LIKES ─────────────────────────────────────────────────────────────────────

// POST /v1/social/posts/:id/like
socialRouter.post('/posts/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const postId = c.req.param('id')
  await execute(
    `INSERT INTO public."PostLike"("postId","userId","createdAt") VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING`,
    [postId, userId]
  )
  // Counter maintained by trigger — but trigger may not exist on VPS pg yet, so also update directly
  await execute(`UPDATE public."Post" SET "likeCount"=GREATEST(COALESCE("likeCount",0)+1,0) WHERE id=$1 AND NOT EXISTS(SELECT 1 FROM public."PostLike" WHERE "postId"=$1 AND "userId"=$2 AND ctid <> (SELECT ctid FROM public."PostLike" WHERE "postId"=$1 AND "userId"=$2 LIMIT 1))`, [postId, userId]).catch(()=>{})
  const row = await queryOne<{likeCount:number}>(`SELECT "likeCount" FROM public."Post" WHERE id=$1`,[postId])
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

// DELETE /v1/social/posts/:id/like
socialRouter.delete('/posts/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const postId = c.req.param('id')
  const n = await execute(`DELETE FROM public."PostLike" WHERE "postId"=$1 AND "userId"=$2`, [postId, userId])
  if (n > 0) await execute(`UPDATE public."Post" SET "likeCount"=GREATEST(COALESCE("likeCount",0)-1,0) WHERE id=$1`, [postId])
  const row = await queryOne<{likeCount:number}>(`SELECT "likeCount" FROM public."Post" WHERE id=$1`,[postId])
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

// GET /v1/social/posts/:id/liked — check if current user liked
socialRouter.get('/posts/:id/liked', async (c) => {
  const userId = c.get('userId') as string
  const row = await queryOne(`SELECT 1 FROM public."PostLike" WHERE "postId"=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  return c.json({ ok: true, liked: !!row })
})

// ── COMMENTS ─────────────────────────────────────────────────────────────────

// GET /v1/social/posts/:id/comments
socialRouter.get('/posts/:id/comments', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows  = await query(
    `SELECT c.*, u.handle, u."avatarUrl", u.name
     FROM public."Comment" c JOIN public."User" u ON u.id=c."userId"
     WHERE c."postId"=$1 ORDER BY c."createdAt" ASC LIMIT $2`,
    [c.req.param('id'), limit]
  )
  return c.json({ ok: true, comments: rows })
})

// POST /v1/social/posts/:id/comments
socialRouter.post('/posts/:id/comments', async (c) => {
  const userId  = c.get('userId') as string
  const postId  = c.req.param('id')
  const { content, parentId } = await c.req.json<{content:string;parentId?:string}>()
  if (!content?.trim()) return c.json({ error: 'content required' }, 400)
  const rows = await query(
    `INSERT INTO public."Comment"(id,"postId","userId",content,"parentId","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4,NOW()) RETURNING *`,
    [postId, userId, content.trim(), parentId??null]
  )
  await execute(`UPDATE public."Post" SET "commentCount"=GREATEST(COALESCE("commentCount",0)+1,0) WHERE id=$1`, [postId])
  return c.json({ ok: true, comment: rows[0] }, 201)
})

// ── FOLLOWS ───────────────────────────────────────────────────────────────────

// POST /v1/social/follow/:targetId
socialRouter.post('/follow/:targetId', async (c) => {
  const userId   = c.get('userId') as string
  const targetId = c.req.param('targetId')
  if (userId === targetId) return c.json({ error: 'Cannot follow yourself' }, 400)
  await execute(
    `INSERT INTO public."Follow"("followerId","followingId","createdAt") VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING`,
    [userId, targetId]
  )
  await execute(`UPDATE public.profiles SET following_count=following_count+1 WHERE id=$1::uuid`, [userId])
  await execute(`UPDATE public.profiles SET follower_count=follower_count+1 WHERE id=$1::uuid`, [targetId])
  // Notification
  await execute(
    `INSERT INTO public."Notification"(id,"userId",type,title,body,"isRead","actorId","createdAt")
     VALUES(gen_random_uuid()::text,$1,'follow','New follower','Someone started following you',false,$2,NOW())`,
    [targetId, userId]
  ).catch(()=>{})
  return c.json({ ok: true })
})

// DELETE /v1/social/follow/:targetId
socialRouter.delete('/follow/:targetId', async (c) => {
  const userId   = c.get('userId') as string
  const targetId = c.req.param('targetId')
  const n = await execute(`DELETE FROM public."Follow" WHERE "followerId"=$1 AND "followingId"=$2`, [userId, targetId])
  if (n > 0) {
    await execute(`UPDATE public.profiles SET following_count=GREATEST(following_count-1,0) WHERE id=$1::uuid`, [userId])
    await execute(`UPDATE public.profiles SET follower_count=GREATEST(follower_count-1,0) WHERE id=$1::uuid`, [targetId])
  }
  return c.json({ ok: true })
})

// GET /v1/social/follow/:targetId/status
socialRouter.get('/follow/:targetId/status', async (c) => {
  const userId   = c.get('userId') as string
  const targetId = c.req.param('targetId')
  const row = await queryOne(`SELECT 1 FROM public."Follow" WHERE "followerId"=$1 AND "followingId"=$2`, [userId, targetId])
  return c.json({ ok: true, following: !!row })
})

// ── FANS ──────────────────────────────────────────────────────────────────────

// POST /v1/social/fan/:entityType/:entityId
socialRouter.post('/fan/:entityType/:entityId', async (c) => {
  const userId     = c.get('userId') as string
  const entityType = c.req.param('entityType')
  const entityId   = c.req.param('entityId')
  await execute(
    `INSERT INTO public.entity_follows(id,follower_id,entity_type,entity_id,is_fan,created_at)
     VALUES(gen_random_uuid(),$1::uuid,$2,$3,true,NOW()) ON CONFLICT(follower_id,entity_type,entity_id) DO NOTHING`,
    [userId, entityType, entityId]
  )
  return c.json({ ok: true })
})

// DELETE /v1/social/fan/:entityType/:entityId
socialRouter.delete('/fan/:entityType/:entityId', async (c) => {
  const userId     = c.get('userId') as string
  const entityType = c.req.param('entityType')
  const entityId   = c.req.param('entityId')
  await execute(
    `DELETE FROM public.entity_follows WHERE follower_id=$1::uuid AND entity_type=$2 AND entity_id=$3`,
    [userId, entityType, entityId]
  )
  return c.json({ ok: true })
})

// GET /v1/social/fan/:entityType/:entityId/status
socialRouter.get('/fan/:entityType/:entityId/status', async (c) => {
  const userId     = c.get('userId') as string
  const entityType = c.req.param('entityType')
  const entityId   = c.req.param('entityId')
  const row = await queryOne(
    `SELECT 1 FROM public.entity_follows WHERE follower_id=$1::uuid AND entity_type=$2 AND entity_id=$3`,
    [userId, entityType, entityId]
  )
  return c.json({ ok: true, isFan: !!row })
})

// ── MESSAGES ──────────────────────────────────────────────────────────────────

// GET /v1/social/messages/:withUserId
socialRouter.get('/messages/:withUserId', async (c) => {
  const userId      = c.get('userId') as string
  const withUserId  = c.req.param('withUserId')
  const limit       = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows = await query(
    `SELECT * FROM public."Message"
     WHERE ("senderId"=$1 AND "receiverId"=$2) OR ("senderId"=$2 AND "receiverId"=$1)
     ORDER BY "createdAt" DESC LIMIT $3`,
    [userId, withUserId, limit]
  )
  return c.json({ ok: true, messages: rows.reverse() })
})

// POST /v1/social/messages — send DM
socialRouter.post('/messages', async (c) => {
  const userId = c.get('userId') as string
  const { receiverId, content } = await c.req.json<{receiverId:string;content:string}>()
  if (!receiverId || !content?.trim()) return c.json({ error: 'receiverId and content required' }, 400)
  if (userId === receiverId) return c.json({ error: 'Cannot message yourself' }, 400)
  const rows = await query(
    `INSERT INTO public."Message"(id,"senderId","receiverId",content,"isRead","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,false,NOW()) RETURNING *`,
    [userId, receiverId, content.trim()]
  )
  return c.json({ ok: true, message: rows[0] }, 201)
})

// ── COMMUNITIES ───────────────────────────────────────────────────────────────

// GET /v1/social/communities
socialRouter.get('/communities', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 20), 100)
  const rows  = await query(`SELECT * FROM public."Community" ORDER BY "memberCount" DESC LIMIT $1`, [limit])
  return c.json({ ok: true, communities: rows })
})

// POST /v1/social/communities/:id/join
socialRouter.post('/communities/:id/join', async (c) => {
  const userId      = c.get('userId') as string
  const communityId = c.req.param('id')
  await execute(
    `INSERT INTO public."CommunityMember"("communityId","userId",role,"joinedAt")
     VALUES($1,$2,'member',NOW()) ON CONFLICT DO NOTHING`,
    [communityId, userId]
  )
  await execute(
    `UPDATE public."Community" SET "memberCount"=(SELECT COUNT(*) FROM public."CommunityMember" WHERE "communityId"=$1) WHERE id=$1`,
    [communityId]
  )
  return c.json({ ok: true })
})

// DELETE /v1/social/communities/:id/leave
socialRouter.delete('/communities/:id/leave', async (c) => {
  const userId      = c.get('userId') as string
  const communityId = c.req.param('id')
  await execute(`DELETE FROM public."CommunityMember" WHERE "communityId"=$1 AND "userId"=$2`, [communityId, userId])
  await execute(
    `UPDATE public."Community" SET "memberCount"=(SELECT COUNT(*) FROM public."CommunityMember" WHERE "communityId"=$1) WHERE id=$1`,
    [communityId]
  )
  return c.json({ ok: true })
})

// GET /v1/social/communities/:id/member
socialRouter.get('/communities/:id/member', async (c) => {
  const userId = c.get('userId') as string
  const row    = await queryOne(`SELECT 1 FROM public."CommunityMember" WHERE "communityId"=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  return c.json({ ok: true, isMember: !!row })
})
