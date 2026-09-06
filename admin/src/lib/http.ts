export type AdminSession = { accessToken: string; refreshToken: string; user: { id: string; role: string } }
const storageKey = 'playify-admin-session'
export function getSession(): AdminSession | null {
  try { return JSON.parse(sessionStorage.getItem(storageKey) ?? 'null') } catch { return null }
}
function saveSession(session: AdminSession | null) {
  if (session) sessionStorage.setItem(storageKey, JSON.stringify(session))
  else sessionStorage.removeItem(storageKey)
  window.dispatchEvent(new Event('admin-session'))
}
export async function api<T = any>(path: string, method = 'GET', body?: unknown): Promise<T> {
  const session = getSession()
  const response = await fetch(path, {
    method, headers: { 'Content-Type': 'application/json', ...(session ? { Authorization: `Bearer ${session.accessToken}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const data = await response.json().catch(() => ({ error: 'Unexpected server response' }))
  if (!response.ok) {
    if (response.status === 401 && session) saveSession(null)
    throw new Error(data.error ?? `Request failed (${response.status})`)
  }
  return data as T
}
export async function signIn(email: string, password: string) {
  const session = await api<AdminSession>('/v1/auth/login', 'POST', { email, password })
  if (session.user.role !== 'admin') throw new Error('An administrator account is required')
  saveSession(session)
  try { await api('/v1/admin/stats') } catch (error) { saveSession(null); throw error }
}
export async function signOut() {
  try { await api('/v1/auth/logout', 'POST', {}) } finally { saveSession(null) }
}
