// vps/api/src/routes/ai-director.ts
// AI Director — autonomous agent that manages content, fixtures, polls, predictions
// and responds to comments on behalf of @playify admin account

import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'

export const aiDirectorRouter = new Hono()

const ANTHROPIC_KEY = () => Bun.env.ANTHROPIC_API_KEY ?? ''
const MODEL = 'claude-haiku-4-5-20251001'

// ── Core AI call ──────────────────────────────────────────────────────────────
async function askClaude(prompt: string, system?: string): Promise<string> {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_KEY(),
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 1024,
      system: system ?? `You are the Playify AI Director for Tanzania football.
You manage the Playify sports social platform (@playify admin).
You know Tanzania Premier League (TPL), teams like Simba SC, Young Africans (Yanga), Azam FC,
Coastal Union, JKT Tanzania, Namungo, Kagera Sugar etc.
Keep responses concise, engaging and football-focused. Use emojis sparingly.
Always respond in English unless asked otherwise.`,
      messages: [{ role: 'user', content: prompt }],
    }),
  })
  const data = await res.json() as any
  if (!res.ok) throw new Error(data?.error?.message ?? 'AI error')
  return data.content?.[0]?.text ?? ''
}

// Get admin userId
async function getAdminId(): Promise<string | null> {
  const row = await queryOne<{id: string}>(`SELECT id FROM public."User" WHERE handle='playify' LIMIT 1`)
  return row?.id ?? null
}

// ── POST /v1/ai-director/generate-post ────────────────────────────────────────
// Generate and optionally publish a football post
aiDirectorRouter.post('/generate-post', async (c) => {
  const { topic, publish = false } = await c.req.json<{ topic?: string; publish?: boolean }>()

  const t = topic ?? 'Tanzania Premier League latest news or matchday preview'
  const content = await askClaude(
    `Write a short, engaging social media post about: ${t}
     Max 280 characters. Football focused. Include relevant hashtags.
     Just the post text, nothing else.`
  )

  if (!publish) return c.json({ ok: true, content, published: false })

  const adminId = await getAdminId()
  if (!adminId) return c.json({ error: 'Admin user not found' }, 404)

  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"likeCount","commentCount","shareCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,0,0,0,NOW(),NOW()) RETURNING id`,
    [adminId, content]
  )
  return c.json({ ok: true, content, published: true, postId: (rows[0] as any).id })
})

// ── POST /v1/ai-director/generate-poll ────────────────────────────────────────
aiDirectorRouter.post('/generate-poll', async (c) => {
  const { topic, publish = false } = await c.req.json<{ topic?: string; publish?: boolean }>()

  const t = topic ?? 'upcoming Tanzania Premier League match'
  const raw = await askClaude(
    `Create a football poll about: ${t}
     Return ONLY valid JSON in this exact format:
     {"question":"...", "options":["option1","option2","option3","option4"]}
     Max 4 options. Keep question under 100 chars. Keep options under 30 chars each.`
  )

  let poll: any
  try {
    poll = JSON.parse(raw.replace(/```json|```/g, '').trim())
  } catch {
    return c.json({ error: 'Failed to parse poll', raw }, 500)
  }

  if (!publish) return c.json({ ok: true, poll, published: false })

  const adminId = await getAdminId()
  if (!adminId) return c.json({ error: 'Admin user not found' }, 404)

  // Create post first
  const postRows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"likeCount","commentCount","shareCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,0,0,0,NOW(),NOW()) RETURNING id`,
    [adminId, `📊 ${poll.question}`]
  )
  const postId = (postRows[0] as any).id

  const pollRows = await query(
    `INSERT INTO public."Poll"(id,"postId",question,options,"totalVotes","endsAt","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,NOW()+'7 days'::interval,NOW()) RETURNING id`,
    [postId, poll.question, JSON.stringify(poll.options)]
  )

  return c.json({ ok: true, poll, published: true, postId, pollId: (pollRows[0] as any).id })
})

