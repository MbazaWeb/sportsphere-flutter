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

// GET /health/version — current APK version info (use /v1/app/version in index.ts)
healthRouter.get('/version', (c) => {
  return c.json({
    ok: true,
    version:     '1.2.0',   // bump this when you release a new APK
    versionCode: 4,          // must be > previous versionCode
    downloadUrl: 'https://playifysport.fun/app/playify.apk',
    releaseNotes: 'Bug fixes, improved feed, password reset, community updates.',
    forceUpdate: false,      // set true to force update (critical fixes)
    minVersionCode: 1,       // versions below this are force-updated
  })
})
