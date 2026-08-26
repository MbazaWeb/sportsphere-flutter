// vps/api/src/routes/claims.ts
import { Hono } from 'hono'
import { supabaseAdmin } from '../lib/supabase.js'
export const claimsRouter = new Hono()

// POST /v1/claims/approve
claimsRouter.post('/approve', async (c) => {
  const { claimId, reviewNotes } = await c.req.json<{ claimId: string; reviewNotes?: string }>()
  if (!claimId) return c.json({ error: 'claimId required' }, 400)
  const { data, error } = await supabaseAdmin.rpc('approve_claim', {
    p_claim_id: claimId, p_review_notes: reviewNotes ?? '',
  })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true, data })
})

// POST /v1/claims/reject
claimsRouter.post('/reject', async (c) => {
  const { claimId, reviewNotes } = await c.req.json<{ claimId: string; reviewNotes?: string }>()
  if (!claimId) return c.json({ error: 'claimId required' }, 400)
  const { data, error } = await supabaseAdmin.rpc('reject_claim', {
    p_claim_id: claimId, p_review_notes: reviewNotes ?? '',
  })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ ok: true, data })
})
