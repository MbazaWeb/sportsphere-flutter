// vps/api/src/routes/mpesa.ts
// POST /v1/mpesa/stk     — initiate STK push (authenticated)
// POST /v1/mpesa/callback — Safaricom callback (public, verified by shortcode)

import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'

export const mpesaRouter = new Hono()

function mpesaBase() {
  return Bun.env.MPESA_ENV === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke'
}

async function getMpesaToken(): Promise<string> {
  const key    = Bun.env.MPESA_CONSUMER_KEY    ?? ''
  const secret = Bun.env.MPESA_CONSUMER_SECRET ?? ''
  const auth   = btoa(`${key}:${secret}`)
  const res = await fetch(`${mpesaBase()}/oauth/v1/generate?grant_type=client_credentials`, {
    headers: { Authorization: `Basic ${auth}` },
  })
  if (!res.ok) throw new Error(`M-Pesa token failed: ${await res.text()}`)
  return (await res.json() as any).access_token as string
}

function timestamp() {
  const d = new Date()
  const p = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`
}

function normalizePhone(phone: string): string {
  let p = phone.replace(/\D/g, '')
  if (p.startsWith('0')) p = '255' + p.slice(1)
  if (!p.startsWith('255')) p = '255' + p
  return p
}

// ── STK Push ─────────────────────────────────────────────────────────────────
mpesaRouter.post('/stk', async (c) => {
  const userId = c.get('userId') as string
  const { orderId, phone } = await c.req.json<{ orderId: string; phone: string }>()
  if (!orderId || !phone) return c.json({ error: 'orderId and phone required' }, 400)

  // H10: always read amount from DB — never trust client
  const { data: order, error: orderErr } = await supabaseAdmin
    .from('ShopOrder').select('id,"userId","amountTzs",status').eq('id', orderId).maybeSingle()
  if (orderErr || !order) return c.json({ error: 'Order not found' }, 400)
  if ((order as any).userId !== userId) return c.json({ error: 'Forbidden' }, 403)

  const amount = Math.max(1, Math.round(Number((order as any).amountTzs ?? 0)))
  const shortcode = Bun.env.MPESA_SHORTCODE ?? '174379'
  const passkey   = Bun.env.MPESA_PASSKEY   ?? ''
  const callback  = Bun.env.MPESA_CALLBACK_URL ?? `https://playifysport.fun/v1/mpesa/callback`

  if (!Bun.env.MPESA_CONSUMER_KEY) return c.json({ error: 'M-Pesa not configured' }, 503)

  const ts       = timestamp()
  const password = btoa(`${shortcode}${passkey}${ts}`)
  const token    = await getMpesaToken()
  const normalPhone = normalizePhone(phone)

  const stkRes = await fetch(`${mpesaBase()}/mpesa/stkpush/v1/processrequest`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      BusinessShortCode: shortcode,
      Password: password,
      Timestamp: ts,
      TransactionType: 'CustomerPayBillOnline',
      Amount: amount,
      PartyA: normalPhone,
      PartyB: shortcode,
      PhoneNumber: normalPhone,
      CallBackURL: callback,
      AccountReference: orderId.slice(0, 12),
      TransactionDesc: 'Playify',
    }),
  })
  const stkJson = await stkRes.json() as any

  // Persist CheckoutRequestID so callback can match it
  await supabaseAdmin.from('ShopOrder').update({
    status:        stkJson.ResponseCode === '0' ? 'stk_sent' : 'stk_failed',
    paymentMethod: 'mpesa',
    paymentRef:    stkJson.CheckoutRequestID ?? null,
  }).eq('id', orderId)

  return c.json(stkJson, stkRes.ok ? 200 : 400)
})

// ── Safaricom Callback ───────────────────────────────────────────────────────
export const mpesaCallbackHandler = async (c: any) => {
  return mpesaRouter.fetch(new Request(c.req.url.replace('/v1/mpesa/callback', '/callback'), { method: 'POST', headers: c.req.raw.headers, body: c.req.raw.body }))
}

mpesaRouter.post('/callback', async (c) => {
  let body: any
  try { body = await c.req.json() }
  catch { return c.json({ error: 'Invalid JSON' }, 500) }

  console.log('[mpesa-callback] payload:', JSON.stringify(body))

  // Verify BusinessShortCode
  const expectedShortcode = (Bun.env.MPESA_SHORTCODE ?? '').trim()
  const result = body?.Body?.stkCallback
  const callbackShortcode = result?.BusinessShortCode
  if (expectedShortcode && callbackShortcode !== undefined) {
    if (String(callbackShortcode) !== String(expectedShortcode)) {
      console.error(`[mpesa-callback] shortcode mismatch: ${callbackShortcode}`)
      return c.json({ error: 'Unauthorized' }, 401)
    }
  }

  const checkoutId = result?.CheckoutRequestID as string | undefined
  const code       = result?.ResultCode
  if (checkoutId) {
    await supabaseAdmin.from('ShopOrder').update({
      status:     code === 0 ? 'paid' : 'failed',
      paymentRef: checkoutId,
    }).eq('paymentRef', checkoutId)
    console.log(`[mpesa-callback] order updated checkoutId=${checkoutId} code=${code}`)
  }

  // Always 200 — Safaricom retries on any non-200
  return c.json({ ResultCode: 0, ResultDesc: 'Accepted' })
})
