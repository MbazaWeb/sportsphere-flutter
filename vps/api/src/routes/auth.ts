import { sendEmail } from '../lib/email.js'
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
  if (!user.passwordHash) {
    // Migrated user — never set a VPS password yet
    return c.json({
      error: 'Please set your Playify password first.',
      code:  'PASSWORD_NOT_SET',
      hint:  'Use forgot-password to receive a reset link.',
    }, 401)
  }

  const valid = await verifyPassword(password, user.passwordHash)
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
    `SELECT u.id, u.name, u.email, u.handle, u.role, u."avatarUrl", u."coverUrl",
            u."isVerified", u."registeredAt", u."lastSeenAt",
            p.bio, p.avatar_url, p.cover_url, p.dob, p.theme_color,
            p.is_verified, p.is_pro, p.country,
            COALESCE(p.post_count, 0)      AS "postCount",
            COALESCE(p.follower_count, 0)  AS "followerCount",
            COALESCE(p.following_count, 0) AS "followingCount",
            COALESCE(p.fan_count, 0)       AS "fanCount",
            p.latitude, p.longitude
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

  // Generate reset token (1 hour expiry)
  const token     = randomBytes(32).toString('hex')
  const tokenHash = createHash('sha256').update(token).digest('hex')

  // Delete any existing reset token for this user first
  await execute(`DELETE FROM public.password_resets WHERE user_id=$1`, [user.id]).catch(()=>{})

  await execute(
    `INSERT INTO public.password_resets(id, user_id, token_hash, expires_at, created_at)
     VALUES(gen_random_uuid()::text,$1,$2,NOW()+INTERVAL '1 hour',NOW())`,
    [user.id, tokenHash]
  ).catch(()=>{})

  const resetUrl  = `https://playifysport.fun/reset-password?token=${token}`
  const appName   = 'Playify'
  const emailSent = await sendEmail({
    to:      email.trim().toLowerCase(),
    subject: `Reset your ${appName} password`,
    html: `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#071420;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#071420;padding:40px 20px">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0" style="background:#0d2137;border-radius:16px;overflow:hidden;max-width:480px;width:100%">
        <!-- Header -->
        <tr><td style="background:linear-gradient(135deg,#168CFF,#0e6cc4);padding:32px;text-align:center">
          <div style="font-size:28px;font-weight:900;color:#fff;letter-spacing:-0.5px">${appName}</div>
          <div style="font-size:13px;color:rgba(255,255,255,0.7);margin-top:4px">The Sports Social Network</div>
        </td></tr>
        <!-- Body -->
        <tr><td style="padding:32px">
          <h2 style="color:#fff;font-size:20px;font-weight:700;margin:0 0 12px">Reset your password</h2>
          <p style="color:rgba(255,255,255,0.65);font-size:15px;line-height:1.6;margin:0 0 24px">
            Hi ${user.name}, we received a request to reset your Playify password. Click the button below to set a new password. This link expires in <strong style="color:#fff">1 hour</strong>.
          </p>
          <a href="${resetUrl}" style="display:inline-block;background:#168CFF;color:#fff;text-decoration:none;font-weight:700;font-size:15px;padding:14px 28px;border-radius:10px;margin-bottom:24px">
            Reset Password →
          </a>
          <p style="color:rgba(255,255,255,0.4);font-size:13px;margin:0 0 8px">Or copy this link:</p>
          <p style="color:#168CFF;font-size:12px;word-break:break-all;margin:0 0 24px">${resetUrl}</p>
          <hr style="border:none;border-top:1px solid rgba(255,255,255,0.08);margin:0 0 20px">
          <p style="color:rgba(255,255,255,0.3);font-size:12px;margin:0">
            If you didn't request this, ignore this email — your account is safe.<br>
            This link expires in 1 hour.
          </p>
        </td></tr>
        <!-- Footer -->
        <tr><td style="padding:16px 32px;text-align:center;border-top:1px solid rgba(255,255,255,0.06)">
          <p style="color:rgba(255,255,255,0.25);font-size:11px;margin:0">
            © ${new Date().getFullYear()} Playify · playifysport.fun
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`,
  })

  if (!emailSent) {
    console.error(`[Password Reset] Email failed for ${user.id} — token logged for manual delivery`)
    console.log(`[Password Reset] MANUAL: ${resetUrl}`)
  }

  return c.json({ ok: true })
})

