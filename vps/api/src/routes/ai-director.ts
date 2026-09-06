// vps/api/src/routes/ai-director.ts
// AI Director — Powered by Claude Haiku
// Features: match analysis, predictions, chatbot, tactical insights,
//           player reports, smart alerts, fantasy tips, auto-content

import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'

export const aiDirectorRouter = new Hono()

const KEY   = () => Bun.env.ANTHROPIC_API_KEY ?? ''
const MODEL = 'claude-haiku-4-5-20251001'

const SYSTEM = `You are the Playify AI Sports Director for Tanzania football.
You are an expert analyst covering the Tanzania Premier League (TPL),
NBC Premier League, and all Tanzania football competitions.
Key teams: Simba SC, Young Africans (Yanga), Azam FC, Coastal Union,
JKT Tanzania, Namungo FC, Kagera Sugar, Pamba FC, Polisi Tanzania,
Mashujaa FC, Mbeya City, Dodoma Jiji, Singida Black Stars, TRA United.
Be concise, data-driven, engaging. Use emojis sparingly. Always in English.`

async function claude(prompt: string, system = SYSTEM, maxTokens = 1024): Promise<string> {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': KEY(),
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: maxTokens,
      system,
      messages: [{ role: 'user', content: prompt }],
    }),
  })
  const d = await res.json() as any
  if (!res.ok) throw new Error(d?.error?.message ?? 'AI error')
  return d.content?.[0]?.text ?? ''
}

async function adminId(): Promise<string | null> {
  const r = await queryOne<{id: string}>(`SELECT id FROM public."User" WHERE handle='playify' LIMIT 1`)
  return r?.id ?? null
}

async function publishPost(userId: string, content: string): Promise<string> {
  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"likeCount","commentCount","shareCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,0,0,0,NOW(),NOW()) RETURNING id`,
    [userId, content]
  )
  return (rows[0] as any).id
}

// ── STATUS ─────────────────────────────────────────────────────────────────────
aiDirectorRouter.get('/status', async (c) => {
  const uid = await adminId()
  const posts = await queryOne<{n: string}>(
    `SELECT COUNT(*) n FROM public."Post" WHERE "userId"=$1`, [uid ?? ''])
  return c.json({
    ok: true, model: MODEL,
    configured: !!KEY(),
    adminHandle: 'playify', adminId: uid,
    postsPublished: parseInt(posts?.n ?? '0'),
    capabilities: [
      'match-analysis','prediction','tactical-report','player-report',
      'chatbot','smart-alert','fantasy-tip','auto-post','auto-poll',
      'respond-comment','team-profile','player-profile',
      'fixture-extract','auto-run'
    ]
  })
})

// ── 1. MATCH ANALYSIS ─────────────────────────────────────────────────────────
aiDirectorRouter.post('/match-analysis', async (c) => {
  const { homeTeam, awayTeam, homeScore, awayScore, events, publish = false } =
    await c.req.json<any>()
  const eventStr = events ? `Key events: ${JSON.stringify(events)}` : ''
  const reply = await claude(
    `Analyze this Tanzania football match result:
     ${homeTeam} ${homeScore ?? '?'} - ${awayScore ?? '?'} ${awayTeam}
     ${eventStr}
     Provide: key moments, man of the match candidate, tactical observations,
     impact on league standings, and 2-3 sentences for a social post.
     Format as JSON: {"analysis":"...","manOfMatch":"...","tacticalNote":"...","socialPost":"..."}`,
    SYSTEM, 800
  )
  const data = JSON.parse(reply.replace(/```json|```/g,'').trim())
  if (publish && data.socialPost) {
    const uid = await adminId()
    if (uid) { const pid = await publishPost(uid, `⚽ ${data.socialPost}`); (data as any).postId = pid }
  }
  return c.json({ ok: true, ...data })
})

