// vps/api/src/routes/ai-director.ts
// AI Director — Autonomous manager of @playify account
// Manages content, unclaimed users, news, polls, predictions, comments

import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'
import { AI_DIRECTOR_SYSTEM, TANZANIA_FOOTBALL_KNOWLEDGE } from '../lib/ai-knowledge.js'

export const aiDirectorRouter = new Hono()

const KEY   = () => Bun.env.ANTHROPIC_API_KEY ?? ''
const MODEL = 'claude-haiku-4-5-20251001'

// ── Core AI call ──────────────────────────────────────────────────────────────
async function claude(prompt: string, system = AI_DIRECTOR_SYSTEM, maxTokens = 1024): Promise<string> {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': KEY(), 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODEL, max_tokens: maxTokens, system, messages: [{ role: 'user', content: prompt }] }),
  })
  const d = await res.json() as any
  if (!res.ok) throw new Error(d?.error?.message ?? 'AI error')
  return d.content?.[0]?.text ?? ''
}

async function claudeJSON<T>(prompt: string, system = AI_DIRECTOR_SYSTEM, maxTokens = 800): Promise<T> {
  const raw = await claude(prompt, system, maxTokens)
  return JSON.parse(raw.replace(/```json|```/g,'').trim()) as T
}

async function adminId(): Promise<string | null> {
  const r = await queryOne<{id:string}>(`SELECT id FROM public."User" WHERE handle='playify' LIMIT 1`)
  return r?.id ?? null
}

async function publishPost(userId: string, content: string, mediaUrls?: string[]): Promise<string> {
  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"mediaUrls","likeCount","commentCount","shareCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,0,0,NOW(),NOW()) RETURNING id`,
    [userId, content, JSON.stringify(mediaUrls ?? [])]
  )
  return (rows[0] as any).id
}

// ── STATUS ────────────────────────────────────────────────────────────────────
aiDirectorRouter.get('/status', async (c) => {
  const uid = await adminId()
  const posts = await queryOne<{n:string}>(`SELECT COUNT(*) n FROM public."Post" WHERE "userId"=$1`, [uid??''])
  const news  = await queryOne<{n:string}>(`SELECT COUNT(*) n FROM public."News" WHERE "authorId"=$1`, [uid??''])
  const unclaimed = await queryOne<{n:string}>(
    `SELECT COUNT(*) n FROM public."User" u
     JOIN public."Team" t ON t."accountUserId"=u.id
     WHERE t."identity_status"!='claimed' OR t."identity_status" IS NULL`)
  return c.json({
    ok: true, model: MODEL, configured: !!KEY(),
    adminHandle: 'playify', adminId: uid,
    stats: { postsPublished: parseInt(posts?.n??'0'), newsPublished: parseInt(news?.n??'0') },
    unclaimedTeams: parseInt(unclaimed?.n??'0'),
    capabilities: [
      'status','chat','match-analysis','prediction','tactical-report',
      'player-report','smart-alert','fantasy-tip','generate-post',
      'generate-poll','generate-news','generate-rumor','respond-comment',
      'fixture-extract','team-profile','player-profile',
      'manage-unclaimed','auto-run','research'
    ]
  })
})

// ── CHAT (interactive AI assistant) ───────────────────────────────────────────
aiDirectorRouter.post('/chat', async (c) => {
  const { message, history = [], context } = await c.req.json<any>()
  const messages = [
    ...history.map((h:any) => ({ role: h.role, content: h.content })),
    { role: 'user', content: message }
  ]
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': KEY(), 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({
      model: MODEL, max_tokens: 512,
      system: AI_DIRECTOR_SYSTEM + (context ? `\nCurrent context: ${context}` : ''),
      messages,
    }),
  })
  const d = await res.json() as any
  return c.json({ ok: true, reply: d.content?.[0]?.text ?? '', model: MODEL })
})

