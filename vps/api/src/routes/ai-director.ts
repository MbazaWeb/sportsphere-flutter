// vps/api/src/routes/ai-director.ts
// AI Director — orchestrates the full content cycle for Playify.
//
// Capabilities (all under /v1/admin/ai-director, require admin JWT):
//   POST /auto-run                 Full content cycle (fetch → analyze → post → poll)
//   POST /generate-post            Football content post + image prompt
//   POST /generate-poll            Fan poll with options
//   POST /generate-prediction      Match outcome prediction
//   POST /respond-comment          Auto-reply to a fan comment as @playify
//   POST /update-fixture           Extract fixture data from text → upsert Match
//   POST /team-profile             Generate team bio
//   POST /player-profile           Generate player profile
//   POST /generate-news            Breaking news / previews / reviews / features
//   POST /generate-rumor           Transfer rumors (labeled speculation)
//   POST /match-analysis           Post-match ratings + tactical breakdown
//   POST /manage-scores            Live score + result + standings update
//   POST /manage-unclaimed         Post content for unclaimed team accounts
//   POST /research                 Deep research on any TZ football topic
//   POST /chat                     Interactive AI football assistant

import { Hono } from 'hono'
import { query, queryOne, execute, transaction } from '../lib/db.js'

export const aiDirectorRouter = new Hono()

// ─── AI core ──────────────────────────────────────────────────────────────
const DEEPSEEK_KEY = Bun.env.DEEPSEEK_API_KEY ?? ''
const ANTHROPIC_KEY = Bun.env.ANTHROPIC_API_KEY ?? ''

async function askAI(system: string, user: string, provider: 'deepseek' | 'anthropic' = 'deepseek'): Promise<string> {
  if (provider === 'anthropic' && ANTHROPIC_KEY) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type':'application/json', 'x-api-key': ANTHROPIC_KEY, 'anthropic-version':'2023-06-01' },
      body: JSON.stringify({ model:'claude-sonnet-4-6', max_tokens:1024, system,
        messages:[{ role:'user', content: user }] }),
    })
    if (!res.ok) throw new Error(`Anthropic ${res.status}`)
    const d = await res.json() as any
    return d?.content?.[0]?.text ?? ''
  }

  // Default: DeepSeek
  if (!DEEPSEEK_KEY) throw new Error('DEEPSEEK_API_KEY not set')
  const res = await fetch('https://api.deepseek.com/chat/completions', {
    method: 'POST',
    headers: { 'content-type':'application/json', authorization:`Bearer ${DEEPSEEK_KEY}` },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [
        { role: 'system', content: system },
        { role: 'user',   content: user },
      ],
    }),
  })
  if (!res.ok) throw new Error(`DeepSeek ${res.status}`)
  const d = await res.json() as any
  return d?.choices?.[0]?.message?.content ?? ''
}

