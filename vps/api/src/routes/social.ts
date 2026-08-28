// vps/api/src/routes/social.ts
// Handles: posts, likes, comments, follows, fans, communities, profiles
import { Hono } from 'hono'
import { query, queryOne, execute, transaction } from '../lib/db.js'

export const socialRouter = new Hono()

// ── PROFILE ───────────────────────────────────────────────────────────────────

socialRouter.get('/profile/:handleOrId', async (c) => {
  const key = c.req.param('handleOrId').replace('@','')
  const row = await queryOne(`
    SELECT u.id, u.name, u.handle, u.email, u.role, u."avatarUrl", u."coverUrl",
           u."isVerified", u."registeredAt",
           p.bio, p.avatar_url, p.cover_url, p.dob, p.theme_color,
           p.is_verified, p.is_pro,
           COALESCE(p.post_count,0)      AS "postCount",
           COALESCE(p.follower_count,0)  AS "followerCount",
           COALESCE(p.following_count,0) AS "followingCount",
           COALESCE(p.fan_count,0)       AS "fanCount",
           (SELECT COUNT(*) FROM public."PostLike" pl
            JOIN public."Post" pp ON pp.id=pl."postId"
            WHERE pp."userId"=u.id)      AS "totalLikesReceived",
           p.latitude, p.longitude, p.country
    FROM public."User" u
    LEFT JOIN public.profiles p ON p.id::text = u.id
    WHERE u.handle = $1 OR u.id = $1
  `, [key])
  if (!row) return c.json({ error: 'User not found' }, 404)
  return c.json({ ok: true, user: row })
})

socialRouter.patch('/profile', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  const allowed = ['first_name','last_name','handle','bio','country','dob',
                   'avatar_url','cover_url','theme_color','website','phone','about_me']
  const sets: string[] = []; const params: unknown[] = []
  for (const [k,v] of Object.entries(b)) {
    if (allowed.includes(k)) { params.push(v); sets.push(`"${k}"=$${params.length}`) }
  }
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(userId)
  await execute(`UPDATE public.profiles SET ${sets.join(',')}, updated_at=NOW() WHERE id=$${params.length}::uuid`, params)
  const userMap: Record<string,string> = {
    first_name:'name', handle:'handle',
    avatar_url:'avatarUrl', cover_url:'coverUrl',
    bio:'bio', country:'currentCountry'
  }
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

socialRouter.get('/posts/user/:uid', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 20), 100)
  const rows = await query(
    `SELECT p.*, u.handle, u."avatarUrl", u.name, u.role
     FROM public."Post" p JOIN public."User" u ON u.id=p."userId"
     WHERE p."userId"=$1 ORDER BY p."createdAt" DESC LIMIT $2`,
    [c.req.param('uid'), limit]
  )
  return c.json({ ok: true, posts: rows })
})

socialRouter.post('/posts', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"postType","mediaUrls","hashtags",
       "teamTag","playerTag","sportTag","communityId","matchId","isBreaking",
       "likeCount","commentCount","shareCount","viewCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4::jsonb,$5::jsonb,$6,$7,$8,$9,$10,$11,0,0,0,0,NOW(),NOW())
     RETURNING *`,
    [userId, b.content??'', b.postType??'post',
     JSON.stringify(b.mediaUrls??[]), JSON.stringify(b.hashtags??[]),
     b.teamTag??null, b.playerTag??null, b.sportTag??null,
     b.communityId??null, b.matchId??null, b.isBreaking??false]
  )
  await execute(`UPDATE public.profiles SET post_count=COALESCE(post_count,0)+1 WHERE id=$1::uuid`, [userId])
  return c.json({ ok: true, post: rows[0] }, 201)
})

socialRouter.delete('/posts/:id', async (c) => {
  const userId = c.get('userId') as string
  const n = await execute(`DELETE FROM public."Post" WHERE id=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  if (n > 0) await execute(`UPDATE public.profiles SET post_count=GREATEST(COALESCE(post_count,0)-1,0) WHERE id=$1::uuid`, [userId])
  return c.json({ ok: true })
})