// ── POST /v1/ai-director/generate-prediction ──────────────────────────────────
aiDirectorRouter.post('/generate-prediction', async (c) => {
  const { matchId, publish = false } = await c.req.json<{ matchId?: string; publish?: boolean }>()

  // Get match details
  let match: any = null
  if (matchId) {
    match = await queryOne(`SELECT * FROM public."Match" WHERE id=$1`, [matchId])
  } else {
    match = await queryOne(`SELECT * FROM public."Match" 
      WHERE "kickoffAt" > NOW() ORDER BY "kickoffAt" ASC LIMIT 1`)
  }

  if (!match) return c.json({ error: 'No upcoming match found' }, 404)

  const content = await askClaude(
    `Predict the result of: ${match.homeTeam} vs ${match.awayTeam}
     League: ${match.league ?? 'Tanzania Premier League'}
     Date: ${match.kickoffAt}
     Give a brief prediction with score, key factors, and confidence level.
     Keep it under 200 chars for a social post.`
  )

  if (!publish) return c.json({ ok: true, content, match, published: false })

  const adminId = await getAdminId()
  if (!adminId) return c.json({ error: 'Admin user not found' }, 404)

  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"likeCount","commentCount","shareCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,0,0,0,NOW(),NOW()) RETURNING id`,
    [adminId, `🔮 Match Prediction: ${content}`]
  )

  return c.json({ ok: true, content, match, published: true, postId: (rows[0] as any).id })
})

// ── POST /v1/ai-director/respond-comment ──────────────────────────────────────
// Respond to a comment as @playify bot
aiDirectorRouter.post('/respond-comment', async (c) => {
  const { commentId, postContent, commentText, publish = false } =
    await c.req.json<{ commentId: string; postContent?: string; commentText: string; publish?: boolean }>()

  const reply = await askClaude(
    `A user commented on a Tanzania football social post.
     Post context: "${postContent ?? 'football discussion'}"
     User comment: "${commentText}"
     Write a brief, friendly reply as the Playify platform admin.
     Max 150 characters. Be engaging and football-focused.`
  )

  if (!publish) return c.json({ ok: true, reply, published: false })

  const adminId = await getAdminId()
  if (!adminId) return c.json({ error: 'Admin user not found' }, 404)

  // Get postId from comment
  const comment = await queryOne<{postId: string}>(
    `SELECT "postId" FROM public."Comment" WHERE id=$1`, [commentId]
  )
  if (!comment) return c.json({ error: 'Comment not found' }, 404)

  await execute(
    `INSERT INTO public."Comment"(id,"postId","userId",content,"likeCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,0,NOW(),NOW())`,
    [comment.postId, adminId, reply]
  )

  return c.json({ ok: true, reply, published: true })
})

// ── POST /v1/ai-director/update-fixture ───────────────────────────────────────
// AI suggests fixture update from text description
aiDirectorRouter.post('/update-fixture', async (c) => {
  const { description } = await c.req.json<{ description: string }>()

  const raw = await askClaude(
    `Extract match fixture data from this description: "${description}"
     Return ONLY valid JSON:
     {
       "homeTeam": "...",
       "awayTeam": "...",
       "kickoffAt": "ISO datetime or null",
       "league": "Tanzania Premier League",
       "venue": "...",
       "homeScore": null_or_number,
       "awayScore": null_or_number,
       "status": "scheduled|live|ft"
     }`,
    'You are a football data extraction assistant. Return only valid JSON, no explanation.'
  )

  try {
    const fixture = JSON.parse(raw.replace(/```json|```/g, '').trim())
    return c.json({ ok: true, fixture })
  } catch {
    return c.json({ error: 'Could not parse fixture', raw }, 500)
  }
})