// Parse the first JSON object from an AI response (LLMs sometimes wrap in ```json)
function parseJSON<T = any>(text: string): T {
  // Strip markdown code fences
  let t = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim()
  // Find first { or [ ... last } or ]
  const start = t.search(/[{\[]/)
  const end = Math.max(t.lastIndexOf('}'), t.lastIndexOf(']'))
  if (start >= 0 && end > start) t = t.slice(start, end + 1)
  return JSON.parse(t) as T
}

// ─── Get/Set the "playify" system user (used to author AI-generated content) ──
async function getPlayifySystemUserId(): Promise<string> {
  let row = await queryOne<{id: string}>(`SELECT id FROM public."User" WHERE handle='playify_bot'`)
  if (row) return row.id
  // Create the bot user if it doesn't exist
  const id = crypto.randomUUID()
  await execute(
    `INSERT INTO public."User"(id, name, email, handle, role, "passwordHash", "emailVerified", "registeredAt", "updatedAt")
     VALUES($1,'Playify AI','bot@playify.app','playify_bot','admin','__no_login__',true,NOW(),NOW())`,
    [id]
  ).catch(() => {})
  await execute(
    `INSERT INTO public.profiles(id, handle, role, first_name, last_name, email, country, created_at, updated_at)
     VALUES($1::uuid,'playify_bot','admin','Playify','AI','bot@playify.app','Global',NOW(),NOW())
     ON CONFLICT DO NOTHING`,
    [id]
  ).catch(() => {})
  return id
}

// ─── Create a Post (as the playify_bot user) ──────────────────────────────
async function createPost(content: string, postType = 'post', mediaUrls: string[] = [], extra: any = {}) {
  const userId = await getPlayifySystemUserId()
  const rows = await query(
    `INSERT INTO public."Post"(id,"userId",content,"postType","mediaUrls","hashtags",
       "teamTag","playerTag","sportTag","isBreaking","likeCount","commentCount","shareCount","viewCount","createdAt","updatedAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4::jsonb,$5::jsonb,$6,$7,$8,$9,0,0,0,0,NOW(),NOW())
     RETURNING *`,
    [userId, content, postType, JSON.stringify(mediaUrls ?? []),
     JSON.stringify(extra.hashtags ?? []),
     extra.teamTag ?? null, extra.playerTag ?? null, extra.sportTag ?? 'football',
     extra.isBreaking ?? false]
  )
  await execute(`UPDATE public.profiles SET post_count=COALESCE(post_count,0)+1 WHERE id::text=$1`, [userId]).catch(() => {})
  return rows[0]
}

// ─── Create a Poll ────────────────────────────────────────────────────────
async function createPoll(postId: string, question: string, options: string[], endsAt?: string) {
  const rows = await query(
    `INSERT INTO public."Poll"(id,"postId","matchId",question,options,"totalVotes","endsAt","createdAt")
     VALUES(gen_random_uuid()::text,$1,$2,$3,$4::jsonb,0,$5,NOW()) RETURNING *`,
    [postId, null, question, JSON.stringify(options), endsAt ?? null]
  )
  return rows[0]
}

// ─── Create a NewsItem ────────────────────────────────────────────────────
async function createNews(item: any) {
  const id = `ai-news-${Date.now()}-${Math.random().toString(36).slice(2,8)}`
  const slug = (item.title ?? 'untitled').toLowerCase().replace(/[^a-z0-9]+/g,'-').slice(0,80)
  await execute(
    `INSERT INTO public."NewsItem"(id,title,slug,body,summary,category,source,
       "imageUrl",status,"is_breaking","likeCount","commentCount","shareCount","viewCount","publishedAt","createdAt","updatedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,'published',$9,0,0,0,0,NOW(),NOW(),NOW())
     ON CONFLICT DO NOTHING`,
    [id, item.title, slug, item.body ?? item.content, item.summary ?? '',
     item.category ?? 'updates', item.source ?? 'Playify AI',
     item.imageUrl ?? null, item.isBreaking ?? false]
  ).catch(() => {})
  return id
}

// ════════════════════════════════════════════════════════════════════════════
// CAPABILITIES
// ════════════════════════════════════════════════════════════════════════════

// ─── POST /auto-run ───────────────────────────────────────────────────────
// Full content cycle in one call: generate news → post → poll → prediction
aiDirectorRouter.post('/auto-run', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>().catch(() => ({}))
  const topic = b.topic ?? 'Tanzania Ligi Kuu Bara — weekly recap'

  const system = `You are the Playify AI Director for the Playify sports social app.
You produce THREE pieces of content in one cycle:
1. A short news article (3-4 paragraphs)
2. A fan post (60-120 words, engaging tone, with 2-4 hashtags)
3. A fan poll question with 3-4 options

Always respond in valid JSON with this exact shape:
{
  "news":     { "title": "...", "body": "...", "summary": "...", "isBreaking": false, "category": "updates" },
  "post":     { "content": "...", "hashtags": ["#ligikuu"], "postType": "post" },
  "poll":     { "question": "...", "options": ["...","...","..."] }
}
Tanzania football (Ligi Kuu Bara, Simba SC, Young Africans) gets TOP priority.
Use English with Swahili fan vocabulary where natural (timu, mechi, magoli).`

  try {
    const text = await askAI(system, `Topic: ${topic}`)
    const parsed = parseJSON(text)
    // Persist everything
    let newsId: string | null = null
    if (parsed.news) newsId = await createNews({ ...parsed.news, source: 'Playify AI Director' })
    let post: any = null
    if (parsed.post) post = await createPost(parsed.post.content, parsed.post.postType ?? 'post', [], { hashtags: parsed.post.hashtags })
    let poll: any = null
    if (parsed.poll && post) poll = await createPoll(post.id, parsed.poll.question, parsed.poll.options)
    return c.json({ ok: true, newsId, post, poll, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /generate-post ──────────────────────────────────────────────────
aiDirectorRouter.post('/generate-post', async (c) => {
  const b = await c.req.json<any>()
  const topic = b.topic ?? 'Simba SC match preview'
  const system = `You are the Playify content writer for a sports social app.
Write an engaging fan post (60-120 words) in English with Swahili fan vocabulary where natural.
Always respond in JSON: { "content": "...", "hashtags": ["#ligikuu"], "postType": "post" }`
  try {
    const text = await askAI(system, topic)
    const parsed = parseJSON(text)
    const auto = b.autoPublish !== false  // default: publish
    let post = null
    if (auto) post = await createPost(parsed.content, parsed.postType ?? 'post', [], { hashtags: parsed.hashtags })
    return c.json({ ok: true, parsed, post, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /generate-poll ──────────────────────────────────────────────────
aiDirectorRouter.post('/generate-poll', async (c) => {
  const b = await c.req.json<any>()
  const topic = b.topic ?? 'Who wins the Ligi Kuu Bara this season?'
  const system = `You are the Playify poll generator. Generate ONE fan engagement poll.
Always respond in JSON: { "question": "...", "options": ["...","...","...","..."] }
Provide 3-4 concise options. Tanzania topics get priority.`
  try {
    const text = await askAI(system, topic)
    const parsed = parseJSON(text)
    let poll = null, post = null
    if (b.autoPublish) {
      post = await createPost(`📊 ${parsed.question}`, 'poll')
      poll = await createPoll(post.id, parsed.question, parsed.options)
    }
    return c.json({ ok: true, parsed, post, poll, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /generate-prediction ────────────────────────────────────────────
aiDirectorRouter.post('/generate-prediction', async (c) => {
  const b = await c.req.json<any>()
  const homeTeam = b.homeTeam ?? 'Simba SC'
  const awayTeam = b.awayTeam ?? 'Young Africans'
  const system = `You are the Playify football analyst. Predict the match outcome.
Always respond in JSON:
{ "predictedHome": 2, "predictedAway": 1, "outcome": "home_win",
  "confidence": 75, "reasoning": "short 2-sentence justification" }
Use realistic scoring (0-4 goals per side). Confidence is 0-100.`
  try {
    const text = await askAI(system, `Match: ${homeTeam} vs ${awayTeam}`)
    const parsed = parseJSON(text)
    let post = null, prediction = null
    if (b.autoPublish) {
      post = await createPost(
        `🔮 Prediction: ${homeTeam} ${parsed.predictedHome}-${parsed.predictedAway} ${awayTeam}\n${parsed.reasoning}`,
        'prediction'
      )
      const rows = await query(
        `INSERT INTO public."Prediction"(id,"userId","homeTeam","awayTeam","predictedHome","predictedAway","outcome","confidence","postId","createdAt")
         VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,$7,$8,NOW()) RETURNING *`,
        [await getPlayifySystemUserId(), homeTeam, awayTeam,
         parsed.predictedHome, parsed.predictedAway, parsed.outcome, parsed.confidence, post.id]
      )
      prediction = rows[0]
    }
    return c.json({ ok: true, parsed, post, prediction, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /respond-comment ────────────────────────────────────────────────
aiDirectorRouter.post('/respond-comment', async (c) => {
  const b = await c.req.json<any>()
  const commentId = b.commentId
  const comment   = b.comment
  if (!comment) return c.json({ error: 'comment required' }, 400)
  const system = `You are @playify, the friendly Playify bot. Reply to a fan comment in 1-2 sentences.
Be supportive, upbeat, use Swahili fan vocabulary where natural (asante, timu, magoli).
Always respond with plain text (not JSON).`
  try {
    const text = await askAI(system, comment)
    let savedReply = null
    if (b.autoPublish !== false && commentId) {
      const botId = await getPlayifySystemUserId()
      const rows = await query(
        `INSERT INTO public."Comment"(id,"postId","userId",content,"createdAt")
         VALUES(gen_random_uuid()::text,
           (SELECT "postId" FROM public."Comment" WHERE id=$1),
           $2, $3, NOW()) RETURNING *`,
        [commentId, botId, text.trim()]
      )
      savedReply = rows[0]
    }
    return c.json({ ok: true, reply: text, savedReply, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /update-fixture ─────────────────────────────────────────────────
// Extract fixture data from free text → upsert Match
aiDirectorRouter.post('/update-fixture', async (c) => {
  const b = await c.req.json<any>()
  const text_input = b.text
  if (!text_input) return c.json({ error: 'text required' }, 400)
  const system = `You extract structured fixture data from football text.
Always respond in JSON:
{ "homeTeam": "...", "awayTeam": "...", "kickoffAt": "ISO date",
  "league": "...", "season": "2026/27", "homeScore": null, "awayScore": null,
  "status": "scheduled", "country": "Tanzania" }
Use null for unknown scores. Status: scheduled | live | finished | postponed | cancelled.`
  try {
    const text = await askAI(system, text_input)
    const parsed = parseJSON(text)
    const id = `ai-fixture-${Date.now()}`
    const existing = await queryOne<{id:string}>(
      `SELECT id FROM public."Match" WHERE "homeTeam"=$1 AND "awayTeam"=$2 AND league=$3`,
      [parsed.homeTeam, parsed.awayTeam, parsed.league]
    )
    let matchId: string
    if (existing) {
      await execute(
        `UPDATE public."Match" SET "homeScore"=$1, "awayScore"=$2, status=$3, "kickoffAt"=$4, "updatedAt"=NOW() WHERE id=$5`,
        [parsed.homeScore, parsed.awayScore, parsed.status, parsed.kickoffAt, existing.id]
      )
      matchId = existing.id
    } else {
      await execute(
        `INSERT INTO public."Match"(id, league, "homeTeam", "awayTeam", "homeScore", "awayScore",
           status, "kickoffAt", season, country, "sportSlug", "createdAt", "updatedAt")
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,NOW(),NOW())`,
        [id, parsed.league, parsed.homeTeam, parsed.awayTeam, parsed.homeScore, parsed.awayScore,
         parsed.status, parsed.kickoffAt, parsed.season, parsed.country, 'football']
      )
      matchId = id
    }
    return c.json({ ok: true, parsed, matchId, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /team-profile ──────────────────────────────────────────────────
aiDirectorRouter.post('/team-profile', async (c) => {
  const b = await c.req.json<any>()
  const teamName = b.teamName ?? 'Simba SC'
  const system = `You are the Playify team bio writer. Write a 200-word team profile with:
history, achievements, current status, key players, fan culture.
Always respond in JSON:
{ "name": "...", "bio": "...", "foundedYear": "1936", "country": "Tanzania",
  "city": "Dar es Salaam", "stadium": "...", "league": "Ligi Kuu Bara" }`
  try {
    const text = await askAI(system, `Team: ${teamName}`)
    const parsed = parseJSON(text)
    if (b.autoPublish) {
      // Upsert team profile
      await execute(
        `INSERT INTO public."TeamProfile"("id","teamId","bio","foundedYear","city","stadium","league","createdAt","updatedAt")
         VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,NOW(),NOW())
         ON CONFLICT DO NOTHING`,
        [`team-${teamName.toLowerCase().replace(/[^a-z0-9]+/g,'-').slice(0,40)}`,
         parsed.bio, parsed.foundedYear, parsed.city, parsed.stadium, parsed.league]
      ).catch(() => {})
    }
    return c.json({ ok: true, parsed, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /player-profile ────────────────────────────────────────────────
aiDirectorRouter.post('/player-profile', async (c) => {
  const b = await c.req.json<any>()
  const playerName = b.playerName ?? 'Twisenge Bakari'
  const system = `You are the Playify player profile writer. Write a 150-word bio.
Always respond in JSON:
{ "name": "...", "bio": "...", "position": "Striker", "nationality": "Tanzanian",
  "currentClub": "Simba SC", "careerStatus": "Active" }`
  try {
    const text = await askAI(system, `Player: ${playerName}`)
    const parsed = parseJSON(text)
    if (b.autoPublish) {
      await execute(
        `INSERT INTO public."PlayerProfile"("id","playerId","bio","position","nationality","currentClub","careerStatus","createdAt","updatedAt")
         VALUES(gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,NOW(),NOW())
         ON CONFLICT DO NOTHING`,
        [`player-${playerName.toLowerCase().replace(/[^a-z0-9]+/g,'-').slice(0,40)}`,
         parsed.bio, parsed.position, parsed.nationality, parsed.currentClub, parsed.careerStatus]
      ).catch(() => {})
    }
    return c.json({ ok: true, parsed, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /generate-news ──────────────────────────────────────────────────
aiDirectorRouter.post('/generate-news', async (c) => {
  const b = await c.req.json<any>()
  const topic = b.topic ?? 'Ligi Kuu Bara matchday recap'
  const isBreaking = b.isBreaking ?? false
  const system = `You are the Playify news desk. Write a Tanzania sports news article (3-4 paragraphs, 200-400 words).
Always respond in JSON: { "title": "...", "body": "...", "summary": "...", "category": "updates" }
Tanzania football gets TOP priority. Use English with Swahili fan vocabulary where natural.`
  try {
    const text = await askAI(system, topic)
    const parsed = parseJSON(text)
    let newsId: string | null = null
    if (b.autoPublish !== false) {
      newsId = await createNews({ ...parsed, source: 'Playify AI Director', isBreaking })
    }
    return c.json({ ok: true, parsed, newsId, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /generate-rumor ─────────────────────────────────────────────────
aiDirectorRouter.post('/generate-rumor', async (c) => {
  const b = await c.req.json<any>()
  const topic = b.topic ?? 'Transfer rumors in Ligi Kuu Bara'
  const system = `You are the Playify transfer-rumor mill. Generate a clearly-labeled speculative transfer rumor (1 paragraph, 60-100 words).
Start with the prefix "RUMOR: " so it's never confused with verified news.
Always respond in JSON: { "title": "RUMOR: ...", "body": "...", "summary": "...", "category": "rumors" }`
  try {
    const text = await askAI(system, topic)
    const parsed = parseJSON(text)
    let newsId: string | null = null
    if (b.autoPublish !== false) {
      newsId = await createNews({ ...parsed, source: 'Playify Rumor Mill (AI)', isBreaking: false })
    }
    return c.json({ ok: true, parsed, newsId, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /match-analysis ─────────────────────────────────────────────────
aiDirectorRouter.post('/match-analysis', async (c) => {
  const b = await c.req.json<any>()
  const matchId = b.matchId
  if (!matchId) return c.json({ error: 'matchId required' }, 400)
  // Pull match row from DB
  const match = await queryOne<any>(`SELECT * FROM public."Match" WHERE id=$1`, [matchId])
  if (!match) return c.json({ error: 'Match not found' }, 404)
  const system = `You are the Playify tactical analyst. Generate a post-match analysis with:
1. Player ratings (top 3 from each side)
2. Tactical breakdown (formation, key moments)
Always respond in JSON:
{ "ratings": [{"team":"...","players":[{"name":"...","rating":8.5}]}],
  "tactics": "2-paragraph tactical summary",
  "keyMoments": ["minute — what happened", "..."] }`
  try {
    const text = await askAI(system,
      `Match: ${match.homeTeam} ${match.homeScore ?? '?'} - ${match.awayScore ?? '?'} ${match.awayTeam} (league: ${match.league}, status: ${match.status})`)
    const parsed = parseJSON(text)
    let post: any = null
    if (b.autoPublish) {
      const summary = `📊 Match Analysis: ${match.homeTeam} vs ${match.awayTeam}\n\n${parsed.tactics}\n\nKey moments: ${(parsed.keyMoments ?? []).join(' | ')}`
      post = await createPost(summary, 'analysis', [], { matchId: matchId, sportTag: 'football' })
    }
    return c.json({ ok: true, parsed, post, raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /manage-scores ──────────────────────────────────────────────────
// Update a live score, finalize a result, or refresh league standings.
aiDirectorRouter.post('/manage-scores', async (c) => {
  const b = await c.req.json<any>()
  const action = b.action ?? 'update-live'
  const matchId = b.matchId
  if (!matchId && action !== 'refresh-standings') return c.json({ error: 'matchId required' }, 400)

  if (action === 'update-live' || action === 'finalize') {
    const match = await queryOne<any>(`SELECT * FROM public."Match" WHERE id=$1`, [matchId])
    if (!match) return c.json({ error: 'Match not found' }, 404)
    const newHome = b.homeScore ?? match.homeScore ?? 0
    const newAway = b.awayScore ?? match.awayScore ?? 0
    const newStatus = action === 'finalize' ? 'finished' : 'live'
    await execute(
      `UPDATE public."Match" SET "homeScore"=$1, "awayScore"=$2, status=$3, "updatedAt"=NOW() WHERE id=$4`,
      [newHome, newAway, newStatus, matchId]
    )
    // Auto-generate an analysis post on finalize
    let post: any = null
    if (action === 'finalize' && b.autoPublish) {
      const sys = `Write a 60-90 word final-score post for a sports social app. English with Swahili fan vocabulary.`
      const text = await askAI(sys, `Match finished: ${match.homeTeam} ${newHome}-${newAway} ${match.awayTeam} (${match.league})`)
      post = await createPost(text.trim(), 'result', [], { matchId, sportTag: 'football' })
    }
    return c.json({ ok: true, action, matchId, homeScore: newHome, awayScore: newAway, status: newStatus, post })
  }

  if (action === 'refresh-standings') {
    // Recompute standings from finished matches
    const league = b.league ?? 'Ligi Kuu Bara'
    const rows = await query(
      `SELECT * FROM public."Match" WHERE league=$1 AND status='finished'`,
      [league]
    )
    const table: Record<string, any> = {}
    for (const m of rows as any[]) {
      for (const [team, gs, gc] of [[m.homeTeam, m.homeScore ?? 0, m.awayScore ?? 0],
                                     [m.awayTeam, m.awayScore ?? 0, m.homeScore ?? 0]] as [string,number,number][]) {
        table[team] ??= { team, p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0 }
        table[team].p++; table[team].gf += gs; table[team].ga += gc
        if (gs > gc) table[team].w++
        else if (gs === gc) table[team].d++
        else table[team].l++
      }
    }
    const standings = Object.values(table)
      .map((s: any) => ({ ...s, pts: s.w*3+s.d, gd: s.gf-s.ga }))
      .sort((a: any, b: any) => b.pts - a.pts || b.gd - a.gd || b.gf - a.gf)
      .map((s: any, i: number) => ({ ...s, pos: i+1 }))
    return c.json({ ok: true, league, standings })
  }

  return c.json({ error: `Unknown action: ${action}` }, 400)
})

// ─── POST /manage-unclaimed ──────────────────────────────────────────────
// Posts content on behalf of team accounts that have no human owner yet.
aiDirectorRouter.post('/manage-unclaimed', async (c) => {
  const b = await c.req.json<any>()
  const teamHandle = b.teamHandle
  if (!teamHandle) return c.json({ error: 'teamHandle required' }, 400)
  // Find the team account user (if any)
  const teamUser = await queryOne<{id: string; name: string}>(
    `SELECT id, name FROM public."User" WHERE handle=$1 AND role='team'`,
    [teamHandle]
  )
  if (!teamUser) return c.json({ error: 'Team account not found' }, 404)

  const system = `You are the Playify AI posting on behalf of an unclaimed team account.
Write a 60-90 word post (announcements, motivation, matchday content).
Always respond with plain text (not JSON).`
  const topic = b.topic ?? `Matchday post for ${teamUser.name}`
  try {
    const text = await askAI(system, topic)
    const rows = await query(
      `INSERT INTO public."Post"(id,"userId",content,"postType","mediaUrls","hashtags","likeCount","commentCount","shareCount","viewCount","createdAt","updatedAt")
       VALUES(gen_random_uuid()::text,$1,$2,$3,$4::jsonb,$5::jsonb,0,0,0,0,NOW(),NOW()) RETURNING *`,
      [teamUser.id, text.trim(), 'post', '[]', JSON.stringify(b.hashtags ?? ['#ligikuu'])]
    )
    await execute(`UPDATE public.profiles SET post_count=COALESCE(post_count,0)+1 WHERE id::text=$1`, [teamUser.id]).catch(() => {})
    return c.json({ ok: true, post: rows[0], raw: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /research ──────────────────────────────────────────────────────
aiDirectorRouter.post('/research', async (c) => {
  const b = await c.req.json<any>()
  const topic = b.topic
  if (!topic) return c.json({ error: 'topic required' }, 400)
  const system = `You are the Playify research analyst. Produce a structured deep-dive on a Tanzania football topic.
Return a 300-600 word markdown brief with sections: Background, Current State, Key Players, Outlook.`
  try {
    const text = await askAI(system, topic, b.provider ?? 'deepseek')
    return c.json({ ok: true, brief: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})

// ─── POST /chat ──────────────────────────────────────────────────────────
aiDirectorRouter.post('/chat', async (c) => {
  const b = await c.req.json<any>()
  const message = b.message
  if (!message) return c.json({ error: 'message required' }, 400)
  const system = `You are the Playify AI football assistant. Be helpful, concise, and use Swahili fan vocabulary where natural.
Tanzania football (Ligi Kuu Bara, Simba SC, Young Africans, Azam FC) is your specialty.
Reply in plain text.`
  try {
    const text = await askAI(system, message, b.provider ?? 'deepseek')
    return c.json({ ok: true, reply: text })
  } catch (e: any) {
    return c.json({ ok: false, error: e.message }, 500)
  }
})
