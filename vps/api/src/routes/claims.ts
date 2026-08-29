// vps/api/src/routes/claims.ts
import { Hono } from 'hono'
import { query, queryOne, execute } from '../lib/db.js'

export const claimsRouter = new Hono()

claimsRouter.post('/approve', async (c) => {
  const adminId = c.get('userId') as string
  const { claimId, reviewNotes } = await c.req.json<{claimId:string;reviewNotes?:string}>()
  if (!claimId) return c.json({ error: 'claimId required' }, 400)

  const claim = await queryOne<{userId:string;profileType:string;profileId:string}>(
    `SELECT "userId","profileType","profileId" FROM public."ClaimRequest" WHERE id = $1`, [claimId]
  )
  if (!claim) return c.json({ error: 'Claim not found' }, 404)

  await execute(
    `UPDATE public."ClaimRequest" SET status='approved',"reviewerId"=$1,"reviewNotes"=$2,"reviewedAt"=NOW() WHERE id=$3`,
    [adminId, reviewNotes??'', claimId]
  )
  // Notify claimant
  await execute(
    `INSERT INTO public."Notification"("id","userId","type","title","body","isRead","createdAt")
     VALUES(gen_random_uuid()::text,$1,'claim_approved','Claim approved',$2,false,NOW())`,
    [claim.userId, reviewNotes??'Your profile claim was approved.']
  )
  return c.json({ ok: true, id: claimId, status: 'approved' })
})

claimsRouter.post('/reject', async (c) => {
  const adminId = c.get('userId') as string
  const { claimId, reviewNotes } = await c.req.json<{claimId:string;reviewNotes?:string}>()
  if (!claimId) return c.json({ error: 'claimId required' }, 400)

  const claim = await queryOne<{userId:string}>(
    `SELECT "userId" FROM public."ClaimRequest" WHERE id = $1`, [claimId]
  )
  if (!claim) return c.json({ error: 'Claim not found' }, 404)

  await execute(
    `UPDATE public."ClaimRequest" SET status='rejected',"reviewerId"=$1,"reviewNotes"=$2,"reviewedAt"=NOW() WHERE id=$3`,
    [adminId, reviewNotes??'', claimId]
  )
  await execute(
    `INSERT INTO public."Notification"("id","userId","type","title","body","isRead","createdAt")
     VALUES(gen_random_uuid()::text,$1,'claim_rejected','Claim rejected',$2,false,NOW())`,
    [claim.userId, reviewNotes??'Your profile claim was rejected.']
  )
  return c.json({ ok: true, id: claimId, status: 'rejected' })
})

// GET /v1/claims/mine — user's own claim requests
claimsRouter.get('/mine', async (c) => {
  const userId = c.get('userId') as string
  const rows   = await query(
    `SELECT * FROM public."ClaimRequest" WHERE "userId"=$1 ORDER BY "submittedAt" DESC`,
    [userId]
  )
  return c.json({ ok: true, claims: rows })
})

// POST /v1/claims/submit — submit a new claim
claimsRouter.post('/submit', async (c) => {
  const userId = c.get('userId') as string
  const b = await c.req.json<any>()
  const rows = await query(
    `INSERT INTO public."ClaimRequest"
      ("userId","profileType","profileId","profileName","claimEmail","claimPhone",
       "evidenceNotes","teamId","playerId","coachId","leagueId","status","submittedAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'pending',NOW())
     RETURNING *`,
    [userId, b.profileType, b.profileId, b.profileName,
     b.claimEmail ?? null, b.claimPhone ?? null, b.evidenceNotes ?? null,
     b.teamId ?? null, b.playerId ?? null, b.coachId ?? null, b.leagueId ?? null]
  )
  return c.json({ ok: true, claim: rows[0] }, 201)
})
