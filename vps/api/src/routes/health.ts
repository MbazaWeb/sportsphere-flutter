// vps/api/src/routes/health.ts
import { Hono } from 'hono'
export const healthRouter = new Hono()

healthRouter.get('/', (c) => c.json({
  ok: true, app: 'playify-api', ts: Date.now(), env: Bun.env.NODE_ENV ?? 'production'
}))
