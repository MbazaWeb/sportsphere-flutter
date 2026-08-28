// vps/api/src/lib/supabase.ts
// Supabase client ONLY for JWT verification (auth.getUser).
// ALL data queries go through lib/db.ts (direct PostgreSQL).
// This file is intentionally minimal.

import { createClient } from '@supabase/supabase-js'
import { queryOne } from './db.js'

const url  = Bun.env.SUPABASE_URL!
const anon = Bun.env.SUPABASE_ANON_KEY!

if (!url || !anon) {
  throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY required for JWT verification')
}

// Anon client — ONLY used for auth.getUser() JWT verification
// Never used for data queries
const supabaseAuth = createClient(url, anon, {
  auth: { persistSession: false, autoRefreshToken: false },
})

/** Verify a Supabase JWT — returns the user or null */
export async function verifyToken(token: string) {
  const { data, error } = await supabaseAuth.auth.getUser(token)
  if (error || !data?.user) return null
  return data.user
}

/** Check if a user has admin role — reads from VPS PostgreSQL */
export async function isAdmin(userId: string): Promise<boolean> {
  const row = await queryOne<{ role: string }>(
    `SELECT role FROM public.profiles WHERE id = $1`,
    [userId]
  )
  const role = String(row?.role ?? '').toLowerCase()
  return ['admin', 'official', 'organization', 'moderator'].includes(role)
}