// ── POST /v1/auth/reset-password ─────────────────────────────────────────────
authRouter.post('/reset-password', async (c) => {
  const { token, password } = await c.req.json<{ token: string; password: string }>()
  if (!token || !password) return c.json({ error: 'token and password required' }, 400)
  if (password.length < 8) return c.json({ error: 'Password must be at least 8 characters' }, 400)

  const tokenHash = createHash('sha256').update(token).digest('hex')
  const reset = await queryOne<{ id: string; user_id: string; expires_at: string; used_at: string | null }>(
    `SELECT id, user_id, expires_at, used_at FROM public.password_resets WHERE token_hash=$1`,
    [tokenHash]
  )

  if (!reset)                return c.json({ error: 'Invalid or expired reset link' }, 400)
  if (reset.used_at)         return c.json({ error: 'This reset link has already been used' }, 400)
  if (new Date(reset.expires_at) < new Date()) {
                              return c.json({ error: 'Reset link has expired — please request a new one' }, 400)
  }

  const newHash = await Bun.password.hash(password, { algorithm: 'bcrypt', cost: 12 })
  await execute(`UPDATE public."User" SET "passwordHash"=$1, "updatedAt"=NOW() WHERE id=$2`, [newHash, reset.user_id])
  await execute(`UPDATE public.password_resets SET used_at=NOW() WHERE id=$1`, [reset.id])
  await execute(`DELETE FROM public.refresh_tokens WHERE user_id=$1`, [reset.user_id]).catch(()=>{})

  // Issue new tokens so user is immediately logged in
  const userRow = await queryOne<any>(
    `SELECT id, name, email, handle, role FROM public."User" WHERE id=$1`, [reset.user_id]
  )
  if (!userRow) return c.json({ ok: true, message: 'Password reset — please login' })

  const JWT_SECRET      = Bun.env.JWT_SECRET ?? ''
  const REFRESH_SECRET  = Bun.env.REFRESH_SECRET ?? ''
  const { SignJWT }     = await import('jose')
  const enc             = new TextEncoder()

  const accessToken = await new SignJWT({ sub: userRow.id, role: userRow.role, handle: userRow.handle })
    .setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('15m')
    .sign(enc.encode(JWT_SECRET))
  const refreshToken = await new SignJWT({ sub: userRow.id, type: 'refresh' })
    .setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('30d')
    .sign(enc.encode(REFRESH_SECRET))

  return c.json({ ok: true, accessToken, refreshToken, user: userRow })
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

// ── POST /v1/auth/otp/send ─────────────────────────────────────────────────
// Send 6-digit OTP to email for identity verification
authRouter.post('/otp/send', async (c) => {
  const { email } = await c.req.json<{ email: string }>()
  if (!email) return c.json({ error: 'email required' }, 400)

  const user = await queryOne<any>(`SELECT id, name FROM public."User" WHERE email=$1`,
    [email.trim().toLowerCase()])
  if (!user) return c.json({ ok: true }) // silent — don't reveal if email exists

  // Generate 6-digit OTP valid 10 min
  const otp      = Math.floor(100000 + Math.random() * 900000).toString()
  const otpHash  = createHash('sha256').update(otp).digest('hex')
  const expires  = new Date(Date.now() + 10 * 60 * 1000).toISOString()

  // Store OTP in password_resets table (reuse for simplicity)
  await execute(`DELETE FROM public.password_resets WHERE user_id=$1`, [user.id]).catch(()=>{})
  await execute(
    `INSERT INTO public.password_resets(id, user_id, token_hash, expires_at, created_at)
     VALUES(gen_random_uuid()::text, $1, $2, $3, NOW())`,
    [user.id, otpHash, expires]
  )

  const { sendEmail } = await import('../lib/email.js')
  await sendEmail({
    to: email.trim().toLowerCase(),
    subject: 'Your Playify verification code',
    html: `<div style="font-family:sans-serif;background:#071420;padding:32px;color:#fff">
      <h2 style="color:#168CFF">Your verification code</h2>
      <p>Hi ${user.name}, use this code to verify your identity on Playify:</p>
      <div style="font-size:42px;font-weight:900;letter-spacing:8px;color:#fff;
        background:#0d2137;padding:24px;border-radius:12px;text-align:center;margin:24px 0">
        ${otp}
      </div>
      <p style="color:rgba(255,255,255,0.5);font-size:12px">Expires in 10 minutes. Do not share this code.</p>
    </div>`,
  })

  console.log(`[OTP] ${user.id}: ${otp}`) // fallback if email fails
  return c.json({ ok: true })
})

// ── POST /v1/auth/verify-identity ─────────────────────────────────────────
// Verify identity via DOB or OTP (no password change yet — just verify)
authRouter.post('/verify-identity', async (c) => {
  const { email, method, dob, otp } = await c.req.json<any>()
  if (!email) return c.json({ error: 'email required' }, 400)

  const user = await queryOne<any>(
    `SELECT u.id, u."dateOfBirth", p.dob FROM public."User" u
     LEFT JOIN public.profiles p ON p.id::text=u.id
     WHERE u.email=$1`,
    [email.trim().toLowerCase()]
  )
  if (!user) return c.json({ error: 'Verification failed' }, 400)

  if (method === 'dob') {
    const userDob = (user.dob ?? user.dateOfBirth ?? '').toString().slice(0,10)
    const inputDob = new Date(dob).toISOString().slice(0,10)
    if (!userDob || userDob !== inputDob) {
      return c.json({ error: 'Date of birth does not match our records' }, 400)
    }
    return c.json({ ok: true, verified: true })
  }

  if (method === 'otp') {
    const otpHash = createHash('sha256').update(otp ?? '').digest('hex')
    const reset   = await queryOne<any>(
      `SELECT id, expires_at FROM public.password_resets WHERE user_id=$1 AND token_hash=$2`,
      [user.id, otpHash]
    )
    if (!reset) return c.json({ error: 'Invalid or expired code' }, 400)
    if (new Date(reset.expires_at) < new Date()) return c.json({ error: 'Code has expired — request a new one' }, 400)
    return c.json({ ok: true, verified: true })
  }

  return c.json({ error: 'Invalid verification method' }, 400)
})

// ── POST /v1/auth/set-password ────────────────────────────────────────────
// Set password after identity verification (DOB or OTP)
authRouter.post('/set-password', async (c) => {
  const { email, password, method, dob, otp } = await c.req.json<any>()
  if (!email || !password) return c.json({ error: 'email and password required' }, 400)
  if (password.length < 8) return c.json({ error: 'Password must be at least 8 characters' }, 400)

  const user = await queryOne<any>(
    `SELECT u.id, u."dateOfBirth", u.name, u.handle, u.role, p.dob
     FROM public."User" u LEFT JOIN public.profiles p ON p.id::text=u.id
     WHERE u.email=$1`,
    [email.trim().toLowerCase()]
  )
  if (!user) return c.json({ error: 'User not found' }, 404)

  // Re-verify identity
  let verified = false
  if (method === 'dob') {
    const userDob  = (user.dob ?? user.dateOfBirth ?? '').toString().slice(0,10)
    const inputDob = new Date(dob).toISOString().slice(0,10)
    verified = !!(userDob && userDob === inputDob)
  } else if (method === 'otp') {
    const otpHash = createHash('sha256').update(otp ?? '').digest('hex')
    const reset   = await queryOne<any>(
      `SELECT id, expires_at FROM public.password_resets WHERE user_id=$1 AND token_hash=$2`,
      [user.id, otpHash]
    )
    verified = !!(reset && new Date(reset.expires_at) >= new Date())
    if (verified) await execute(`UPDATE public.password_resets SET used_at=NOW() WHERE id=$1`, [reset.id])
  }

  if (!verified) return c.json({ error: 'Identity verification failed' }, 401)

  // Set password
  const hash = await Bun.password.hash(password, { algorithm: 'bcrypt', cost: 12 })
  await execute(`UPDATE public."User" SET "passwordHash"=$1,"updatedAt"=NOW() WHERE id=$2`, [hash, user.id])
  await execute(`DELETE FROM public.refresh_tokens WHERE user_id=$1`, [user.id]).catch(()=>{})

  // Issue new tokens (auto-login)
  const JWT_SECRET     = Bun.env.JWT_SECRET ?? ''
  const REFRESH_SECRET = Bun.env.REFRESH_SECRET ?? ''
  const { SignJWT }    = await import('jose')
  const enc            = new TextEncoder()

  const accessToken  = await new SignJWT({ sub: user.id, role: user.role, handle: user.handle })
    .setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('15m')
    .sign(enc.encode(JWT_SECRET))
  const refreshToken = await new SignJWT({ sub: user.id, type: 'refresh' })
    .setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('30d')
    .sign(enc.encode(REFRESH_SECRET))

  return c.json({ ok: true, accessToken, refreshToken,
    user: { id: user.id, name: user.name, handle: user.handle, role: user.role } })
})