// ── 2. MATCH PREDICTION ────────────────────────────────────────────────────────
aiDirectorRouter.post('/prediction', async (c) => {
  const { homeTeam, awayTeam, venue, league = 'Tanzania Premier League',
          homeForm, awayForm, injuries, weather, publish = false } = await c.req.json<any>()
  const context = [
    homeForm && `${homeTeam} recent form: ${homeForm}`,
    awayForm && `${awayTeam} recent form: ${awayForm}`,
    injuries && `Injuries/suspensions: ${injuries}`,
    weather  && `Weather: ${weather}`,
    venue    && `Venue: ${venue}`,
  ].filter(Boolean).join('\n')

  const reply = await claude(
    `Predict this ${league} match:
     ${homeTeam} vs ${awayTeam}
     ${context}
     Return JSON: {
       "prediction": "Home Win|Draw|Away Win",
       "confidence": "High|Medium|Low",
       "predictedScore": "X-Y",
       "keyFactors": ["factor1","factor2","factor3"],
       "rationale": "2-3 sentences",
       "socialPost": "engaging post under 200 chars with prediction"
     }`,
    SYSTEM, 600
  )
  const data = JSON.parse(reply.replace(/```json|```/g,'').trim())
  if (publish && data.socialPost) {
    const uid = await adminId()
    if (uid) { const pid = await publishPost(uid, `🔮 ${data.socialPost}`); (data as any).postId = pid }
  }
  return c.json({ ok: true, homeTeam, awayTeam, ...data })
})

// ── 3. TACTICAL REPORT ────────────────────────────────────────────────────────
aiDirectorRouter.post('/tactical-report', async (c) => {
  const { teamName, opponent, matchData } = await c.req.json<any>()
  const reply = await claude(
    `Generate a tactical analysis for ${teamName}${opponent ? ` vs ${opponent}` : ''}.
     ${matchData ? `Match data: ${JSON.stringify(matchData)}` : ''}
     Return JSON: {
       "formation": "e.g. 4-3-3",
       "strengths": ["...","..."],
       "weaknesses": ["...","..."],
       "keyPlayers": ["name - role","..."],
       "recommendedStrategy": "2-3 sentences",
       "pressurePoints": "where to attack/defend"
     }`,
    SYSTEM, 700
  )
  return c.json({ ok: true, teamName, ...JSON.parse(reply.replace(/```json|```/g,'').trim()) })
})

// ── 4. PLAYER PERFORMANCE REPORT ──────────────────────────────────────────────
aiDirectorRouter.post('/player-report', async (c) => {
  const { playerName, position, team, stats, recentMatches } = await c.req.json<any>()
  const reply = await claude(
    `Generate a performance report for ${playerName} (${position ?? 'player'}) at ${team ?? 'Tanzania'}.
     ${stats ? `Stats: ${JSON.stringify(stats)}` : ''}
     ${recentMatches ? `Recent matches: ${JSON.stringify(recentMatches)}` : ''}
     Return JSON: {
       "overallRating": 1-10,
       "technicalScore": 1-10,
       "tacticalScore": 1-10,
       "physicalScore": 1-10,
       "strengths": ["..."],
       "areasForImprovement": ["..."],
       "summary": "2-3 sentence professional assessment",
       "recommendation": "transfer value/development advice"
     }`,
    SYSTEM, 600
  )
  return c.json({ ok: true, playerName, ...JSON.parse(reply.replace(/```json|```/g,'').trim()) })
})

// ── 5. CHATBOT / MATCH CHAT ───────────────────────────────────────────────────
aiDirectorRouter.post('/chat', async (c) => {
  const { message, context, history = [] } = await c.req.json<any>()
  const messages = [
    ...history.map((h: any) => ({ role: h.role, content: h.content })),
    { role: 'user', content: message }
  ]
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': KEY(),
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 512,
      system: SYSTEM + (context ? `\nContext: ${context}` : ''),
      messages,
    }),
  })
  const d = await res.json() as any
  const reply = d.content?.[0]?.text ?? ''
  return c.json({ ok: true, reply, model: MODEL })
})

