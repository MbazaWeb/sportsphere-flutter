// vps/api/src/routes/shop.ts — shop orders (VPS PostgreSQL, no Supabase)
import { Hono } from 'hono'
import { query, execute, queryOne } from '../lib/db.js'

export const shopRouter = new Hono()

// POST /v1/shop/orders — create a new order
shopRouter.post('/orders', async (c) => {
  const userId = c.get('userId') as string
  if (!userId) return c.json({ error: 'Unauthorized' }, 401)

  const b = await c.req.json<any>()
  const {
    itemId, itemName, kind,
    unitPriceTzs, quantity = 1,
    sellerHandle, sellerName,
    paymentMethod = 'mpesa',
  } = b

  if (!itemId || !itemName || !kind || !unitPriceTzs) {
    return c.json({ error: 'itemId, itemName, kind, unitPriceTzs are required' }, 400)
  }

  const id     = `ord-${Date.now()}`
  const ref    = `SS-${id.substring(4)}`
  const amount = unitPriceTzs * quantity
  const status = paymentMethod === 'demo' ? 'paid' : 'pending_confirm'

  const rows = await query(
    `INSERT INTO public."ShopOrder"
       (id, ref, "userId", "sellerHandle", "sellerName",
        "itemId", "itemName", kind, quantity,
        "unitPriceTzs", "amountTzs", status, "paymentMethod", "createdAt")
     VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW())
     RETURNING *`,
    [id, ref, userId, sellerHandle ?? null, sellerName ?? null,
     itemId, itemName, kind, quantity,
     unitPriceTzs, amount, status, paymentMethod]
  )
  return c.json({ ok: true, order: rows[0], orderId: id }, 201)
})

// GET /v1/shop/orders/mine — buyer's order history
shopRouter.get('/orders/mine', async (c) => {
  const userId = c.get('userId') as string
  const limit  = Math.min(Number(c.req.query('limit') ?? 50), 200)
  const rows   = await query(
    `SELECT * FROM public."ShopOrder" WHERE "userId"=$1 ORDER BY "createdAt" DESC LIMIT $2`,
    [userId, limit]
  )
  return c.json({ ok: true, orders: rows })
})

// GET /v1/shop/orders/seller — seller's received orders
shopRouter.get('/orders/seller', async (c) => {
  const userId = c.get('userId') as string
  const limit  = Math.min(Number(c.req.query('limit') ?? 50), 200)
  // look up handle
  const user = await queryOne<{ handle: string }>(
    `SELECT handle FROM public."User" WHERE id=$1`, [userId]
  )
  if (!user?.handle) return c.json({ ok: true, orders: [] })
  const rows = await query(
    `SELECT * FROM public."ShopOrder" WHERE "sellerHandle"=$1 ORDER BY "createdAt" DESC LIMIT $2`,
    [user.handle, limit]
  )
  return c.json({ ok: true, orders: rows })
})

// PATCH /v1/shop/orders/:id/confirm — mark paid
shopRouter.patch('/orders/:id/confirm', async (c) => {
  const userId  = c.get('userId') as string
  const orderId = c.req.param('id')
  const { providerRef } = await c.req.json<any>().catch(() => ({}))

  const order = await queryOne<any>(
    `SELECT * FROM public."ShopOrder" WHERE id=$1`, [orderId]
  )
  if (!order) return c.json({ error: 'Order not found' }, 404)
  if (order.userId !== userId) return c.json({ error: 'Forbidden' }, 403)

  await execute(
    `UPDATE public."ShopOrder" SET status='paid', "providerRef"=$1, "updatedAt"=NOW() WHERE id=$2`,
    [providerRef ?? null, orderId]
  )
  return c.json({ ok: true })
})

// GET /v1/shop/tickets/:sellerHandle/stats
shopRouter.get('/tickets/:sellerHandle/stats', async (c) => {
  const handle = c.req.param('sellerHandle')
  const rows   = await query<{ quantity: number; amountTzs: number }>(
    `SELECT quantity, "amountTzs" FROM public."ShopOrder"
     WHERE "sellerHandle"=$1 AND kind='ticket' AND status='paid'`,
    [handle]
  )
  const sold   = rows.reduce((s, r) => s + (r.quantity ?? 0), 0)
  const amount = rows.reduce((s, r) => s + (r.amountTzs ?? 0), 0)
  return c.json({ ok: true, sold, amountTzs: amount })
})
