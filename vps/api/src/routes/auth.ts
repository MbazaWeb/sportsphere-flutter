// vps/api/src/routes/auth.ts
// Full auth system on VPS — no Supabase Auth dependency
// Uses: bcrypt (password hashing) + jose (JWT RS256)
// Tables: public."User" + public.profiles

import { Hono } from 'hono'
import { query, queryOne, execute, transaction } from '../lib/db.js'
// jose imported dynamically inside signToken/verifyJwt to avoid top-level await issues
import { createHash, randomBytes } from 'crypto'

export const authRouter = new Hono()

// ── JWT helpers ───────────────────────────────────────────────────────────────
const JWT_SECRET = Bun.env.JWT_SECRET ?? randomBytes(64).toString('hex')
const JWT_EXPIRES = Bun.env.JWT_EXPIRES_IN ?? '15m'
const REFRESH_SECRET = Bun.env.REFRESH_SECRET ?? randomBytes(64).toString('hex')
const REFRESH_EXPIRES = Bun.env.REFRESH_EXPIRES_IN ?? '30d'

// HMAC-based JWT (simple, fast — upgrade to RS256 if needed)
const encoder = new TextEncoder()

async function signToken(payload: Record<string, unknown>, secret: string, expiresIn: string): Promise<string> {
  const secret_bytes = encoder.encode(secret)
  const { SignJWT: Sign } = await import('jose')
  return new Sign(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(secret_bytes)
}

async function verifyJwt(token: string, secret: string): Promise<any> {
  const { jwtVerify: verify } = await import('jose')
  const { payload } = await verify(token, encoder.encode(secret))
  return payload
}

// ── Bcrypt password hashing (using Bun's built-in) ────────────────────────────
async function hashPassword(password: string): Promise<string> {
  return Bun.password.hash(password, { algorithm: 'bcrypt', cost: 12 })
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return Bun.password.verify(password, hash)
}

// ── Handle deduplication ──────────────────────────────────────────────────────
async function uniqueHandle(base: string): Promise<string> {
  let handle = base.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 30)
  if (!handle) handle = 'user'
  let attempt = handle
  let suffix = 0
  while (true) {
    const existing = await queryOne(`SELECT id FROM public."User" WHERE handle = $1`, [attempt])
    if (!existing) return attempt
    suffix++
    attempt = `${handle}${suffix}`
    if (suffix > 999) return `${handle}${Date.now()}`
  }
}

// ── POST /v1/auth/register ────────────────────────────────────────────────────
authRouter.post('/register', async (c) => {
  const { email, password, firstName, lastName, handle, country, dob, role, avatarUrl } =
    await c.req.json<{
      email: string; password: string; firstName?: string; lastName?: string
      handle?: string; country?: string; dob?: string; role?: string; avatarUrl?: string
    }>()

  if (!email?.includes('@')) return c.json({ error: 'Valid email required' }, 400)
  if (!password || password.length < 8) return c.json({ error: 'Password must be at least 8 characters' }, 400)

  const normalEmail = email.trim().toLowerCase()

  // Check duplicate email
  const existing = await queryOne(`SELECT id FROM public."User" WHERE email = $1`, [normalEmail])
  if (existing) return c.json({ error: 'Email already registered' }, 409)

  const userId     = crypto.randomUUID()
  const hash       = await hashPassword(password)
  const finalHandle = await uniqueHandle(handle ?? normalEmail.split('@')[0])
  const name       = [firstName, lastName].filter(Boolean).join(' ') || finalHandle
  const userRole   = role ?? 'fan'

  await transaction(async (client) => {
    // Insert into User table
    await client.query(
      `INSERT INTO public."User"(id, name, email, handle, role, "passwordHash", "avatarUrl", "emailVerified", "registeredAt", "updatedAt")
       VALUES($1,$2,$3,$4,$5,$6,$7,false,NOW(),NOW())`,
      [userId, name, normalEmail, finalHandle, userRole, hash, avatarUrl ?? null]
    )
    // Insert into profiles (snake_case)
    await client.query(
      `INSERT INTO public.profiles(id, handle, role, first_name, last_name, email, country, dob, created_at, updated_at)
       VALUES($1::uuid,$2,$3,$4,$5,$6,$7,$8::date,NOW(),NOW())`,
      [userId, finalHandle, userRole, firstName??'', lastName??'', normalEmail, country??'Tanzania', dob??null]
    )
  })

  // Issue tokens
  const accessToken  = await signToken({ sub: userId, role: userRole, handle: finalHandle }, JWT_SECRET, JWT_EXPIRES)
  const refreshToken = await signToken({ sub: userId, type: 'refresh' }, REFRESH_SECRET, REFRESH_EXPIRES)

  // Save refresh token hash
  const tokenHash = createHash('sha256').update(refreshToken).digest('hex')
  await execute(
    `INSERT INTO public.refresh_tokens(id, user_id, token_hash, expires_at, created_at)
     VALUES(gen_random_uuid()::text, $1, $2, NOW() + INTERVAL '30 days', NOW())
     ON CONFLICT DO NOTHING`,
    [userId, tokenHash]
  ).catch(() => {}) // table may not exist yet — non-fatal

  const user = await queryOne(`SELECT id, name, email, handle, role, "avatarUrl", "isVerified" FROM public."User" WHERE id=$1`, [userId])
  return c.json({ ok: true, accessToken, refreshToken, user }, 201)
})