// ── 6. SMART ALERT FILTER ─────────────────────────────────────────────────────
aiDirectorRouter.post('/smart-alert', async (c) => {
  const { events } = await c.req.json<{ events: any[] }>()
  const reply = await claude(
    `Filter these match events for high-significance moments only.
     Events: ${JSON.stringify(events)}
     Return JSON array of only the most significant events (goals, red cards, last-minute drama):
     [{"event":"...","significance":"HIGH","alertText":"push notification text under 80 chars"}]`,
    SYSTEM, 400
  )
  const alerts = JSON.parse(reply.replace(/```json|```/g,'').trim())
  return c.json({ ok: true, alerts })
})

// ── 7. FANTASY TIP ────────────────────────────────────────────────────────────
aiDirectorRouter.post('/fantasy-tip', async (c) => {
  const { gameweek, budget, currentSquad, availablePlayers } = await c.req.json<any>()
  const reply = await claude(
    `Give fantasy football tips for Tanzania Premier League.
     Gameweek: ${gameweek ?? 'next'}
     Budget remaining: ${budget ?? 'any'}
     ${currentSquad ? `Current squad: ${JSON.stringify(currentSquad)}` : ''}
     ${availablePlayers ? `Available: ${JSON.stringify(availablePlayers)}` : ''}
     Return JSON: {
       "captainPick": {"player":"...","team":"...","reason":"..."},
       "transfers": [{"out":"...","in":"...","reason":"..."}],
       "watchlist": ["player1","player2"],
       "tip": "key tactical tip for this gameweek"
     }`,
    SYSTEM, 500
  )
  return c.json({ ok: true, ...JSON.parse(reply.replace(/```json|```/g,'').trim()) })
})