// ── LIKES (atomic) ────────────────────────────────────────────────────────────

socialRouter.post('/posts/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const postId = c.req.param('id')
  // Atomic: insert + conditional increment in one query
  await query(`
    WITH ins AS (
      INSERT INTO public."PostLike"("postId","userId","createdAt")
      VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING
      RETURNING 1
    )
    UPDATE public."Post" SET "likeCount"=COALESCE("likeCount",0)+1
    WHERE id=$1 AND EXISTS(SELECT 1 FROM ins)
  `, [postId, userId])
  const row = await queryOne<{likeCount:number}>(`SELECT "likeCount" FROM public."Post" WHERE id=$1`,[postId])
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

socialRouter.delete('/posts/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const postId = c.req.param('id')
  await query(`
    WITH del AS (
      DELETE FROM public."PostLike" WHERE "postId"=$1 AND "userId"=$2 RETURNING 1
    )
    UPDATE public."Post" SET "likeCount"=GREATEST(COALESCE("likeCount",0)-1,0)
    WHERE id=$1 AND EXISTS(SELECT 1 FROM del)
  `, [postId, userId])
  const row = await queryOne<{likeCount:number}>(`SELECT "likeCount" FROM public."Post" WHERE id=$1`,[postId])
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

socialRouter.get('/posts/:id/liked', async (c) => {
  const userId = c.get('userId') as string
  const row = await queryOne(`SELECT 1 FROM public."PostLike" WHERE "postId"=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  return c.json({ ok: true, liked: !!row })
})

// ── SHARES ────────────────────────────────────────────────────────────────────

socialRouter.post('/posts/:id/share', async (c) => {
  const userId = c.get('userId') as string
  const postId = c.req.param('id')
  await query(`
    WITH ins AS (
      INSERT INTO public."PostShare"("postId","userId","createdAt")
      VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING RETURNING 1
    )
    UPDATE public."Post" SET "shareCount"=COALESCE("shareCount",0)+1
    WHERE id=$1 AND EXISTS(SELECT 1 FROM ins)
  `, [postId, userId])
  const row = await queryOne<{shareCount:number}>(`SELECT "shareCount" FROM public."Post" WHERE id=$1`,[postId])
  return c.json({ ok: true, shareCount: row?.shareCount ?? 0 })
})

socialRouter.get('/posts/:id/shared', async (c) => {
  const userId = c.get('userId') as string
  const row = await queryOne(`SELECT 1 FROM public."PostShare" WHERE "postId"=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  return c.json({ ok: true, shared: !!row })
})

// ── COMMENTS + REPLIES ────────────────────────────────────────────────────────

socialRouter.get('/posts/:id/comments', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200)
  // Return threaded: top-level + replies nested under parent
  const rows = await query(
    `SELECT c.*, u.handle, u."avatarUrl", u.name, u.role,
            COALESCE(c."likeCount",0) AS "likeCount"
     FROM public."Comment" c JOIN public."User" u ON u.id=c."userId"
     WHERE c."postId"=$1 ORDER BY c."createdAt" ASC LIMIT $2`,
    [c.req.param('id'), limit]
  )
  // Build tree: top-level + replies
  const topLevel = rows.filter((r:any) => !r.parentId)
  const replies   = rows.filter((r:any) => !!r.parentId)
  const threaded  = topLevel.map((r:any) => ({
    ...r,
    replies: replies.filter((rep:any) => rep.parentId === r.id)
  }))
  return c.json({ ok: true, comments: threaded, total: rows.length })
})

socialRouter.post('/posts/:id/comments', async (c) => {
  const userId  = c.get('userId') as string
  const postId  = c.req.param('id')
  const { content, parentId, mentionedUserIds } =
    await c.req.json<{content:string;parentId?:string;mentionedUserIds?:string[]}>()
  if (!content?.trim()) return c.json({ error: 'content required' }, 400)

  const rows = await query(
    `INSERT INTO public."Comment"(id,"postId","userId",content,"parentId","mentionedUserIds","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5::jsonb,NOW()) RETURNING *`,
    [postId, userId, content.trim(), parentId??null,
     JSON.stringify(mentionedUserIds??[])]
  )
  // Atomic comment count increment
  await execute(`UPDATE public."Post" SET "commentCount"=COALESCE("commentCount",0)+1 WHERE id=$1`, [postId])
  return c.json({ ok: true, comment: rows[0] }, 201)
})

// Like a comment
socialRouter.post('/comments/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const commentId = c.req.param('id')
  await query(`
    WITH ins AS (
      INSERT INTO public."CommentLike"("commentId","userId","createdAt")
      VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING RETURNING 1
    )
    UPDATE public."Comment" SET "likeCount"=COALESCE("likeCount",0)+1
    WHERE id=$1 AND EXISTS(SELECT 1 FROM ins)
  `, [commentId, userId])
  const row = await queryOne<{likeCount:number}>(`SELECT "likeCount" FROM public."Comment" WHERE id=$1`,[commentId])
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

socialRouter.delete('/comments/:id/like', async (c) => {
  const userId = c.get('userId') as string
  const commentId = c.req.param('id')
  await query(`
    WITH del AS (
      DELETE FROM public."CommentLike" WHERE "commentId"=$1 AND "userId"=$2 RETURNING 1
    )
    UPDATE public."Comment" SET "likeCount"=GREATEST(COALESCE("likeCount",0)-1,0)
    WHERE id=$1 AND EXISTS(SELECT 1 FROM del)
  `, [commentId, userId])
  const row = await queryOne<{likeCount:number}>(`SELECT "likeCount" FROM public."Comment" WHERE id=$1`,[commentId])
  return c.json({ ok: true, likeCount: row?.likeCount ?? 0 })
})

// ── FOLLOWS (user→user) ───────────────────────────────────────────────────────

socialRouter.post('/follow/:targetId', async (c) => {
  const userId   = c.get('userId') as string
  const targetId = c.req.param('targetId')
  if (userId === targetId) return c.json({ error: 'Cannot follow yourself' }, 400)
  await query(`
    WITH ins AS (
      INSERT INTO public."Follow"("followerId","followingId","createdAt")
      VALUES($1,$2,NOW()) ON CONFLICT DO NOTHING RETURNING 1
    )
    UPDATE public.profiles SET following_count=COALESCE(following_count,0)+1
    WHERE id=$1::uuid AND EXISTS(SELECT 1 FROM ins)
  `, [userId, targetId])
  await execute(`UPDATE public.profiles SET follower_count=COALESCE(follower_count,0)+1 WHERE id=$1::uuid AND EXISTS(SELECT 1 FROM public."Follow" WHERE "followerId"=$2 AND "followingId"=$1)`, [targetId, userId])
  await execute(
    `INSERT INTO public."Notification"(id,"userId",type,title,body,"isRead","actorId","createdAt")
     VALUES(gen_random_uuid()::text,$1,'follow','New follower','Someone started following you',false,$2,NOW())`,
    [targetId, userId]
  ).catch(()=>{})
  return c.json({ ok: true })
})

socialRouter.delete('/follow/:targetId', async (c) => {
  const userId   = c.get('userId') as string
  const targetId = c.req.param('targetId')
  await query(`
    WITH del AS (
      DELETE FROM public."Follow" WHERE "followerId"=$1 AND "followingId"=$2 RETURNING 1
    )
    UPDATE public.profiles SET following_count=GREATEST(COALESCE(following_count,0)-1,0)
    WHERE id=$1::uuid AND EXISTS(SELECT 1 FROM del)
  `, [userId, targetId])
  await execute(`UPDATE public.profiles SET follower_count=GREATEST(COALESCE(follower_count,0)-1,0) WHERE id=$1::uuid`, [targetId])
  return c.json({ ok: true })
})

socialRouter.get('/follow/:targetId/status', async (c) => {
  const userId   = c.get('userId') as string
  const row = await queryOne(`SELECT 1 FROM public."Follow" WHERE "followerId"=$1 AND "followingId"=$2`, [userId, c.req.param('targetId')])
  return c.json({ ok: true, following: !!row })
})

// GET followers list
socialRouter.get('/followers/:userId', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows = await query(
    `SELECT u.id, u.handle, u.name, u."avatarUrl", u.role
     FROM public."Follow" f JOIN public."User" u ON u.id=f."followerId"
     WHERE f."followingId"=$1 ORDER BY f."createdAt" DESC LIMIT $2`,
    [c.req.param('userId'), limit]
  )
  return c.json({ ok: true, followers: rows })
})

// GET following list
socialRouter.get('/following/:userId', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows = await query(
    `SELECT u.id, u.handle, u.name, u."avatarUrl", u.role
     FROM public."Follow" f JOIN public."User" u ON u.id=f."followingId"
     WHERE f."followerId"=$1 ORDER BY f."createdAt" DESC LIMIT $2`,
    [c.req.param('userId'), limit]
  )
  return c.json({ ok: true, following: rows })
})

