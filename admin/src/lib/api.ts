/**
 * playify Admin API helpers — thin layer over Supabase tables
 * used by both the Flutter app and this admin console.
 */
import { supabase, type MatchRow, type Profile, type PostRow, type TeamRow, type LeagueRow, type PlayerRow, type CoachRow, type NewsRow, ROLE_CONFIGS } from './supabase'

// ═══════════════════════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════════════════════

export async function fetchDashboardStats() {
  const [users, teams, matches, posts, claims, news] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('Team').select('id', { count: 'exact', head: true }),
    supabase.from('Match').select('id', { count: 'exact', head: true }),
    supabase.from('Post').select('id', { count: 'exact', head: true }),
    supabase.from('ClaimRequest').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('NewsItem').select('id', { count: 'exact', head: true }),
  ])
  return {
    users: users.count ?? 0,
    teams: teams.count ?? 0,
    matches: matches.count ?? 0,
    posts: posts.count ?? 0,
    pendingClaims: claims.count ?? 0,
    news: news.count ?? 0,
    errors: [users.error, teams.error, matches.error, posts.error, claims.error, news.error]
      .filter(Boolean)
      .map((e) => e!.message),
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILES / USERS
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// ADMIN CREATE USER (with role-based profile)
// ═══════════════════════════════════════════════════════════════

export async function adminCreateUser(params: {
  email: string
  password: string
  firstName: string
  lastName: string
  handle: string
  role: string
  country?: string
  bio?: string
  // Role-specific profile data
  profileData?: Record<string, any>
}) {
  const { email, password, firstName, lastName, handle, role, country, bio, profileData } = params

  // Step 1: Create auth user via admin API (requires service_role key)
  // We use the sign-up approach since the admin is authenticated
  // The handle_new_user trigger will auto-create profiles + User row
  const { data: authData, error: authError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        first_name: firstName,
        last_name: lastName,
        handle: handle,
        country: country || '',
        role: role,
      },
    },
  })

  if (authError) throw new Error(`Auth signup failed: ${authError.message}`)
  const userId = authData.user?.id
  if (!userId) throw new Error('User created but no ID returned')

  // Step 2: Update the profiles table with the correct role
  await supabase.from('profiles').update({
    role,
    first_name: firstName,
    last_name: lastName,
    handle,
    country: country || null,
    bio: bio || null,
  }).eq('id', userId)

  // Step 3: Update the User table (PascalCase) with role
  await supabase.from('User').update({
    role,
    name: `${firstName} ${lastName}`.trim(),
    email,
    handle,
  }).eq('id', userId)

  // Step 4: Create the role-specific profile if applicable
  if (profileData && Object.keys(profileData).length > 0) {
    const config = ROLE_CONFIGS[role]
    if (config && config.table) {
      const profileRow: Record<string, any> = {
        userId,
        ...profileData,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }
      const { error: profileError } = await supabase
        .from(config.table)
        .upsert(profileRow)
      if (profileError) {
        console.warn(`Role profile creation warning: ${profileError.message}`)
        // Don't throw — user is created, profile is optional
      }
    }
  }

  return { userId, email, handle, role }
}

// ═══════════════════════════════════════════════════════════════
// TEAMS
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// LEAGUES
// ═══════════════════════════════════════════════════════════════

export async function listLeagues(): Promise<LeagueRow[]> {
  const { data, error } = await supabase.from('League').select('*').order('name')
  if (error) throw error
  return (data ?? []) as LeagueRow[]
}

export async function createLeague(row: Partial<LeagueRow> & { id: string; name: string }) {
  const { data, error } = await supabase
    .from('League')
    .insert({
      ...row,
      verified: row.verified ?? true,
    })
    .select()
    .single()
  if (error) throw error
  return data as LeagueRow
}

// ═══════════════════════════════════════════════════════════════
// PLAYERS
// ═══════════════════════════════════════════════════════════════

export async function listPlayers(limit = 200): Promise<PlayerRow[]> {
  const { data, error } = await supabase
    .from('Player')
    .select('*, Team(name, shortName), League(name)')
    .order('name')
    .limit(limit)
  if (error) throw error
  return (data ?? []) as PlayerRow[]
}

export async function createPlayer(row: Partial<PlayerRow> & { id: string; name: string }) {
  const { data, error } = await supabase
    .from('Player')
    .insert({
      ...row,
      isClaimable: row.isClaimable ?? true,
    })
    .select()
    .single()
  if (error) throw error
  return data as PlayerRow
}

// ═══════════════════════════════════════════════════════════════
// COACHES
// ═══════════════════════════════════════════════════════════════

export async function listCoaches(limit = 100): Promise<CoachRow[]> {
  const { data, error } = await supabase
    .from('Coach')
    .select('*, Team(name)')
    .order('name')
    .limit(limit)
  if (error) throw error
  return (data ?? []) as CoachRow[]
}

export async function createCoach(row: Partial<CoachRow> & { id: string; name: string }) {
  const { data, error } = await supabase
    .from('Coach')
    .insert({
      ...row,
      isClaimable: row.isClaimable ?? true,
    })
    .select()
    .single()
  if (error) throw error
  return data as CoachRow
}

// ═══════════════════════════════════════════════════════════════
// MATCHES
// ═══════════════════════════════════════════════════════════════

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
  status: string = 'finished',
) {
  const { data, error } = await supabase
    .from('Match')
    .update({ homeScore, awayScore, status: status === 'FT' ? 'finished' : status, updatedAt: new Date().toISOString() })
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
      country: row.country ?? 'Tanzania',
      updatedAt: new Date().toISOString(),
    })
    .select()
    .single()
  if (error) throw error
  return data as MatchRow
}

// ═══════════════════════════════════════════════════════════════
// POSTS
// ═══════════════════════════════════════════════════════════════

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
      hashtags: ['#playify'],
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

// ═══════════════════════════════════════════════════════════════
// NEWS
// ═══════════════════════════════════════════════════════════════

export async function listNews(limit = 100): Promise<NewsRow[]> {
  const { data, error } = await supabase
    .from('NewsItem')
    .select('*')
    .order('publishedAt', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as NewsRow[]
}

export async function createNews(row: {
  title: string
  body?: string
  summary?: string
  imageUrl?: string
  category?: string
  tags?: string[]
  sportId?: string
  source?: string
  source_url?: string
  is_breaking?: boolean
}) {
  const slug = row.title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 120)
  const { data, error } = await supabase
    .from('NewsItem')
    .insert({
      id: `news-${Date.now()}`,
      title: row.title,
      slug,
      body: row.body ?? '',
      summary: row.summary ?? row.title,
      imageUrl: row.imageUrl,
      category: row.category ?? 'general',
      tags: row.tags ?? [],
      sportId: row.sportId,
      source: row.source,
      source_url: row.source_url,
      is_breaking: row.is_breaking ?? false,
      status: 'published',
      publishedAt: new Date().toISOString(),
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      createdAt: new Date().toISOString(),
    })
    .select()
    .single()
  if (error) throw error
  return data as NewsRow
}

export async function deleteNews(id: string) {
  const { error } = await supabase.from('NewsItem').delete().eq('id', id)
  if (error) throw error
}

// ═══════════════════════════════════════════════════════════════
// CLAIMS
// ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════
// HEALTH
// ═══════════════════════════════════════════════════════════════

export async function healthCheck() {
  const start = performance.now()
  const { error } = await supabase.from('profiles').select('id').limit(1)
  const ms = Math.round(performance.now() - start)
  return { ok: !error, latencyMs: ms, error: error?.message ?? null }
}