// ── POST /v1/auth/login ───────────────────────────────────────────────────────
authRouter.post('/login', async (c) => {
  const { email, password, handle } = await c.req.json<{ email?: string; password: string; handle?: string }>()
  if (!password) return c.json({ error: 'Password required' }, 400)

  let user: any = null

  if (email) {
    user = await queryOne(
      `SELECT id, name, email, handle, role, "passwordHash", "avatarUrl", "isVerified", "isBanned"
       FROM public."User" WHERE email = $1`,
      [email.trim().toLowerCase()]
    )
  } else if (handle) {
    // Login by handle — resolve to email
    user = await queryOne(
      `SELECT id, name, email, handle, role, "passwordHash", "avatarUrl", "isVerified", "isBanned"
       FROM public."User" WHERE handle = $1`,
      [handle.replace('@','').toLowerCase()]
    )
  }

  if (!user) return c.json({ error: 'Invalid email or password' }, 401)
  if (user.isBanned) return c.json({ error: 'Account suspended' }, 403)

  // Verify password
  const valid = user.passwordHash
    ? await verifyPassword(password, user.passwordHash)
    : false

  if (!valid) return c.json({ error: 'Invalid email or password' }, 401)

  // Update last seen
  await execute(`UPDATE public."User" SET "lastSeenAt"=NOW() WHERE id=$1`, [user.id]).catch(()=>{})

  const accessToken  = await signToken({ sub: user.id, role: user.role, handle: user.handle }, JWT_SECRET, JWT_EXPIRES)
  const refreshToken = await signToken({ sub: user.id, type: 'refresh' }, REFRESH_SECRET, REFRESH_EXPIRES)

  const { passwordHash: _, ...safeUser } = user
  return c.json({ ok: true, accessToken, refreshToken, user: safeUser })
})

// ── POST /v1/auth/refresh ─────────────────────────────────────────────────────
authRouter.post('/refresh', async (c) => {
  const { refreshToken } = await c.req.json<{ refreshToken: string }>()
  if (!refreshToken) return c.json({ error: 'Refresh token required' }, 400)

  let payload: any
  try { payload = await verifyJwt(refreshToken, REFRESH_SECRET) }
  catch { return c.json({ error: 'Invalid or expired refresh token' }, 401) }

  const userId = payload.sub as string
  const user   = await queryOne(
    `SELECT id, name, email, handle, role, "avatarUrl", "isVerified" FROM public."User" WHERE id=$1`,
    [userId]
  )
  if (!user) return c.json({ error: 'User not found' }, 401)

  const newAccess  = await signToken({ sub: userId, role: (user as any).role, handle: (user as any).handle }, JWT_SECRET, JWT_EXPIRES)
  const newRefresh = await signToken({ sub: userId, type: 'refresh' }, REFRESH_SECRET, REFRESH_EXPIRES)

  return c.json({ ok: true, accessToken: newAccess, refreshToken: newRefresh, user })
})

// ── GET /v1/auth/me ───────────────────────────────────────────────────────────
authRouter.get('/me', async (c) => {
  const userId = c.get('userId') as string
  const user   = await queryOne(
    `SELECT u.*, p.bio, p.avatar_url, p.cover_url, p.dob, p.theme_color,
            p.is_verified, p.follower_count, p.following_count, p.latitude, p.longitude
     FROM public."User" u
     LEFT JOIN public.profiles p ON p.id::text = u.id
     WHERE u.id = $1`,
    [userId]
  )
  if (!user) return c.json({ error: 'User not found' }, 404)
  const { passwordHash: _, ...safeUser } = user as any
  return c.json({ ok: true, user: safeUser })
})

// ── POST /v1/auth/logout ──────────────────────────────────────────────────────
authRouter.post('/logout', async (c) => {
  const userId = c.get('userId') as string
  // Invalidate all refresh tokens for this user
  await execute(
    `DELETE FROM public.refresh_tokens WHERE user_id = $1`,
    [userId]
  ).catch(()=>{})
  return c.json({ ok: true })
})

