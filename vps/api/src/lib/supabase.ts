// vps/api/src/lib/supabase.ts
// STUB — Supabase fully removed. All auth uses VPS JWT (jose).
// This file kept to avoid import errors during transition.
// TODO: remove all imports of this file once confirmed clean.

import { queryOne } from './db.js'

/** @deprecated — returns null always. VPS JWT used instead. */
export async function verifyToken(_token: string) {
  return null
}

/** Check admin role via VPS PostgreSQL */
export async function isAdmin(userId: string): Promise<boolean> {
  const row = await queryOne<{ role: string }>(
    `SELECT role FROM public.profiles WHERE id = $1`, [userId]
  )
  return ['admin','moderator'].includes(String(row?.role ?? '').toLowerCase())
}
