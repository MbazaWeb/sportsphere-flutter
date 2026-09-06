// vps/api/src/routes/ai.ts
// AI chat endpoint — uses DeepSeek by default, Anthropic as fallback/option
import { Hono } from 'hono'

export const aiRouter = new Hono()

aiRouter.post('/', async (c) => {
  const { prompt, model = 'anthropic' } = await c.req.json<{ prompt: string; model?: string }>()
  if (!prompt) return c.json({ error: 'prompt required' }, 400)

  if (model === 'anthropic') {
    const key = Bun.env.ANTHROPIC_API_KEY ?? ''
    if (!key) return c.json({ error: 'Anthropic not configured' }, 503)
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
      }),
    })
    const data = await res.json() as any
    return c.json({ ok: true, reply: data.content?.[0]?.text ?? '', model: 'anthropic' })
  }

  // Default: DeepSeek
  const key = Bun.env.DEEPSEEK_API_KEY ?? ''
  if (!key) return c.json({ error: 'DeepSeek not configured' }, 503)
  console.log('[AI] DeepSeek key length:', key.length)
  const res = await fetch('https://api.deepseek.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1024,
    }),
  })
  const data = await res.json() as any
  console.log('[AI] DeepSeek status:', res.status, JSON.stringify(data).slice(0,200))
  if (!res.ok) return c.json({ error: data?.error?.message ?? 'DeepSeek error', status: res.status }, 502)
  return c.json({ ok: true, reply: data.choices?.[0]?.message?.content ?? '', model: 'deepseek' })
})