// ── FANS (user→entity: team/player/coach/league/venue) ───────────────────────
// Fans are distinct from followers:
//   Follow = user→user (social graph)
//   Fan    = user→entity (team/player/coach etc.)

const FAN_ENTITY_TYPES = ['team','player','coach','league','venue','community','competition']

socialRouter.post('/fan/:entityType/:entityId', async (c) => {
  const userId     = c.get('userId') as string
  const entityType = c.req.param('entityType').toLowerCase()
  const entityId   = c.req.param('entityId')
  if (!FAN_ENTITY_TYPES.includes(entityType)) {
    return c.json({ error: `Invalid entity type: ${entityType}` }, 400)
  }
  await execute(
    `INSERT INTO public.entity_follows(id,follower_id,entity_type,entity_id,is_fan,created_at)
     VALUES(gen_random_uuid(),$1::uuid,$2,$3,true,NOW())
     ON CONFLICT(follower_id,entity_type,entity_id) DO NOTHING`,
    [userId, entityType, entityId]
  )
  // Increment fan_count on profiles if entity has an account
  await execute(
    `UPDATE public.profiles SET fan_count=COALESCE(fan_count,0)+1
     WHERE id=(SELECT id FROM public.profiles WHERE handle=$1 LIMIT 1)`,
    [entityId]
  ).catch(()=>{})
  return c.json({ ok: true })
})

