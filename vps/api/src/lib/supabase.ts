// vps/api/src/lib/supabase.ts
// Two clients:
//   anon   — for verifying user JWTs (getUser)
//   admin  — service role for privileged operations (never exposed to client)

import { createClient, SupabaseClient } from '@supabase/supabase-js'

const url  = Bun.env.SUPABASE_URL!
const anon = Bun.env.SUPABASE_ANON_KEY!
const svc  = Bun.env.SUPABASE_SERVICE_ROLE_KEY!

if (!url || !anon || !svc) {
  throw new Error('SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY required')
}

// Anon client — used with user JWT to verify auth.getUser()
export const supabaseAnon: SupabaseClient = createClient(url, anon, {
  auth: { persistSession: false, autoRefreshToken: false },
})

// Admin client — service role, never return to client
export const supabaseAdmin: SupabaseClient = createClient(url, svc, {
  auth: { persistSession: false, autoRefreshToken: false },
})

// Verify a Supabase JWT and return the user, or null
export async function verifyToken(token: string) {
  const { data, error } = await supabaseAnon.auth.getUser(token)
  if (error || !data?.user) return null
  return data.user
}

// Check if a user has admin role
export async function isAdmin(userId: string): Promise<boolean> {
  const { data } = await supabaseAdmin
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle()
  const role = String(data?.role ?? '').toLowerCase()
  return ['admin', 'official', 'organization', 'moderator'].includes(role)
}
