import { Navigate, Route, Routes } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { getSession, api, type AdminSession } from './lib/http'

import { Shell } from './components/Shell'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { UsersPage } from './pages/UsersPage'
import { CreateUserPage } from './pages/CreateUserPage'
import { PlayifyPage } from './pages/PlayifyPage'
import { EntitiesPage } from './pages/EntitiesPage'
import { NewsPage } from './pages/NewsPage'
import { SyncPage } from './pages/SyncPage'
import { ModerationPage } from './pages/ModerationPage'
import { MatchesPage } from './pages/MatchesPage'
import AiAssistantPage from './pages/AiAssistantPage'

export default function App() {
  const [session, setSession] = useState<AdminSession | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const update = () => setSession(getSession())
    const current = getSession()
    if (current) api('/v1/admin/stats').then(() => setSession(current)).catch(() => setSession(null)).finally(() => setLoading(false))
    else setLoading(false)
    window.addEventListener('admin-session', update)
    return () => window.removeEventListener('admin-session', update)
  }, [])

  if (loading) {
    return (
      <div className="login-wrap">
        <p className="muted">Loading Playify Admin…</p>
      </div>
    )
  }

  if (!session) return <LoginPage />

  return (
    <Shell>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/create-user" element={<CreateUserPage />} />
        <Route path="/playify" element={<PlayifyPage />} />
        <Route path="/entities" element={<EntitiesPage />} />
        <Route path="/matches" element={<MatchesPage />} />
        <Route path="/news" element={<NewsPage />} />
        <Route path="/ai" element={<AiAssistantPage />} />
        <Route path="/moderation" element={<ModerationPage />} />
        <Route path="/sync" element={<SyncPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Shell>
  )
}