// ── 8. AUTO-POST ──────────────────────────────────────────────────────────────
aiDirectorRouter.post('/generate-post', async (c) => {
  const { topic, publish = false } = await c.req.json<any>()
  const content = await claude(
    `Write an engaging Tanzania football social media post about: ${topic ?? 'TPL latest news or matchday'}.
     Max 250 chars. Include hashtags. Just the post text, nothing else.`,
    SYSTEM, 300
  )
  if (!publish) return c.json({ ok: true, content, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const pid = await publishPost(uid, content)
  return c.json({ ok: true, content, published: true, postId: pid })
})

// ── 9. AUTO-POLL ──────────────────────────────────────────────────────────────
aiDirectorRouter.post('/generate-poll', async (c) => {
  const { topic, publish = false } = await c.req.json<any>()
  const raw = await claude(
    `Create a Tanzania football poll about: ${topic ?? 'TPL this week'}.
     Return ONLY JSON: {"question":"...","options":["...","...","...","..."]}`,
    SYSTEM, 200
  )
  const poll = JSON.parse(raw.replace(/```json|```/g,'').trim())
  if (!publish) return c.json({ ok: true, poll, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const pid = await publishPost(uid, `📊 ${poll.question}`)
  await query(
    `INSERT INTO public."Poll"(id,"postId",question,options,"totalVotes","endsAt","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,NOW()+'7 days'::interval,NOW())`,
    [pid, poll.question, JSON.stringify(poll.options)]
  )
  return c.json({ ok: true, poll, published: true, postId: pid })
})

// ── 10. RESPOND TO COMMENT ────────────────────────────────────────────────────
aiDirectorRouter.post('/respond-comment', async (c) => {
  const { commentId, commentText, postContent, publish = false } = await c.req.json<any>()
  const reply = await claude(
    `A user commented on a Playify Tanzania football post.
     Post: "${postContent ?? 'football discussion'}"
     Comment: "${commentText}"
     Write a friendly reply as @playify admin. Max 150 chars. Be engaging.`,
    SYSTEM, 200
  )
  if (!publish) return c.json({ ok: true, reply, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const comment = await queryOne<{postId: string}>(
    `SELECT "postId" FROM public."Comment" WHERE id=$1`, [commentId])
  if (!comment) return c.json({ error: 'Comment not found' }, 404)
  await execute(
    `INSERT INTO public."Comment"(id,"postId","userId",content,"likeCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,0,NOW(),NOW())`,
    [comment.postId, uid, reply]
  )
  return c.json({ ok: true, reply, published: true })
})

// ── 11. FIXTURE EXTRACT ───────────────────────────────────────────────────────
aiDirectorRouter.post('/fixture-extract', async (c) => {
  const { text } = await c.req.json<{ text: string }>()
  const raw = await claude(
    `Extract all football fixtures from this text: "${text}"
     Return JSON array:
     [{"homeTeam":"...","awayTeam":"...","date":"YYYY-MM-DD or null",
       "time":"HH:MM or null","venue":"...","league":"Tanzania Premier League",
       "homeScore":null,"awayScore":null,"status":"scheduled"}]`,
    'Extract football fixture data. Return only valid JSON array.', 600
  )
  const fixtures = JSON.parse(raw.replace(/```json|```/g,'').trim())
  return c.json({ ok: true, fixtures, count: fixtures.length })
})

// ── 12. TEAM PROFILE ──────────────────────────────────────────────────────────
aiDirectorRouter.post('/team-profile', async (c) => {
  const { teamName } = await c.req.json<{ teamName: string }>()
  const raw = await claude(
    `Generate a complete profile for Tanzania football club "${teamName}".
     Return JSON: {
       "bio":"2-3 sentence bio","founded":year,"stadium":"name",
       "nickname":"...","colors":"...","achievements":"key honours",
       "currentManager":"...","leaguePosition":"...",
       "socialPost":"exciting 1-line description for social media"
     }`,
    SYSTEM, 500
  )
  return c.json({ ok: true, teamName, ...JSON.parse(raw.replace(/```json|```/g,'').trim()) })
})

// ── 13. PLAYER PROFILE ────────────────────────────────────────────────────────
aiDirectorRouter.post('/player-profile', async (c) => {
  const { playerName, teamName } = await c.req.json<any>()
  const raw = await claude(
    `Generate a profile for "${playerName}"${teamName ? ` at ${teamName}` : ''} in Tanzania football.
     Return JSON: {
       "bio":"2-3 sentences","position":"GK|CB|LB|RB|CM|CAM|LW|RW|ST",
       "nationality":"...","age":null,"strengths":"key attributes",
       "marketValue":"estimate in USD","socialPost":"engaging 1-line bio"
     }`,
    SYSTEM, 400
  )
  return c.json({ ok: true, playerName, ...JSON.parse(raw.replace(/```json|```/g,'').trim()) })
})

// ── 14. AUTO-RUN (full cycle) ─────────────────────────────────────────────────
aiDirectorRouter.post('/auto-run', async (c) => {
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const results: any[] = []

  // Generate post
  const postText = await claude(
    `Write one engaging Tanzania football post for today (matchday/news/stats). Max 250 chars. Just the text.`,
    SYSTEM, 300
  )
  const pid = await publishPost(uid, postText)
  results.push({ type: 'post', content: postText, postId: pid })

  // Generate poll
  const pollRaw = await claude(
    `Create a TPL fan poll. Return ONLY JSON: {"question":"...","options":["...","...","...","..."]}`,
    SYSTEM, 200
  )
  try {
    const poll = JSON.parse(pollRaw.replace(/```json|```/g,'').trim())
    const ppid = await publishPost(uid, `📊 ${poll.question}`)
    await query(
      `INSERT INTO public."Poll"(id,"postId",question,options,"totalVotes","endsAt","createdAt")
       VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,NOW()+'7 days'::interval,NOW())`,
      [ppid, poll.question, JSON.stringify(poll.options)]
    )
    results.push({ type: 'poll', poll, postId: ppid })
  } catch (_) {}

  return c.json({ ok: true, results, ran_at: new Date().toISOString() })
})