// ── POST /v1/ai-director/team-profile ─────────────────────────────────────────
// Generate team profile content
aiDirectorRouter.post('/team-profile', async (c) => {
  const { teamName } = await c.req.json<{ teamName: string }>()

  const raw = await askClaude(
    `Generate a football team profile for "${teamName}" (Tanzania).
     Return ONLY valid JSON:
     {
       "bio": "2-3 sentence bio",
       "founded": year_or_null,
       "stadium": "stadium name or null",
       "nickname": "team nickname or null",
       "achievements": "key achievements in one line"
     }`,
    'You are a Tanzania football expert. Return only valid JSON.'
  )

  try {
    const profile = JSON.parse(raw.replace(/```json|```/g, '').trim())
    return c.json({ ok: true, teamName, profile })
  } catch {
    return c.json({ error: 'Could not parse profile', raw }, 500)
  }
})

// ── POST /v1/ai-director/player-profile ───────────────────────────────────────
aiDirectorRouter.post('/player-profile', async (c) => {
  const { playerName, teamName } = await c.req.json<{ playerName: string; teamName?: string }>()

  const raw = await askClaude(
    `Generate a player profile for "${playerName}"${teamName ? ` who plays for ${teamName}` : ''} in Tanzania football.
     Return ONLY valid JSON:
     {
       "bio": "2-3 sentence bio",
       "position": "GK|CB|LB|RB|CM|CAM|LW|RW|ST",
       "nationality": "country",
       "strengths": "key strengths in one line"
     }`,
    'You are a Tanzania football expert. Return only valid JSON.'
  )

  try {
    const profile = JSON.parse(raw.replace(/```json|```/g, '').trim())
    return c.json({ ok: true, playerName, profile })
  } catch {
    return c.json({ error: 'Could not parse profile', raw }, 500)
  }
})

// ── POST /v1/ai-director/auto-run ─────────────────────────────────────────────
// Run a full auto-content cycle: generate post + poll
aiDirectorRouter.post('/auto-run', async (c) => {
  const adminId = await getAdminId()
  if (!adminId) return c.json({ error: 'Admin user not found' }, 404)

  const results: any[] = []

  // 1. Generate a football post
  const postContent = await askClaude(
    `Write an engaging Tanzania football social media post for today.
     Pick one: matchday preview, team news, player spotlight, or league table update.
     Max 250 characters. Include hashtags. Just the post text.`
  )
  const postRows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"likeCount","commentCount","shareCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,0,0,0,NOW(),NOW()) RETURNING id`,
    [adminId, postContent]
  )
  results.push({ type: 'post', content: postContent, id: (postRows[0] as any).id })

  // 2. Generate a poll
  const pollRaw = await askClaude(
    `Create a Tanzania football poll. Return ONLY JSON:
     {"question":"...","options":["...","...","...","..."]}`)
  try {
    const poll = JSON.parse(pollRaw.replace(/```json|```/g, '').trim())
    const ppRows = await query(
      `INSERT INTO public."Post"(id,"userId",content,"likeCount","commentCount","shareCount","createdAt","updatedAt")
       VALUES(gen_random_uuid()::text,$1,$2,0,0,0,NOW(),NOW()) RETURNING id`,
      [adminId, `📊 ${poll.question}`]
    )
    const ppId = (ppRows[0] as any).id
    await query(
      `INSERT INTO public."Poll"(id,"postId",question,options,"totalVotes","endsAt","createdAt")
       VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,NOW()+'7 days'::interval,NOW()) RETURNING id`,
      [ppId, poll.question, JSON.stringify(poll.options)]
    )
    results.push({ type: 'poll', poll, postId: ppId })
  } catch (_) {}

  return c.json({ ok: true, results, ran_at: new Date().toISOString() })
})

// ── GET /v1/ai-director/status ─────────────────────────────────────────────────
aiDirectorRouter.get('/status', async (c) => {
  const adminId = await getAdminId()
  const postCount = await queryOne<{count: string}>(
    `SELECT COUNT(*) as count FROM public."Post" WHERE "userId"=$1`, [adminId ?? '']
  )
  return c.json({
    ok: true,
    aiModel: MODEL,
    anthropicConfigured: !!ANTHROPIC_KEY(),
    adminHandle: 'playify',
    adminId,
    postsGenerated: parseInt(postCount?.count ?? '0'),
  })
})
