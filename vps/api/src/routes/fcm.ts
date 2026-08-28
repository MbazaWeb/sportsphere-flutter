// vps/api/src/routes/fcm.ts
import { Hono } from 'hono'
import { query, execute } from '../lib/db.js'
import { isAdmin } from '../lib/supabase.js'

export const fcmRouter = new Hono()

// FCM JWT helpers
function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input
  let bin = ''; for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')
}
function pkcs8Bytes(pem: string): Uint8Array {
  const b64 = pem.replace(/\\n/g,'\n').replace('-----BEGIN PRIVATE KEY-----','')
    .replace('-----END PRIVATE KEY-----','').replace(/\s+/g,'')
  const bin = atob(b64); const arr = new Uint8Array(bin.length)
  for (let i=0;i<bin.length;i++) arr[i]=bin.charCodeAt(i); return arr
}
let _cachedToken: {token:string;exp:number}|null = null
async function getFcmToken(sa: Record<string,string>): Promise<string> {
  if (_cachedToken && _cachedToken.exp > Date.now()/1000+60) return _cachedToken.token
  const now = Math.floor(Date.now()/1000)
  const header  = b64url(JSON.stringify({alg:'RS256',typ:'JWT'}))
  const payload = b64url(JSON.stringify({iss:sa.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}))
  const unsigned = `${header}.${payload}`
  const key = await crypto.subtle.importKey('pkcs8',pkcs8Bytes(sa.private_key),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign'])
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,new TextEncoder().encode(unsigned))
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`
  const res = await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:jwt})})
  if (!res.ok) throw new Error(`FCM OAuth: ${await res.text()}`)
  const j = await res.json() as any
  _cachedToken = {token:j.access_token,exp:now+(j.expires_in??3600)}
  return j.access_token as string
}

// Register device token
fcmRouter.post('/register', async (c) => {
  const userId = c.get('userId') as string
  const { token, platform } = await c.req.json<{token:string;platform:string}>()
  if (!token) return c.json({ error: 'token required' }, 400)
  await execute(
    `INSERT INTO public.device_tokens (user_id, token, platform, updated_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (user_id, token) DO UPDATE SET platform = $3, updated_at = NOW()`,
    [userId, token, platform ?? 'unknown']
  )
  return c.json({ ok: true })
})

// Unregister device token
fcmRouter.post('/unregister', async (c) => {
  const userId = c.get('userId') as string
  const { token } = await c.req.json<{token:string}>()
  if (!token) return c.json({ error: 'token required' }, 400)
  await execute(`DELETE FROM public.device_tokens WHERE user_id = $1 AND token = $2`, [userId, token])
  return c.json({ ok: true })
})

// Send FCM push
fcmRouter.post('/send', async (c) => {
  const callerId = c.get('userId') as string
  const { userId, title, body, data } = await c.req.json<{userId:string;title:string;body?:string;data?:Record<string,string>}>()
  if (!userId || !title) return c.json({ error: 'userId and title required' }, 400)
  if (userId !== callerId && !(await isAdmin(callerId))) return c.json({ error: 'Forbidden' }, 403)

  const saRaw = Bun.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? ''
  if (!saRaw) return c.json({ error: 'FCM not configured' }, 503)
  const sa = JSON.parse(saRaw.trimStart().startsWith('{') ? saRaw : new TextDecoder().decode(Uint8Array.from(atob(saRaw),c=>c.charCodeAt(0))))

  const tokenRows = await query<{token:string}>(`SELECT token FROM public.device_tokens WHERE user_id = $1`, [userId])
  if (!tokenRows.length) return c.json({ ok: true, sent: 0 })

  const accessToken = await getFcmToken(sa)
  let sent = 0
  for (const row of tokenRows) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,{
      method:'POST', headers:{Authorization:`Bearer ${accessToken}`,'Content-Type':'application/json'},
      body:JSON.stringify({message:{token:row.token,notification:{title,body},data:Object.fromEntries(Object.entries(data??{}).map(([k,v])=>[k,String(v)])),android:{priority:'high'}}})
    })
    if (res.ok) sent++; else console.error('[FCM] error:', await res.text())
  }
  return c.json({ ok: true, sent })
})
