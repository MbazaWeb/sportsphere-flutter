/**
 * SportSphere Admin API helpers — thin layer over Supabase tables
 * used by both the Flutter app and this admin console.
 */
import { supabase, type MatchRow, type Profile, type PostRow, type TeamRow } from './supabase'

export async function fetchDashboardStats() {
  const [users, teams, matches, posts, claims] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('Team').select('id', { count: 'exact', head: true }),
    supabase.from('Match').select('id', { count: 'exact', head: true }),
    supabase.from('Post').select('id', { count: 'exact', head: true }),
    supabase.from('ClaimRequest').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
  ])
  return {
    users: users.count ?? 0,
    teams: teams.count ?? 0,
    matches: matches.count ?? 0,
    posts: posts.count ?? 0,
    pendingClaims: claims.count ?? 0,
    errors: [users.error, teams.error, matches.error, posts.error, claims.error]
      .filter(Boolean)
      .map((e) => e!.message),
  }
}

export async function listProfiles(limit = 100): Promise<Profile[]> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as Profile[]
}

export async function updateProfile(id: string, patch: Partial<Profile>) {
  const { data, error } = await supabase.from('profiles').update(patch).eq('id', id).select().single()
  if (error) throw error
  return data as Profile
}

export async function verifyProfile(id: string, verified: boolean) {
  return updateProfile(id, { is_verified: verified })
}

export async function listTeams(): Promise<TeamRow[]> {
  const { data, error } = await supabase.from('Team').select('*').order('name')
  if (error) throw error
  return (data ?? []) as TeamRow[]
}

export async function upsertTeam(row: Partial<TeamRow> & { id: string; name: string }) {
  const { data, error } = await supabase.from('Team').upsert(row).select().single()
  if (error) throw error
  return data as TeamRow
}

export async function listMatches(limit = 200): Promise<MatchRow[]> {
  const { data, error } = await supabase
    .from('Match')
    .select('*')
    .order('kickoffAt', { ascending: true })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as MatchRow[]
}

export async function updateMatchResult(
  id: string,
  homeScore: number,
  awayScore: number,
  status: string = 'FT',
) {
  const { data, error } = await supabase
    .from('Match')
    .update({ homeScore, awayScore, status, updatedAt: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data as MatchRow
}

export async function postponeMatch(id: string, note?: string) {
  const { data: existing } = await supabase.from('Match').select('events').eq('id', id).single()
  const events = { ...(existing?.events as object || {}), postponed: true, note: note ?? null }
  const { data, error } = await supabase
    .from('Match')
    .update({ status: 'postponed', events, updatedAt: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data as MatchRow
}

export async function createMatch(row: Partial<MatchRow> & { id: string; homeTeam: string; awayTeam: string }) {
  const { data, error } = await supabase
    .from('Match')
    .insert({
      ...row,
      status: row.status ?? 'scheduled',
      season: row.season ?? '2026/2027',
      league: row.league ?? 'Ligi Kuu Bara',
      country: 'Tanzania',
      updatedAt: new Date().toISOString(),
    })
    .select()
    .single()
  if (error) throw error
  return data as MatchRow
}

export async function listPosts(limit = 100): Promise<PostRow[]> {
  const { data, error } = await supabase
    .from('Post')
    .select('*')
    .order('createdAt', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as PostRow[]
}

export async function createOfficialPost(content: string, mediaUrls: string[] = [], postType = 'text') {
  const { data: session } = await supabase.auth.getUser()
  const uid = session.user?.id
  if (!uid) throw new Error('Not signed in')
  const { data, error } = await supabase
    .from('Post')
    .insert({
      id: `admin-${Date.now()}`,
      userId: uid,
      content,
      postType,
      mediaUrls,
      hashtags: ['#SportSphere'],
      sportTag: 'football',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    })
    .select()
    .single()
  if (error) throw error
  return data as PostRow
}

export async function deletePost(id: string) {
  const { error } = await supabase.from('Post').delete().eq('id', id)
  if (error) throw error
}

export async function listClaims() {
  const { data, error } = await supabase
    .from('ClaimRequest')
    .select('*')
    .order('createdAt', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function resolveClaim(id: string, status: 'approved' | 'rejected') {
  const { data, error } = await supabase
    .from('ClaimRequest')
    .update({ status })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function healthCheck() {
  const start = performance.now()
  const { error } = await supabase.from('profiles').select('id').limit(1)
  const ms = Math.round(performance.now() - start)
  return { ok: !error, latencyMs: ms, error: error?.message ?? null }
}
