// vps/api/src/routes/claims.ts
import { Hono } from 'hono'
import { queryOne, execute } from '../lib/db.js'

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
