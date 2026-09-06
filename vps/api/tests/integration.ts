import sharp from 'sharp'
import { S3Client, DeleteObjectCommand } from '@aws-sdk/client-s3'
// Run only against the isolated candidate. Creates and removes disposable test users.
import { randomBytes, createHash } from 'crypto'
import { SignJWT } from 'jose'
import { pool } from '../src/lib/db'
import candidate from '../src/index'

if (Bun.env.PLAYIFY_CANDIDATE_TEST !== '1') throw new Error('Set PLAYIFY_CANDIDATE_TEST=1 in staging')
const server = Bun.serve({ ...candidate, port: 0, hostname: '127.0.0.1' })
const base = `http://127.0.0.1:${server.port}`
const suffix = randomBytes(6).toString('hex')
const password = randomBytes(18).toString('hex')
const users: string[] = []
const cleanup: Array<[string, string]> = []
const mediaKeys: string[] = []
const s3 = new S3Client({ endpoint: Bun.env.MINIO_ENDPOINT, region: Bun.env.MINIO_REGION ?? 'us-east-1', forcePathStyle:true, credentials:{ accessKeyId:Bun.env.MINIO_ROOT_USER!,secretAccessKey:Bun.env.MINIO_ROOT_PASSWORD! } })
let failures = 0
async function request(path: string, token?: string, method = 'GET', body?: unknown) {
  const res = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) })
  return { status: res.status, data: await res.json() as any }
}
function check(name: string, actual: unknown, expected: unknown) {
  const pass = actual === expected
  if (!pass) failures++
  console.log(JSON.stringify({ test: name, pass, actual, expected }))
}
try {
  for (const role of ['fan', 'admin']) {
    const id = crypto.randomUUID(); users.push(id)
    const handle = `check_${role}_${suffix}`
    await pool.query('INSERT INTO public."User"(id,name,email,handle,role,"passwordHash","registeredAt","updatedAt") VALUES($1,$2,$3,$2,$4,$5,NOW(),NOW())', [id,handle,`${handle}@example.invalid`,role,await Bun.password.hash(password)])
    await pool.query('INSERT INTO public.profiles(id,handle,role,email,created_at,updated_at) VALUES($1::uuid,$2,$3,$4,NOW(),NOW())', [id,handle,role,`${handle}@example.invalid`])
  }
  async function token(id: string) { return new SignJWT({ sub:id }).setProtectedHeader({alg:'HS256'}).setIssuedAt().setExpirationTime('5m').sign(new TextEncoder().encode(Bun.env.JWT_SECRET!)) }
  const fan = await token(users[0]), admin = await token(users[1])
  const createdUser = await request('/v1/admin/users',admin,'POST',{email:`check_created_${suffix}@example.invalid`,password,handle:`check_created_${suffix}`,role:'player',profileData:{position:'Striker'}})
  check('admin creates role profile',createdUser.status,201)
  if (createdUser.data.id) users.push(createdUser.data.id)
  for (const [section,table,body,key] of [
    ['teams','Team',{name:`Check ${suffix}`,country:'Tanzania'},'team'],
    ['leagues','League',{name:`Check ${suffix}`,country:'Tanzania'},'league'],
    ['players','Player',{name:`Check ${suffix}`,position:'Striker'},'player'],
    ['coaches','Coach',{name:`Check ${suffix}`},'coach'],
    ['matches','Match',{homeTeam:`Check ${suffix}`,awayTeam:'Check opponent'},'match'],
  ] as const) {
    const result = await request(`/v1/admin/${section}`,admin,'POST',body)
    check(`create ${section}`,result.status, section === 'matches' ? 200 : 201)
    if (result.data[key]?.id) cleanup.push([table,result.data[key].id])
  }
  const form = new FormData()
  form.set('folder','checks')
  form.set('file',new File([await sharp({create:{width:2,height:2,channels:3,background:'#ffffff'}}).png().toBuffer()], 'check.png',{type:'image/png'}))
  const uploaded = await fetch(base+'/v1/media/image',{method:'POST',headers:{Authorization:'Bearer '+fan},body:form})
  const uploadResult = await uploaded.json() as any
  check('media image upload',uploaded.status,200)
  for(const url of Object.values(uploadResult.urls ?? {}) as string[]) mediaKeys.push('checks/'+users[0]+'/'+url.split(users[0]+'/')[1])
  if (mediaKeys[0]) {
    const media = await fetch(base + '/storage/' + mediaKeys[0])
    check('media public download',media.status,200)
    check('media content type',media.headers.get('Content-Type'),'image/webp')
    await media.arrayBuffer()
  }
  const socket = new WebSocket(base.replace('http:','ws:')+'/app/playify-app-key')
  const received: any[] = []
  socket.addEventListener('message',event=>received.push(JSON.parse(String(event.data))))
  async function waitFor(event: string) {
    for(let i=0;i<100;i++){const index=received.findIndex(x=>x.event===event);if(index>=0)return received.splice(index,1)[0];await Bun.sleep(20)}
    throw new Error('WebSocket timeout: '+event)
  }
  const connected = await waitFor('pusher:connection_established')
  const socketId = JSON.parse(connected.data).socket_id
  socket.send(JSON.stringify({event:'pusher:subscribe',data:{channel:'private:user-'+users[0]}}))
  check('websocket rejects unsigned private subscription',(await waitFor('pusher:error')).data.code,4009)
  const signed = await fetch(base+'/v1/realtime/auth',{method:'POST',headers:{Authorization:'Bearer '+fan,'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({socket_id:socketId,channel_name:'private:user-'+users[0]})})
  check('realtime auth works',signed.status,200)
  socket.send(JSON.stringify({event:'pusher:subscribe',data:{channel:'private:user-'+users[0],...(await signed.json())}}))
  check('websocket accepts authorized subscription',(await waitFor('pusher_internal:subscription_succeeded')).channel,'private:user-'+users[0])
  socket.close()
  for (const path of ['/health','/v1/feed','/v1/feed/trending','/v1/news','/v1/matches/live','/v1/matches/today','/v1/matches/upcoming','/v1/matches/results','/v1/matches/standings','/v1/matches/all','/v1/matches/leagues','/v1/social/communities','/v1/social/sports','/v1/nearby?lat=-1.286&lng=36.817']) check(`public ${path}`, (await request(path)).status, 200)
  for (const section of ['stats','users','teams','players','coaches','leagues','matches','news','posts','claims','role-requests','services']) {
    check(`admin ${section}`, (await request(`/v1/admin/${section}`,admin)).status,200)
    check(`deny fan ${section}`, (await request(`/v1/admin/${section}`,fan)).status,403)
  }
  for (const path of ['/v1/auth/me','/v1/notifications','/v1/shop/orders/mine','/v1/shop/orders/seller','/v1/claims/mine','/v1/social/messages','/v1/social/my-sports','/v1/social/my-favorites']) check(`member ${path}`,(await request(path,fan)).status,200)
  for (const action of ['approve','reject']) check(`deny fan claim ${action}`,(await request(`/v1/claims/${action}`,fan,'POST',{claimId:'nonexistent'})).status,403)
  check('deny anonymous post',(await request('/v1/social/posts',undefined,'POST',{content:'must not be created'})).status,401)
  check('deny anonymous realtime auth',(await request('/v1/realtime/auth',undefined,'POST',{})).status,401)
  check('deny unsigned payment callback',[401,503].includes((await request('/v1/mpesa/callback',undefined,'POST',{})).status),true)
  check('deny demo purchase',(await request('/v1/shop/orders',fan,'POST',{itemId:'test',itemName:'test',kind:'ticket',unitPriceTzs:1,paymentMethod:'demo'})).status,400)
  const registered = await request('/v1/auth/register',undefined,'POST',{email:`check_register_${suffix}@example.invalid`,password,role:'admin'})
  check('registration succeeds',registered.status,201)
  if (registered.data.user?.id) users.push(registered.data.user.id)
  check('registration cannot grant admin',registered.data.user?.role,'fan')
  const login = await request('/v1/auth/login',undefined,'POST',{email:`check_fan_${suffix}@example.invalid`,password})
  check('login',login.status,200)
  const refresh = await request('/v1/auth/refresh',undefined,'POST',{refreshToken:login.data.refreshToken})
  check('refresh',refresh.status,200)
  check('refresh replay rejected',(await request('/v1/auth/refresh',undefined,'POST',{refreshToken:login.data.refreshToken})).status,401)
  await request('/v1/auth/logout',fan,'POST',{})
  check('logout revokes refresh',(await request('/v1/auth/refresh',undefined,'POST',{refreshToken:refresh.data.refreshToken})).status,401)
  check('DOB recovery rejected',(await request('/v1/auth/set-password',undefined,'POST',{email:`check_fan_${suffix}@example.invalid`,password,method:'dob',dob:'2000-01-01'})).status,401)
  const otp = '123456', email = `check_fan_${suffix}@example.invalid`
  await pool.query('INSERT INTO public.password_resets(id,user_id,token_hash,expires_at) VALUES($1,$2,$3,NOW()+INTERVAL \'10 minutes\')',[crypto.randomUUID(),users[0],createHash('sha256').update(otp).digest('hex')])
  check('OTP verification',(await request('/v1/auth/verify-identity',undefined,'POST',{email,method:'otp',otp})).status,200)
  check('OTP password reset',(await request('/v1/auth/set-password',undefined,'POST',{email,password,method:'otp',otp})).status,200)
  check('OTP cannot be reused',(await request('/v1/auth/set-password',undefined,'POST',{email,password,method:'otp',otp})).status,401)
  const news = await request('/v1/admin/news',admin,'POST',{title:`Check ${suffix}`,body:'Disposable integration check'})
  check('create news',news.status,201)
  if (news.data.news?.id) { cleanup.push(['NewsItem',news.data.news.id]); check('delete news',(await request(`/v1/admin/news/${news.data.news.id}`,admin,'DELETE')).status,200) }
  const post = await request('/v1/social/posts',fan,'POST',{content:`Disposable check ${suffix}`})
  check('create post',post.status,201)
  if (post.data.post?.id) { cleanup.push(['Post',post.data.post.id]); check('delete post',(await request(`/v1/social/posts/${post.data.post.id}`,fan,'DELETE')).status,200) }
} finally {
  for(const key of mediaKeys) await s3.send(new DeleteObjectCommand({Bucket:'media',Key:key}))
  for (const [table,id] of cleanup.reverse()) await pool.query(`DELETE FROM public."${table}" WHERE id=$1`,[id])
  await pool.query('DELETE FROM public."Community" WHERE name=$1 OR name=$2',[`Check ${suffix} Fans`,`Check ${suffix} Channel`])
  for (const id of users.reverse()) {
    await pool.query('DELETE FROM public."PlayerProfile" WHERE "userId"=$1',[id])
    await pool.query('DELETE FROM public.password_resets WHERE user_id=$1',[id])
    await pool.query('DELETE FROM public.refresh_tokens WHERE user_id=$1',[id])
    await pool.query('DELETE FROM public.profiles WHERE id=$1::uuid',[id])
    await pool.query('DELETE FROM public."User" WHERE id=$1',[id])
  }
  server.stop(true); await pool.end()
}
if (failures) throw new Error(`${failures} integration checks failed`)