socialRouter.delete('/fan/:entityType/:entityId', async (c) => {
  const userId     = c.get('userId') as string
  const entityType = c.req.param('entityType').toLowerCase()
  const entityId   = c.req.param('entityId')
  const n = await execute(
    `DELETE FROM public.entity_follows WHERE follower_id=$1::uuid AND entity_type=$2 AND entity_id=$3`,
    [userId, entityType, entityId]
  )
  if (n > 0) {
    await execute(
      `UPDATE public.profiles SET fan_count=GREATEST(COALESCE(fan_count,0)-1,0)
       WHERE id=(SELECT id FROM public.profiles WHERE handle=$1 LIMIT 1)`,
      [entityId]
    ).catch(()=>{})
  }
  return c.json({ ok: true })
})

socialRouter.get('/fan/:entityType/:entityId/status', async (c) => {
  const userId     = c.get('userId') as string
  const row = await queryOne(
    `SELECT 1 FROM public.entity_follows WHERE follower_id=$1::uuid AND entity_type=$2 AND entity_id=$3`,
    [userId, c.req.param('entityType'), c.req.param('entityId')]
  )
  return c.json({ ok: true, isFan: !!row })
})

// GET all fans of an entity
socialRouter.get('/fan/:entityType/:entityId/fans', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows = await query(
    `SELECT u.id, u.handle, u.name, u."avatarUrl", u.role, ef.created_at
     FROM public.entity_follows ef JOIN public."User" u ON u.id=ef.follower_id::text
     WHERE ef.entity_type=$1 AND ef.entity_id=$2 AND ef.is_fan=true
     ORDER BY ef.created_at DESC LIMIT $3`,
    [c.req.param('entityType'), c.req.param('entityId'), limit]
  )
  const total = await queryOne<{count:string}>(
    `SELECT COUNT(*) as count FROM public.entity_follows WHERE entity_type=$1 AND entity_id=$2 AND is_fan=true`,
    [c.req.param('entityType'), c.req.param('entityId')]
  )
  return c.json({ ok: true, fans: rows, total: Number(total?.count ?? 0) })
})

