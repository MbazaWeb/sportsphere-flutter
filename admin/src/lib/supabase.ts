import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY as string

if (!url || !anon) {
  console.warn('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY')
}

export const supabase = createClient(url, anon, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})

export type Profile = {
  id: string
  handle: string | null
  role: string | null
  first_name: string | null
  last_name: string | null
  email: string | null
  is_verified: boolean | null
  avatar_url: string | null
  country: string | null
  created_at?: string
}

export type TeamRow = {
  id: string
  name: string
  shortName: string | null
  city: string | null
  logoUrl: string | null
  leagueId: string | null
  verified: boolean | null
  accountUserId: string | null
}

export type MatchRow = {
  id: string
  league: string | null
  homeTeam: string
  awayTeam: string
  homeScore: number | null
  awayScore: number | null
  status: string | null
  kickoffAt: string | null
  season: string | null
  homeBadge: string | null
  awayBadge: string | null
  events: Record<string, unknown> | null
}

export type PostRow = {
  id: string
  userId: string
  content: string
  postType: string | null
  mediaUrls: string[] | null
  likeCount: number | null
  commentCount: number | null
  createdAt: string | null
}

export type ClaimRow = {
  id: string
  entityType: string
  entityId: string
  status: string
  evidence: string | null
  createdAt?: string
}
