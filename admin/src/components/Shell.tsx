import { NavLink } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import type { ReactNode } from 'react'

const links = [
  { to: '/', label: 'Dashboard' },
  { to: '/users', label: 'User Management' },
  { to: '/sportsphere', label: 'SportSphere' },
  { to: '/entities', label: 'League · Team · Player' },
  { to: '/matches', label: 'Match Updates' },
  { to: '/ai', label: 'AI Assistant' },
  { to: '/moderation', label: 'Posts & News' },
  { to: '/sync', label: 'Data Sync & APIs' },
]

export function Shell({ children }: { children: ReactNode }) {
  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <span>SS</span>
          SportSphere Admin
        </div>
        <nav className="nav">
          {links.map((l) => (
            <NavLink key={l.to} to={l.to} end={l.to === '/'}>
              {l.label}
            </NavLink>
          ))}
        </nav>
        <div style={{ marginTop: 28, padding: '0 8px' }}>
          <button className="btn btn-sm" onClick={() => supabase.auth.signOut()}>
            Sign out
          </button>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  )
}