// ── RESEARCH Tanzania Football ────────────────────────────────────────────────
aiDirectorRouter.post('/research', async (c) => {
  const { topic } = await c.req.json<{ topic: string }>()
  const reply = await claude(
    `Research and provide detailed, accurate information about: ${topic}
     Focus on Tanzania football context. Include:
     - Current status/facts
     - Historical context  
     - Key statistics if relevant
     - Recent developments (based on your knowledge)
     - Recommendations for the platform
     Be thorough but factual. Label any speculation clearly.`,
    AI_DIRECTOR_SYSTEM, 1024
  )
  return c.json({ ok: true, topic, research: reply })
})

// ── GENERATE NEWS ARTICLE ──────────────────────────────────────────────────────
aiDirectorRouter.post('/generate-news', async (c) => {
  const { topic, type = 'news', publish = false } = await c.req.json<any>()
  // type: 'news' | 'rumor' | 'breaking' | 'preview' | 'review' | 'feature'

  const typeInstructions: Record<string, string> = {
    news:     'Write a factual news article.',
    rumor:    'Write a transfer rumor article. CLEARLY label as "RUMOR" and use "reportedly","sources claim" etc.',
    breaking: 'Write a BREAKING NEWS article. Urgent tone, key facts first.',
    preview:  'Write a match preview article with tactical analysis and prediction.',
    review:   'Write a match review with analysis, player ratings, and key moments.',
    feature:  'Write a feature story about Tanzania football, engaging and detailed.',
  }

  const article = await claudeJSON<any>(`
    ${typeInstructions[type] ?? typeInstructions.news}
    Topic: ${topic}
    
    Return JSON:
    {
      "headline": "compelling headline under 80 chars",
      "summary": "2-sentence summary for preview",
      "body": "full article 300-500 words with paragraphs separated by \\n\\n",
      "tags": ["tag1","tag2","tag3"],
      "imagePrompt": "description for generating a relevant image",
      "socialPost": "engaging post under 200 chars to share this article"
    }`)

  if (!publish) return c.json({ ok: true, type, article, published: false })

  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)

  // Save as news
  const rows = await query(
    `INSERT INTO public."News"(id,title,summary,content,tags,"authorId","publishedAt","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4::jsonb,$5,NOW(),NOW(),NOW()) RETURNING id`,
    [article.headline, article.summary, article.body,
     JSON.stringify(article.tags ?? []), uid]
  ).catch(async () => {
    // News table may have different schema — fallback to Post
    const pid = await publishPost(uid, `📰 ${article.headline}\n\n${article.summary}`)
    return [{ id: pid }]
  })

  // Also create a social post
  const pid = await publishPost(uid, article.socialPost ?? `📰 ${article.headline}`)

  return c.json({ ok: true, type, article, published: true,
    newsId: (rows[0] as any).id, postId: pid })
})