// GET all entities a user fans
socialRouter.get('/fan/my-entities', async (c) => {
  const userId = c.get('userId') as string
  const rows = await query(
    `SELECT entity_type, entity_id, created_at FROM public.entity_follows
     WHERE follower_id=$1::uuid AND is_fan=true ORDER BY created_at DESC`,
    [userId]
  )
  return c.json({ ok: true, entities: rows })
})

// ── MESSAGES (DM) ─────────────────────────────────────────────────────────────

socialRouter.get('/messages/:withUserId', async (c) => {
  const userId     = c.get('userId') as string
  const withUserId = c.req.param('withUserId')
  const limit      = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows = await query(
    `SELECT m.*, u.handle, u."avatarUrl", u.name
     FROM public."Message" m JOIN public."User" u ON u.id=m."senderId"
     WHERE ("senderId"=$1 AND "receiverId"=$2) OR ("senderId"=$2 AND "receiverId"=$1)
     ORDER BY m."createdAt" DESC LIMIT $3`,
    [userId, withUserId, limit]
  )
  return c.json({ ok: true, messages: rows.reverse() })
})

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
  // Notify recipient
  await execute(
    `INSERT INTO public."Notification"(id,"userId",type,title,body,"isRead","actorId","createdAt")
     VALUES(gen_random_uuid()::text,$1,'message','New message',$2,false,$3,NOW())`,
    [receiverId, content.trim().substring(0,80), userId]
  ).catch(()=>{})
  return c.json({ ok: true, message: rows[0] }, 201)
})

// GET conversations list (latest message per user)
socialRouter.get('/messages', async (c) => {
  const userId = c.get('userId') as string
  const rows = await query(
    `SELECT DISTINCT ON (partner_id)
       CASE WHEN "senderId"=$1 THEN "receiverId" ELSE "senderId" END AS partner_id,
       content, "isRead", "createdAt"
     FROM public."Message"
     WHERE "senderId"=$1 OR "receiverId"=$1
     ORDER BY partner_id, "createdAt" DESC`,
    [userId]
  )
  return c.json({ ok: true, conversations: rows })
})

// ── COMMUNITIES ───────────────────────────────────────────────────────────────

socialRouter.get('/communities', async (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 20), 100)
  const rows  = await query(
    `SELECT * FROM public."Community" ORDER BY "memberCount" DESC LIMIT $1`, [limit]
  )
  return c.json({ ok: true, communities: rows })
})

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