// ── POST /v1/auth/change-password ────────────────────────────────────────────
authRouter.post('/change-password', async (c) => {
  const userId = c.get('userId') as string
  const { currentPassword, newPassword } = await c.req.json<{ currentPassword: string; newPassword: string }>()
  if (!currentPassword || !newPassword) return c.json({ error: 'Both passwords required' }, 400)
  if (newPassword.length < 8) return c.json({ error: 'New password must be at least 8 characters' }, 400)

  const user = await queryOne<{ passwordHash: string }>(
    `SELECT "passwordHash" FROM public."User" WHERE id=$1`, [userId]
  )
  if (!user?.passwordHash) return c.json({ error: 'Cannot change password' }, 400)

  const valid = await verifyPassword(currentPassword, user.passwordHash)
  if (!valid) return c.json({ error: 'Current password is incorrect' }, 401)

  const newHash = await hashPassword(newPassword)
  await execute(`UPDATE public."User" SET "passwordHash"=$1, "updatedAt"=NOW() WHERE id=$2`, [newHash, userId])
  await execute(`DELETE FROM public.refresh_tokens WHERE user_id=$1`, [userId]).catch(()=>{})

  return c.json({ ok: true })
})

// ── POST /v1/auth/forgot-password ────────────────────────────────────────────
authRouter.post('/forgot-password', async (c) => {
  const { email } = await c.req.json<{ email: string }>()
  // Always return ok to prevent email enumeration
  if (!email) return c.json({ ok: true })

  const user = await queryOne<{ id: string; name: string }>(
    `SELECT id, name FROM public."User" WHERE email=$1`, [email.trim().toLowerCase()]
  )
  if (!user) return c.json({ ok: true }) // silent

  // Generate reset token
  const token     = randomBytes(32).toString('hex')
  const tokenHash = createHash('sha256').update(token).digest('hex')

  await execute(
    `INSERT INTO public.password_resets(id, user_id, token_hash, expires_at, created_at)
     VALUES(gen_random_uuid()::text,$1,$2,NOW()+INTERVAL '1 hour',NOW())
     ON CONFLICT DO NOTHING`,
    [user.id, tokenHash]
  ).catch(()=>{})

  // TODO: Send email with reset link: https://playifysport.fun/reset-password?token=${token}
  // For now, log it (replace with SMTP/Resend/Mailgun in production)
  console.log(`[Password Reset] User ${user.id}: token=${token}`)

  return c.json({ ok: true })
})

// ── DB tables needed (run once) ───────────────────────────────────────────────
// These are created by the migration script but adding here for reference:
//
// CREATE TABLE IF NOT EXISTS public.refresh_tokens (
//   id text PRIMARY KEY,
//   user_id text NOT NULL REFERENCES public."User"(id) ON DELETE CASCADE,
//   token_hash text NOT NULL UNIQUE,
//   expires_at timestamptz NOT NULL,
//   created_at timestamptz DEFAULT NOW()
// );
//
// CREATE TABLE IF NOT EXISTS public.password_resets (
//   id text PRIMARY KEY,
//   user_id text NOT NULL,
//   token_hash text NOT NULL UNIQUE,
//   expires_at timestamptz NOT NULL,
//   used_at timestamptz,
//   created_at timestamptz DEFAULT NOW()
// );

// PATCH /v1/auth/profile — update profile
authRouter.patch('/profile', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  const sets: string[] = []; const params: unknown[] = []
  const add = (col: string, val: unknown) => { params.push(val); sets.push(`"${col}"=$${params.length}`) }
  if (b.firstName  != null) add('first_name', b.firstName)
  if (b.lastName   != null) add('last_name',  b.lastName)
  if (b.handle     != null) add('handle',     b.handle)
  if (b.country    != null) add('country',    b.country)
  if (b.bio        != null) add('bio',        b.bio)
  if (b.dob        != null) add('dob',        b.dob)
  if (b.avatarUrl  != null) add('avatar_url', b.avatarUrl)
  if (b.coverUrl   != null) add('cover_url',  b.coverUrl)
  if (b.themeColor != null) add('theme_color',b.themeColor)
  if (!sets.length) return c.json({ error: 'Nothing to update' }, 400)
  params.push(userId)
  await query(`UPDATE public.profiles SET ${sets.join(',')}, updated_at=NOW() WHERE id=$${params.length}::uuid`, params)
  return c.json({ ok: true })
})

// POST /v1/auth/resend-confirmation
authRouter.post('/resend-confirmation', async (c) => {
  // VPS native auth doesn't require email confirmation by default
  // This is a no-op stub for API compatibility
  return c.json({ ok: true, message: 'Confirmation resent if email exists' })
})