// ── GENERATE RUMOR ────────────────────────────────────────────────────────────
aiDirectorRouter.post('/generate-rumor', async (c) => {
  const { context, publish = false } = await c.req.json<any>()
  const rumor = await claudeJSON<any>(`
    Generate a realistic Tanzania football transfer rumor.
    ${context ? `Context: ${context}` : 'Pick any interesting rumor involving TPL teams.'}
    IMPORTANT: This is entertainment/speculation content. Always label clearly.
    
    Return JSON:
    {
      "headline": "RUMOR: ... (include RUMOR label)",
      "player": "player name",
      "fromClub": "current club",
      "toClub": "rumored destination",
      "fee": "reported fee or null",
      "reliability": "Low|Medium",
      "source": "Social media reports|Club insiders|Agent sources",
      "body": "150-200 word article clearly labeled as rumor/speculation",
      "socialPost": "🔁 RUMOR: ... under 180 chars"
    }`)

  if (!publish) return c.json({ ok: true, rumor, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const pid = await publishPost(uid, rumor.socialPost ?? `🔁 ${rumor.headline}`)
  return c.json({ ok: true, rumor, published: true, postId: pid })
})

// ── MATCH ANALYSIS ────────────────────────────────────────────────────────────
aiDirectorRouter.post('/match-analysis', async (c) => {
  const { homeTeam, awayTeam, homeScore, awayScore, events, publish = false } = await c.req.json<any>()
  const data = await claudeJSON<any>(`
    Analyze Tanzania football match: ${homeTeam} ${homeScore??'?'}-${awayScore??'?'} ${awayTeam}
    ${events ? `Events: ${JSON.stringify(events)}` : ''}
    Return JSON: {
      "analysis":"detailed 3-4 sentence analysis",
      "manOfMatch":"player name and reason",
      "tacticalNote":"key tactical observation",
      "playerRatings":[{"name":"...","rating":6.5,"note":"..."}],
      "socialPost":"engaging post under 200 chars"
    }`)
  if (publish && data.socialPost) {
    const uid = await adminId()
    if (uid) { data.postId = await publishPost(uid, `⚽ ${data.socialPost}`) }
  }
  return c.json({ ok: true, homeTeam, awayTeam, homeScore, awayScore, ...data })
})

// ── MATCH PREDICTION ──────────────────────────────────────────────────────────
aiDirectorRouter.post('/prediction', async (c) => {
  const { homeTeam, awayTeam, venue, league='Tanzania Premier League',
          homeForm, awayForm, injuries, publish = false } = await c.req.json<any>()
  const data = await claudeJSON<any>(`
    Predict ${league}: ${homeTeam} vs ${awayTeam}
    ${venue?`Venue: ${venue}`:''}
    ${homeForm?`${homeTeam} form: ${homeForm}`:''}
    ${awayForm?`${awayTeam} form: ${awayForm}`:''}
    ${injuries?`Injuries: ${injuries}`:''}
    Return JSON: {
      "prediction":"Home Win|Draw|Away Win",
      "confidence":"High|Medium|Low",
      "predictedScore":"X-Y",
      "keyFactors":["...","...","..."],
      "rationale":"2-3 sentences",
      "socialPost":"🔮 prediction post under 180 chars"
    }`)
  if (publish && data.socialPost) {
    const uid = await adminId()
    if (uid) { data.postId = await publishPost(uid, data.socialPost) }
  }
  return c.json({ ok: true, homeTeam, awayTeam, ...data })
})

// ── TACTICAL REPORT ───────────────────────────────────────────────────────────
aiDirectorRouter.post('/tactical-report', async (c) => {
  const { teamName, opponent } = await c.req.json<any>()
  const data = await claudeJSON<any>(`
    Tactical analysis for ${teamName}${opponent?` vs ${opponent}`:''}:
    Return JSON: {
      "formation":"e.g. 4-3-3",
      "strengths":["...","..."],
      "weaknesses":["...","..."],
      "keyPlayers":["name - role","..."],
      "recommendedStrategy":"2-3 sentences",
      "pressurePoints":"where to exploit"
    }`)
  return c.json({ ok: true, teamName, ...data })
})

// ── PLAYER PERFORMANCE REPORT ─────────────────────────────────────────────────
aiDirectorRouter.post('/player-report', async (c) => {
  const { playerName, position, team, stats } = await c.req.json<any>()
  const data = await claudeJSON<any>(`
    Performance report for ${playerName} (${position??'player'}) at ${team??'Tanzania'}:
    ${stats?`Stats: ${JSON.stringify(stats)}`:''}
    Return JSON: {
      "overallRating":7.5,
      "technical":7,"tactical":7,"physical":7,
      "strengths":["..."],
      "improvements":["..."],
      "summary":"2-3 sentence assessment",
      "marketValue":"$X-Y million estimate"
    }`)
  return c.json({ ok: true, playerName, ...data })
})

// ── SMART ALERT FILTER ────────────────────────────────────────────────────────
aiDirectorRouter.post('/smart-alert', async (c) => {
  const { events } = await c.req.json<{ events: any[] }>()
  const alerts = await claudeJSON<any[]>(`
    Filter for HIGH significance events only from: ${JSON.stringify(events)}
    Return JSON array: [{"event":"...","significance":"HIGH","alertText":"push notification under 80 chars"}]`)
  return c.json({ ok: true, alerts })
})

// ── FANTASY TIP ───────────────────────────────────────────────────────────────
aiDirectorRouter.post('/fantasy-tip', async (c) => {
  const { gameweek, budget, currentSquad } = await c.req.json<any>()
  const data = await claudeJSON<any>(`
    Fantasy TPL tips for gameweek ${gameweek??'next'}, budget: ${budget??'any'}.
    ${currentSquad?`Squad: ${JSON.stringify(currentSquad)}`:''}
    Return JSON: {
      "captainPick":{"player":"...","team":"...","reason":"..."},
      "transfers":[{"out":"...","in":"...","reason":"..."}],
      "watchlist":["player1","player2"],
      "tip":"key insight for this gameweek"
    }`)
  return c.json({ ok: true, ...data })
})

// ── GENERATE POST ─────────────────────────────────────────────────────────────
aiDirectorRouter.post('/generate-post', async (c) => {
  const { topic, publish = false } = await c.req.json<any>()
  const content = await claude(
    `Write an engaging Tanzania football social media post: ${topic??'TPL latest news or matchday'}.
     Max 250 chars. Include hashtags. Just the post text.`, AI_DIRECTOR_SYSTEM, 300)
  if (!publish) return c.json({ ok: true, content, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  return c.json({ ok: true, content, published: true, postId: await publishPost(uid, content) })
})

// ── GENERATE POLL ─────────────────────────────────────────────────────────────
aiDirectorRouter.post('/generate-poll', async (c) => {
  const { topic, publish = false } = await c.req.json<any>()
  const poll = await claudeJSON<any>(`
    Tanzania football poll: ${topic??'TPL this week'}.
    Return JSON: {"question":"...","options":["...","...","...","..."]}`)
  if (!publish) return c.json({ ok: true, poll, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const pid = await publishPost(uid, `📊 ${poll.question}`)
  await query(
    `INSERT INTO public."Poll"(id,"postId",question,options,"totalVotes","endsAt","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,NOW()+'7 days'::interval,NOW())`,
    [pid, poll.question, JSON.stringify(poll.options)])
  return c.json({ ok: true, poll, published: true, postId: pid })
})

// ── RESPOND TO COMMENT ────────────────────────────────────────────────────────
aiDirectorRouter.post('/respond-comment', async (c) => {
  const { commentId, commentText, postContent, publish = false } = await c.req.json<any>()
  const reply = await claude(
    `Fan comment on Tanzania football post.
     Post: "${postContent??'football'}" | Comment: "${commentText}"
     Reply as @playify admin. Max 150 chars. Friendly and engaging.`, AI_DIRECTOR_SYSTEM, 200)
  if (!publish) return c.json({ ok: true, reply, published: false })
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const comment = await queryOne<{postId:string}>(`SELECT "postId" FROM public."Comment" WHERE id=$1`, [commentId])
  if (!comment) return c.json({ error: 'Comment not found' }, 404)
  await execute(
    `INSERT INTO public."Comment"(id,"postId","userId",content,"likeCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,0,NOW(),NOW())`,
    [comment.postId, uid, reply])
  return c.json({ ok: true, reply, published: true })
})

// ── MANAGE UNCLAIMED USERS ────────────────────────────────────────────────────
// AI creates content for unclaimed team/player accounts
aiDirectorRouter.post('/manage-unclaimed', async (c) => {
  const { limit = 5 } = await c.req.json<any>()

  // Get unclaimed team accounts
  const teams = await query<{id:string, name:string, handle:string, accountUserId:string}>(
    `SELECT t.id, t.name, u.handle, u.id as "accountUserId"
     FROM public."Team" t
     JOIN public."User" u ON u.id::text = t."accountUserId"
     WHERE (t."identity_status" IS NULL OR t."identity_status" != 'claimed')
     AND t."isActive" = true
     LIMIT $1`, [limit])

  const results = []

  for (const team of teams) {
    try {
      // Generate a post for this team's account
      const content = await claude(
        `Write a short social media post as if you are ${team.name} football club in Tanzania.
         Team handle: @${team.handle}
         Write about: training update, fan engagement, or upcoming match excitement.
         Max 200 chars. First person ("We are ready!", "Our fans are amazing!").
         Just the post text.`, AI_DIRECTOR_SYSTEM, 200)

      await publishPost(team.accountUserId, content)
      results.push({ team: team.name, handle: team.handle, posted: true, content })
    } catch (e: any) {
      results.push({ team: team.name, handle: team.handle, posted: false, error: e.message })
    }
  }

  return c.json({ ok: true, managed: results.length, results })
})

// ── FIXTURE EXTRACT ───────────────────────────────────────────────────────────
aiDirectorRouter.post('/fixture-extract', async (c) => {
  const { text } = await c.req.json<{ text: string }>()
  const fixtures = await claudeJSON<any[]>(`
    Extract all football fixtures from: "${text}"
    Return JSON array: [{
      "homeTeam":"...","awayTeam":"...","date":"YYYY-MM-DD",
      "time":"HH:MM","venue":"...","league":"Tanzania Premier League",
      "homeScore":null,"awayScore":null,"status":"scheduled"
    }]`,
    'Extract football fixture data. Return only valid JSON array.', 600)
  return c.json({ ok: true, fixtures, count: fixtures.length })
})

// ── TEAM PROFILE ──────────────────────────────────────────────────────────────
aiDirectorRouter.post('/team-profile', async (c) => {
  const { teamName } = await c.req.json<{ teamName: string }>()
  const profile = await claudeJSON<any>(`
    Complete profile for Tanzania football club "${teamName}":
    Return JSON: {
      "bio":"2-3 sentence bio","founded":year,"stadium":"name",
      "nickname":"...","colors":"...","achievements":"key honours",
      "currentManager":"...","socialPost":"exciting 1-line description"
    }`)
  return c.json({ ok: true, teamName, ...profile })
})

// ── PLAYER PROFILE ────────────────────────────────────────────────────────────
aiDirectorRouter.post('/player-profile', async (c) => {
  const { playerName, teamName } = await c.req.json<any>()
  const profile = await claudeJSON<any>(`
    Profile for "${playerName}"${teamName?` at ${teamName}`:''} Tanzania football:
    Return JSON: {
      "bio":"2-3 sentences","position":"GK|CB|LB|RB|CM|CAM|LW|RW|ST",
      "nationality":"...","strengths":"key attributes",
      "marketValue":"USD estimate","socialPost":"engaging 1-line bio"
    }`)
  return c.json({ ok: true, playerName, ...profile })
})

// ── AUTO-RUN (full autonomous cycle) ─────────────────────────────────────────
aiDirectorRouter.post('/auto-run', async (c) => {
  const uid = await adminId()
  if (!uid) return c.json({ error: 'Admin not found' }, 404)
  const results: any[] = []

  // 1. Generate football post
  const postText = await claude(
    `Write one engaging Tanzania football post for today. Pick from:
     matchday preview, TPL table update, player spotlight, team news, or fan engagement.
     Max 250 chars with hashtags.`, AI_DIRECTOR_SYSTEM, 300)
  results.push({ type: 'post', content: postText, postId: await publishPost(uid, postText) })

  // 2. Generate poll
  try {
    const poll = await claudeJSON<any>(`
      Create an exciting TPL fan poll.
      Return ONLY JSON: {"question":"...","options":["...","...","...","..."]}`)
    const ppid = await publishPost(uid, `📊 ${poll.question}`)
    await query(
      `INSERT INTO public."Poll"(id,"postId",question,options,"totalVotes","endsAt","createdAt")
       VALUES(gen_random_uuid()::text,$1,$2,$3::jsonb,0,NOW()+'7 days'::interval,NOW())`,
      [ppid, poll.question, JSON.stringify(poll.options)])
    results.push({ type: 'poll', poll, postId: ppid })
  } catch (_) {}

  // 3. Generate a news headline post
  try {
    const news = await claudeJSON<any>(`
      Write a Tanzania football news headline post for today.
      Return JSON: {"headline":"...","socialPost":"📰 news post under 200 chars"}`)
    const npid = await publishPost(uid, news.socialPost)
    results.push({ type: 'news', headline: news.headline, postId: npid })
  } catch (_) {}

  return c.json({ ok: true, results, ran_at: new Date().toISOString() })
})
