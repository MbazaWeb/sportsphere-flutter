import { Navigate, Route, Routes } from 'react-router-dom'
import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import { Shell } from './components/Shell'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { UsersPage } from './pages/UsersPage'
import { SportSpherePage } from './pages/SportSpherePage'
import { EntitiesPage } from './pages/EntitiesPage'
import { SyncPage } from './pages/SyncPage'
import { ModerationPage } from './pages/ModerationPage'
import { MatchesPage } from './pages/MatchesPage'

export default function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => sub.subscription.unsubscribe()
  }, [])

  if (loading) {
    return (
      <div className="login-wrap">
        <p className="muted">Loading SportSphere Admin…</p>
      </div>
    )
  }

  if (!session) return <LoginPage />

  return (
    <Shell>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/sportsphere" element={<SportSpherePage />} />
        <Route path="/entities" element={<EntitiesPage />} />
        <Route path="/sync" element={<SyncPage />} />
        <Route path="/moderation" element={<ModerationPage />} />
        <Route path="/matches" element={<MatchesPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Shell>
  )
}