socialRouter.get('/communities/:id/member', async (c) => {
  const userId = c.get('userId') as string
  const row    = await queryOne(`SELECT 1 FROM public."CommunityMember" WHERE "communityId"=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  return c.json({ ok: true, isMember: !!row })
})

// ── POLLS ─────────────────────────────────────────────────────────────────────

socialRouter.post('/polls', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  if (!b.postId || !b.question) return c.json({ error: 'postId and question required' }, 400)
  const rows = await query(
    `INSERT INTO public."Poll"(id,"postId","matchId",question,options,"totalVotes","endsAt","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4::jsonb,0,$5,NOW()) RETURNING *`,
    [b.postId, b.matchId??null, b.question,
     JSON.stringify(b.options??[]),
     b.endsAt??null]
  )
  return c.json({ ok: true, poll: rows[0] }, 201)
})

// Route order matters — /by-poll/:id before /:postId
socialRouter.get('/polls/by-poll/:pollId', async (c) => {
  const row = await queryOne(`SELECT * FROM public."Poll" WHERE id=$1`, [c.req.param('pollId')])
  return c.json({ ok: true, poll: row ?? null })
})

socialRouter.get('/polls/:postId', async (c) => {
  const row = await queryOne(`SELECT * FROM public."Poll" WHERE "postId"=$1`, [c.req.param('postId')])
  return c.json({ ok: true, poll: row ?? null })
})

socialRouter.get('/polls/:id/my-vote', async (c) => {
  const userId = c.get('userId') as string
  const row    = await queryOne<{optionIndex:number}>(
    `SELECT "optionIndex" FROM public."PollVote" WHERE "pollId"=$1 AND "userId"=$2`,
    [c.req.param('id'), userId]
  )
  return c.json({ ok: true, voted: row ? row.optionIndex : null })
})

socialRouter.post('/polls/:id/vote', async (c) => {
  const userId      = c.get('userId') as string
  const pollId      = c.req.param('id')
  const { optionIndex } = await c.req.json<{optionIndex:number}>()
  if (optionIndex === undefined || optionIndex < 0) return c.json({ error: 'optionIndex required' }, 400)

  // One vote per user — upsert
  await execute(
    `INSERT INTO public."PollVote"(id,"pollId","userId","optionIndex","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,NOW())
     ON CONFLICT("pollId","userId") DO UPDATE SET "optionIndex"=$3`,
    [pollId, userId, optionIndex]
  )
  // Update totalVotes + option vote counts in options JSONB
  await execute(
    `UPDATE public."Poll" SET "totalVotes"=(SELECT COUNT(*) FROM public."PollVote" WHERE "pollId"=$1) WHERE id=$1`,
    [pollId]
  )
  const rows = await query<{optionIndex:number;cnt:string}>(
    `SELECT "optionIndex", COUNT(*) as cnt FROM public."PollVote" WHERE "pollId"=$1 GROUP BY "optionIndex"`,
    [pollId]
  )
  const counts: Record<number,number> = {}
  rows.forEach(r => { counts[r.optionIndex] = Number(r.cnt) })
  return c.json({ ok: true, counts })
})

socialRouter.delete('/polls/:id/vote', async (c) => {
  const userId = c.get('userId') as string
  await execute(`DELETE FROM public."PollVote" WHERE "pollId"=$1 AND "userId"=$2`, [c.req.param('id'), userId])
  await execute(`UPDATE public."Poll" SET "totalVotes"=(SELECT COUNT(*) FROM public."PollVote" WHERE "pollId"=$1) WHERE id=$1`, [c.req.param('id')])
  return c.json({ ok: true })
})

// ── PREDICTIONS ───────────────────────────────────────────────────────────────

socialRouter.post('/predictions', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  if (!b.homeTeam || !b.awayTeam) return c.json({ error: 'homeTeam and awayTeam required' }, 400)
  const rows = await query(
    `INSERT INTO public."Prediction"(id,"userId","homeTeam","awayTeam",
       "predictedHome","predictedAway","outcome","confidence","matchId","postId","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,$7,$8,$9,NOW()) RETURNING *`,
    [userId, b.homeTeam, b.awayTeam,
     b.predictedHome??null, b.predictedAway??null,
     b.outcome??null, b.confidence??null,
     b.matchId??null, b.postId??null]
  )
  return c.json({ ok: true, prediction: rows[0], id: (rows[0] as any)?.id ?? '' }, 201)
})

socialRouter.get('/predictions/by-post/:postId', async (c) => {
  const row = await queryOne(`SELECT * FROM public."Prediction" WHERE "postId"=$1`, [c.req.param('postId')])
  return c.json({ ok: true, prediction: row ?? null })
})

// ── SPORTS & USER SPORTS ──────────────────────────────────────────────────────

socialRouter.get('/sports', async (c) => {
  const rows = await query(`SELECT * FROM public."Sport" WHERE "isActive"=true ORDER BY "displayOrder" ASC`)
  return c.json({ ok: true, sports: rows })
})

