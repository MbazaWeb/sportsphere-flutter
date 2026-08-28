// vps/api/src/routes/health.ts
import { Hono } from 'hono'
import { dbHealthCheck } from '../lib/db.js'

export const healthRouter = new Hono()

healthRouter.get('/', async (c) => {
  const dbOk = await dbHealthCheck()
  const status = dbOk ? 200 : 503
  return c.json({
    ok:      dbOk,
    app:    'playify-api',
    ts:      Date.now(),
    env:     Bun.env.NODE_ENV ?? 'production',
    db:      dbOk ? 'ok' : 'error',
  }, status)
})
