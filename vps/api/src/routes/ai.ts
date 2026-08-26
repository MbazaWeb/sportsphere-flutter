// vps/api/src/routes/ai.ts
// POST /v1/ai  — AI assistant (Anthropic + DeepSeek)
// Rate limited: 20 calls / hour / user (in-memory, resets on restart)
import { Hono } from 'hono'
export const aiRouter = new Hono()

const RATE_WINDOW = 60 * 60 * 1000  // 1 hour
const RATE_MAX    = 20
const buckets     = new Map<string, { count: number; resetAt: number }>()

function rateLimit(userId: string): { ok: boolean; remaining: number } {
  const now = Date.now()
  const b   = buckets.get(userId)
  if (!b || b.resetAt < now) {
    buckets.set(userId, { count: 1, resetAt: now + RATE_WINDOW })
    return { ok: true, remaining: RATE_MAX - 1 }
  }
  if (b.count >= RATE_MAX) return { ok: false, remaining: 0 }
  b.count++
  return { ok: true, remaining: RATE_MAX - b.count }
}

const SYSTEM: Record<string, string> = {
  news:      'You are Playify news desk. Write concise Tanzania sports news.',
  article:   'You are a sports journalist. Write structured articles.',
  moderate:  'You moderate a sports social app. Flag toxicity, spam, false claims.',
  chat:      'You are Playify assistant. Help fans, players and admins.',
  caption:   'Write a short social post caption with 2-4 hashtags for Playify.',
}

aiRouter.post('/', async (c) => {
  const userId = c.get('userId') as string
  const rl = rateLimit(userId)
  if (!rl.ok) return c.json({ error: 'Rate limit exceeded (20/hr)' }, 429)

  const { mode, prompt, provider } = await c.req.json<{
    mode?: string; prompt: string; provider?: string
  }>()
  if (!prompt) return c.json({ error: 'prompt required' }, 400)

  const system = SYSTEM[mode ?? 'chat'] ?? SYSTEM.chat

  if (provider === 'anthropic') {
    const key = Bun.env.ANTHROPIC_API_KEY
    if (!key) return c.json({ error: 'ANTHROPIC_API_KEY not set' }, 503)
    const res  = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type':'application/json', 'x-api-key': key, 'anthropic-version':'2023-06-01' },
      body: JSON.stringify({ model:'claude-sonnet-4-6', max_tokens:1024, system,
        messages:[{ role:'user', content: prompt }] }),
    })
    const d    = await res.json() as any
    const text = d?.content?.[0]?.text ?? ''
    return c.json({ ok:true, text, provider:'anthropic', remaining: rl.remaining })
  }

  // Default: DeepSeek
  const key = Bun.env.DEEPSEEK_API_KEY
  if (!key) return c.json({ error: 'DEEPSEEK_API_KEY not set' }, 503)
  const res  = await fetch('https://api.deepseek.com/chat/completions', {
    method: 'POST',
    headers: { 'content-type':'application/json', authorization:`Bearer ${key}` },
    body: JSON.stringify({ model:'deepseek-chat',
      messages:[{ role:'system', content:system }, { role:'user', content:prompt }] }),
  })
  const d    = await res.json() as any
  const text = d?.choices?.[0]?.message?.content ?? ''
  return c.json({ ok:true, text, provider:'deepseek', remaining: rl.remaining })
})