socialRouter.get('/my-sports', async (c) => {
  const userId = c.get('userId') as string
  const rows = await query(
    `SELECT us."sportId", s.slug, s.name, s.icon FROM public."UserSport" us
     JOIN public."Sport" s ON s.id=us."sportId" WHERE us."userId"=$1`,
    [userId]
  )
  return c.json({ ok: true, slugs: rows.map((r:any) => r.slug), sports: rows })
})

socialRouter.post('/my-sports', async (c) => {
  const userId = c.get('userId') as string
  const { slugs, primary } = await c.req.json<{slugs:string[];primary?:string}>()
  await execute(`DELETE FROM public."UserSport" WHERE "userId"=$1`, [userId])
  for (const slug of (slugs??[])) {
    const sport = await queryOne<{id:string}>(`SELECT id FROM public."Sport" WHERE slug=$1`, [slug])
    if (!sport) continue
    await execute(
      `INSERT INTO public."UserSport"(id,"userId","sportId","isPrimary","weight","createdAt")
       VALUES(gen_random_uuid()::text,$1,$2,$3,1,NOW()) ON CONFLICT DO NOTHING`,
      [userId, sport.id, slug === primary]
    )
  }
  return c.json({ ok: true })
})

// ── BATCH PROFILES (N+1 fix) ──────────────────────────────────────────────────

socialRouter.post('/profiles/batch', async (c) => {
  const { ids } = await c.req.json<{ids:string[]}>()
  if (!ids?.length) return c.json({ ok: true, profiles: {} })
  const unique = [...new Set(ids)].slice(0,200)
  const placeholders = unique.map((_,i)=>`$${i+1}`).join(',')
  const rows = await query(
    `SELECT u.id, u.handle, u.name, u."avatarUrl", u.role,
            COALESCE(p.follower_count,0) AS "followerCount",
            COALESCE(p.post_count,0)     AS "postCount",
            COALESCE(p.fan_count,0)      AS "fanCount"
     FROM public."User" u
     LEFT JOIN public.profiles p ON p.id::text=u.id
     WHERE u.id IN (${placeholders})`,
    unique
  )
  const profiles: Record<string,unknown> = {}
  rows.forEach(r => { profiles[(r as any).id] = r })
  return c.json({ ok: true, profiles })
})

// ── SEARCH ────────────────────────────────────────────────────────────────────

socialRouter.get('/search', async (c) => {
  const q     = (c.req.query('q')??'').trim()
  const limit = Math.min(Number(c.req.query('limit')??15),50)
  if (!q) return c.json({ ok: true, results: [] })
  const pat = `%${q}%`
  const [users, leagues, teams, players] = await Promise.all([
    query(`SELECT id, handle, first_name, last_name, role, avatar_url FROM public.profiles WHERE handle ILIKE $1 OR first_name ILIKE $1 OR last_name ILIKE $1 LIMIT $2`, [pat, limit]),
    query(`SELECT id, name, country, type, season FROM public."League" WHERE name ILIKE $1 OR country ILIKE $1 LIMIT $2`, [pat, Math.floor(limit/3)]),
    query(`SELECT id, name, country, city, "logoUrl" FROM public."Team" WHERE name ILIKE $1 AND "isActive"=true LIMIT $2`, [pat, Math.floor(limit/3)]),
    query(`SELECT id, name, position, nationality FROM public."Player" WHERE name ILIKE $1 AND "isActive"=true LIMIT $2`, [pat, Math.floor(limit/3)]),
  ])
  const results = [
    ...users.map((r:any) => {
      const kind = ['team','league','player','coach','organization'].includes(r.role) ? r.role : 'user'
      return { ...r, _kind: kind, _subtitle: kind==='user'?`@${r.handle}`:r.role }
    }),
    ...leagues.map((r:any) => ({ id:r.id, handle:String(r.name||'').toLowerCase().replace(/ /g,'_'), first_name:r.name, last_name:'', role:'league', avatar_url:null, _kind:'league', _subtitle:`${r.country||''} · ${r.type||''}` })),
    ...teams.map((r:any) => ({ id:r.id, handle:String(r.name||'').toLowerCase().replace(/ /g,'_'), first_name:r.name, last_name:'', role:'team', avatar_url:r.logoUrl, _kind:'team', _subtitle:`${r.city||''} · ${r.country||''}` })),
    ...players.map((r:any) => ({ id:r.id, handle:String(r.name||'').toLowerCase().replace(/ /g,'_'), first_name:r.name, last_name:'', role:'player', avatar_url:null, _kind:'player', _subtitle:`${r.position||''} · ${r.nationality||''}` })),
  ]
  return c.json({ ok: true, results })
})

