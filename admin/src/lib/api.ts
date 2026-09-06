import { api } from './http'
import type { Profile, TeamRow, LeagueRow, PlayerRow, CoachRow, MatchRow, PostRow, NewsRow } from './types'
const idPath = (id: string) => encodeURIComponent(id)
export async function fetchDashboardStats() {
  const [{ stats }, { claims }] = await Promise.all([api('/v1/admin/stats'), api('/v1/admin/claims')])
  return { ...stats, pendingClaims: claims.length, errors: [] as string[] }
}
export async function listProfiles(limit = 100): Promise<Profile[]> {
  const { users } = await api(`/v1/admin/users?limit=${limit}`)
  return users.map((u: any) => ({ ...u, first_name: u.first_name ?? u.name, last_name: u.last_name ?? '', is_verified: u.isVerified, created_at: u.registeredAt }))
}
export async function updateProfile(id: string, patch: Partial<Profile>) {
  if (patch.role != null) await api(`/v1/admin/users/${idPath(id)}/role`, 'PATCH', { role: patch.role })
  if (patch.is_verified != null) await verifyProfile(id, patch.is_verified)
}
export const verifyProfile = (id: string, verified: boolean) => api(`/v1/admin/users/${idPath(id)}/verify`, 'PATCH', { verified })
export async function adminCreateUser(params: { email: string; password: string; firstName: string; lastName: string; handle: string; role: string; country?: string; bio?: string; profileData?: Record<string, any> }) {
  const result = await api('/v1/admin/users', 'POST', params)
  return { userId: result.id, email: params.email, handle: result.handle, role: params.role }
}
export async function listTeams(): Promise<TeamRow[]> { return (await api('/v1/admin/teams')).teams }
export async function upsertTeam(row: Partial<TeamRow> & { id: string; name: string }) { return (await api('/v1/admin/teams', 'POST', { ...row, country: row.country || 'Tanzania' })).team }
export async function listLeagues(): Promise<LeagueRow[]> { return (await api('/v1/admin/leagues')).leagues }
export async function createLeague(row: Partial<LeagueRow> & { id: string; name: string }) { return (await api('/v1/admin/leagues', 'POST', row)).league }
export async function listPlayers(limit = 200): Promise<PlayerRow[]> { return (await api(`/v1/admin/players?limit=${limit}`)).players }
export async function createPlayer(row: Partial<PlayerRow> & { id: string; name: string }) { return (await api('/v1/admin/players', 'POST', row)).player }
export async function listCoaches(limit = 100): Promise<CoachRow[]> { return (await api(`/v1/admin/coaches?limit=${limit}`)).coaches }
export async function createCoach(row: Partial<CoachRow> & { id: string; name: string }) { return (await api('/v1/admin/coaches', 'POST', row)).coach }
export async function listMatches(limit = 200): Promise<MatchRow[]> { return (await api(`/v1/admin/matches?limit=${limit}`)).matches }
export const updateMatchResult = (id: string, homeScore: number, awayScore: number, status = 'finished') => api(`/v1/admin/matches/${idPath(id)}`, 'PATCH', { homeScore, awayScore, status: status === 'FT' ? 'finished' : status })
export const postponeMatch = (id: string, note?: string) => api(`/v1/admin/matches/${idPath(id)}`, 'PATCH', { status: 'postponed', note })
export async function createMatch(row: Partial<MatchRow> & { id: string; homeTeam: string; awayTeam: string }) { return (await api('/v1/admin/matches', 'POST', row)).match }
export async function listPosts(limit = 100): Promise<PostRow[]> { return (await api(`/v1/admin/posts?limit=${limit}`)).posts }
export const createOfficialPost = (content: string, mediaUrls: string[] = [], postType = 'text') => api('/v1/social/posts', 'POST', { content, mediaUrls, postType })
export const deletePost = (id: string) => api(`/v1/admin/posts/${idPath(id)}`, 'DELETE')
export async function listNews(limit = 100): Promise<NewsRow[]> { return (await api(`/v1/admin/news?limit=${limit}`)).news }
export async function createNews(row: { title: string; body?: string; summary?: string; imageUrl?: string; category?: string; tags?: string[]; sportId?: string; source?: string; source_url?: string; is_breaking?: boolean }) { return (await api('/v1/admin/news', 'POST', { ...row, body: row.body || row.summary || row.title })).news }
export const deleteNews = (id: string) => api(`/v1/admin/news/${idPath(id)}`, 'DELETE')
export async function listClaims() { return (await api('/v1/admin/claims')).claims }
export const resolveClaim = (id: string, status: 'approved' | 'rejected') => api(`/v1/claims/${status === 'approved' ? 'approve' : 'reject'}`, 'POST', { claimId: id })
export async function healthCheck() {
  const start = performance.now()
  try { const data = await api('/health'); return { ok: !!data.ok, latencyMs: Math.round(performance.now() - start), error: null } }
  catch (e) { return { ok: false, latencyMs: Math.round(performance.now() - start), error: String(e) } }
}
