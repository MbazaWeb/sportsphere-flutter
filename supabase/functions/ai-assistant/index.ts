import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const { mode, prompt, provider } = await req.json()
    if (!prompt || typeof prompt !== 'string') {
      return new Response(JSON.stringify({ error: 'prompt required' }), { status: 400, headers: cors })
    }
    const system = {
      news: 'You are SportSphere news desk. Write concise Tanzania sports news in English.',
      article: 'You are a sports journalist. Write a structured article with headline and short paragraphs.',
      moderate: 'You moderate a sports social app. Flag toxicity, spam, or false claims. Reply with verdict and reason.',
      chat: 'You are SportSphere assistant. Help fans, players and admins with the app.',
      caption: 'Write a short social post caption with 2-4 hashtags for SportSphere.',
    }[mode as string] || 'You are SportSphere assistant.'

    const useAnthropic = provider === 'anthropic'
    if (useAnthropic) {
      const key = Deno.env.get('ANTHROPIC_API_KEY')
      if (!key) throw new Error('ANTHROPIC_API_KEY not set')
      const res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-3-5-haiku-20241022',
          max_tokens: 1024,
          system,
          messages: [{ role: 'user', content: prompt }],
        }),
      })
      const data = await res.json()
      const text = data?.content?.[0]?.text ?? JSON.stringify(data)
      return new Response(JSON.stringify({ text, provider: 'anthropic' }), {
        headers: { ...cors, 'content-type': 'application/json' },
      })
    }

    const key = Deno.env.get('DEEPSEEK_API_KEY')
    if (!key) throw new Error('DEEPSEEK_API_KEY not set')
    const res = await fetch('https://api.deepseek.com/chat/completions', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: 'deepseek-chat',
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: prompt },
        ],
      }),
    })
    const data = await res.json()
    const text = data?.choices?.[0]?.message?.content ?? JSON.stringify(data)
    return new Response(JSON.stringify({ text, provider: 'deepseek' }), {
      headers: { ...cors, 'content-type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, 'content-type': 'application/json' },
    })
  }
})
