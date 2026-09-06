// vps/api/src/middleware/auth.ts
// Verifies VPS JWT (HS256) using jose.
import type { MiddlewareHandler } from 'hono'

const JWT_SECRET = Bun.env.JWT_SECRET ?? ''

async function verifyVpsJwt(token: string): Promise<string | null> {
  if (!JWT_SECRET) return null
  try {
    const { jwtVerify } = await import('jose')
    const { payload } = await jwtVerify(token, new TextEncoder().encode(JWT_SECRET))
    return (payload.sub as string) ?? null
  } catch {
    return null
  }
}

export const authMiddleware: MiddlewareHandler = async (c, next) => {
  const header = c.req.header('Authorization') ?? ''
  const token  = header.replace(/^Bearer\s+/i, '').trim()
  if (!token) return c.json({ error: 'Missing Authorization header' }, 401)

  const userId = await verifyVpsJwt(token)
  if (!userId) return c.json({ error: 'Invalid or expired token' }, 401)

  c.set('userId', userId)
  c.set('token',  token)
  return next()
}
