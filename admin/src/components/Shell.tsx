import { NavLink } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import type { ReactNode } from 'react'

const links = [
  { to: '/', label: 'Dashboard' },
  { to: '/users', label: 'User Management' },
  { to: '/create-user', label: 'Create User (Role-Based)' },
  { to: '/entities', label: 'League · Team · Player · Coach' },
  { to: '/matches', label: 'Match Updates' },
  { to: '/news', label: 'News Management' },
  { to: '/playify', label: 'Playify Posts' },
  { to: '/moderation', label: 'Posts & Content Moderation' },
  { to: '/ai', label: 'AI Assistant' },
  { to: '/sync', label: 'Data Sync & APIs' },
]

export function Shell({ children }: { children: ReactNode }) {
  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">
          <span>SS</span>
          Playify Admin
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
