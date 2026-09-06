import { createHmac, timingSafeEqual } from 'crypto'
// vps/api/src/routes/mpesa.ts
import { Hono } from 'hono'
import { queryOne, execute } from '../lib/db.js'

export const mpesaRouter = new Hono()

function mpesaBase() {
  return Bun.env.MPESA_ENV === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke'
}
async function getMpesaToken(): Promise<string> {
  const auth = btoa(`${Bun.env.MPESA_CONSUMER_KEY}:${Bun.env.MPESA_CONSUMER_SECRET}`)
  const res  = await fetch(`${mpesaBase()}/oauth/v1/generate?grant_type=client_credentials`,{headers:{Authorization:`Basic ${auth}`}})
  if (!res.ok) throw new Error(`M-Pesa token: ${await res.text()}`)
  return ((await res.json()) as any).access_token as string
}
function timestamp() {
  const d=new Date(); const p=(n:number)=>n.toString().padStart(2,'0')
  return `${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`
}
function normalizePhone(phone: string): string {
  let p = phone.replace(/\D/g,'')
  if (p.startsWith('0')) p = '255'+p.slice(1)
  if (!p.startsWith('255')) p = '255'+p
  return p
}

export const mpesaCallbackHandler = async (c: any) => {
  let body: any
  try { body = await c.req.json() } catch { return c.json({error:'Invalid JSON'},500) }
  const secret = Bun.env.MPESA_CALLBACK_SECRET
  if (!secret) return c.json({ error: 'Payments are not configured' }, 503)
  const orderId = c.req.query('orderId') ?? ''
  const provided = Buffer.from(c.req.query('token') ?? '')
  const expected = Buffer.from(createHmac('sha256', secret).update(orderId).digest('hex'))
  if (!orderId || provided.length !== expected.length || !timingSafeEqual(provided, expected)) return c.json({ error: 'Unauthorized' }, 401)
  const result = body?.Body?.stkCallback
  if (!result?.CheckoutRequestID || !Number.isInteger(result.ResultCode)) return c.json({ error: 'Invalid callback' }, 400)
  const order = await queryOne<any>('SELECT * FROM public."ShopOrder" WHERE id=$1 AND "paymentRef"=$2', [orderId, result.CheckoutRequestID])
  if (!order) return c.json({ error: 'Unknown payment' }, 400)
  if (result.ResultCode === 0) {
    const amount = result.CallbackMetadata?.Item?.find((item: any) => item.Name === 'Amount')?.Value
    if (Number(amount) !== Number(order.amountTzs)) return c.json({ error: 'Payment amount mismatch' }, 400)
  }
  await execute(`UPDATE public."ShopOrder" SET status=$1,"updatedAt"=NOW() WHERE id=$2 AND "paymentRef"=$3 AND status='stk_sent'`, [result.ResultCode === 0 ? 'paid' : 'failed', orderId, result.CheckoutRequestID])
  return c.json({ ResultCode: 0, ResultDesc: 'Accepted' })
}

mpesaRouter.post('/stk', async (c) => {
  const userId = c.get('userId') as string
  const { orderId, phone } = await c.req.json<{orderId:string;phone:string}>()
  if (!orderId || !phone) return c.json({ error: 'orderId and phone required' }, 400)

  // H10: amount ALWAYS from DB
  const order = await queryOne<{userId:string;amountTzs:number;status:string}>(
    `SELECT "userId", "amountTzs", status FROM public."ShopOrder" WHERE id = $1`, [orderId]
  )
  if (!order) return c.json({ error: 'Order not found' }, 400)
  if (order.userId !== userId) return c.json({ error: 'Forbidden' }, 403)

  const amount    = Math.max(1, Math.round(Number(order.amountTzs ?? 0)))
  const shortcode = Bun.env.MPESA_SHORTCODE ?? '174379'
  const passkey   = Bun.env.MPESA_PASSKEY   ?? ''
  const callback  = Bun.env.MPESA_CALLBACK_URL ?? `https://playifysport.fun/v1/mpesa/callback`

  if (!Bun.env.MPESA_CONSUMER_KEY || !Bun.env.MPESA_CONSUMER_SECRET || !passkey || !Bun.env.MPESA_CALLBACK_SECRET) return c.json({ error: 'M-Pesa is not configured' }, 503)
  const callbackUrl = new URL(callback)
  callbackUrl.searchParams.set('orderId', orderId)
  callbackUrl.searchParams.set('token', createHmac('sha256', Bun.env.MPESA_CALLBACK_SECRET).update(orderId).digest('hex'))
  if (order.status === 'paid' || order.status === 'stk_sent') return c.json({ error: 'Order already paid or payment pending' }, 409)

  const ts = timestamp(); const password = btoa(`${shortcode}${passkey}${ts}`)
  const token = await getMpesaToken()
  const normalPhone = normalizePhone(phone)

  const stkRes  = await fetch(`${mpesaBase()}/mpesa/stkpush/v1/processrequest`,{
    method:'POST', headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
    body:JSON.stringify({BusinessShortCode:shortcode,Password:password,Timestamp:ts,TransactionType:'CustomerPayBillOnline',Amount:amount,PartyA:normalPhone,PartyB:shortcode,PhoneNumber:normalPhone,CallBackURL:callbackUrl.toString(),AccountReference:orderId.slice(0,12),TransactionDesc:'Playify'})
  })
  const stkJson = await stkRes.json() as any

  await execute(
    `UPDATE public."ShopOrder" SET status = $1, "paymentMethod" = 'mpesa', "paymentRef" = $2, "updatedAt" = NOW() WHERE id = $3`,
    [stkJson.ResponseCode==='0'?'stk_sent':'stk_failed', stkJson.CheckoutRequestID??null, orderId]
  )
  return c.json(stkJson, stkRes.ok ? 200 : 400)
})

mpesaRouter.post('/callback', mpesaCallbackHandler)