// ── NEARBY / SOCIAL GRAPH HELPERS ─────────────────────────────────────────────

socialRouter.get('/fans-by-teams', async (c) => {
  const ids     = (c.req.query('ids')??'').split(',').filter(Boolean)
  const exclude = c.req.query('exclude')??''
  if (!ids.length) return c.json({ ok: true, fans: [] })
  const ph = ids.map((_,i)=>`$${i+1}`).join(',')
  const rows = await query(`SELECT uf."userId", uf."targetId", uf."targetName" FROM public."UserFavorite" uf WHERE uf."targetId" IN (${ph}) AND uf."userId"!=$${ids.length+1} LIMIT 100`, [...ids, exclude])
  return c.json({ ok: true, fans: rows })
})

socialRouter.get('/fans-by-sports', async (c) => {
  const ids     = (c.req.query('ids')??'').split(',').filter(Boolean)
  const exclude = c.req.query('exclude')??''
  if (!ids.length) return c.json({ ok: true, fans: [] })
  const ph = ids.map((_,i)=>`$${i+1}`).join(',')
  const rows = await query(`SELECT us."userId", us."sportId" FROM public."UserSport" us WHERE us."sportId" IN (${ph}) AND us."userId"!=$${ids.length+1} LIMIT 100`, [...ids, exclude])
  return c.json({ ok: true, fans: rows })
})

socialRouter.get('/fans-by-country', async (c) => {
  const country = c.req.query('country')??''
  const exclude = c.req.query('exclude')??''
  const limit   = Math.min(Number(c.req.query('limit')??50),200)
  const rows = await query(`SELECT id, handle, name, "avatarUrl", role, "currentCountry" FROM public."User" WHERE ("currentCountry" ILIKE $1 OR location ILIKE $1) AND id!=$2 LIMIT $3`, [`%${country}%`, exclude, limit])
  return c.json({ ok: true, fans: rows })
})

socialRouter.get('/my-favorites', async (c) => {
  const userId = c.get('userId') as string
  const type   = c.req.query('type')??'TEAM'
  const rows   = await query(`SELECT "targetId","targetName","targetType" FROM public."UserFavorite" WHERE "userId"=$1 AND "targetType"=$2`, [userId, type])
  return c.json({ ok: true, favorites: rows })
})

socialRouter.get('/fans/:userId/teams', async (c) => {
  const rows = await query(
    `SELECT t.name FROM public.entity_follows ef JOIN public."Team" t ON t.id=ef.entity_id WHERE ef.follower_id=$1::uuid AND ef.entity_type='team' AND ef.is_fan=true`,
    [c.req.param('userId')]
  )
  return c.json({ ok: true, teams: rows.map((r:any)=>r.name) })
})

socialRouter.get('/posts/by-tag', async (c) => {
  const playerTag = c.req.query('playerTag')??''
  const limit     = Math.min(Number(c.req.query('limit')??40),100)
  const rows = await query(
    `SELECT p.*, u.handle, u."avatarUrl", u.name FROM public."Post" p JOIN public."User" u ON u.id=p."userId" WHERE p."playerTag"=$1 ORDER BY p."createdAt" DESC LIMIT $2`,
    [playerTag, limit]
  )
  return c.json({ ok: true, posts: rows })
})
