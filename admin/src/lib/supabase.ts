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

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

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
  country?: string | null
  foundedYear?: string | null
  venue?: string | null
  sportId?: string | null
  slug?: string | null
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
  venue?: string | null
  continent?: string | null
  country?: string | null
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

export type Role = {
  id: string
  name: string
  slug: string
  description: string
  icon: string
  category: 'individual' | 'organization' | 'commerce'
  displayOrder: number
  isActive: boolean
}

export type LeagueRow = {
  id: string
  name: string
  slug: string | null
  country: string | null
  logoUrl: string | null
  sportId: string | null
  type: string | null
  division: string | null
  season: string | null
  verified: boolean | null
}

export type PlayerRow = {
  id: string
  name: string
  slug: string | null
  firstName: string | null
  lastName: string | null
  position: string | null
  nationality: string | null
  photoUrl: string | null
  dateOfBirth: string | null
  heightCm: number | null
  weightKg: number | null
  shirtNumber: number | null
  teamId: string | null
  leagueId: string | null
  sportId: string | null
  isClaimable: boolean | null
  accountUserId: string | null
}

export type CoachRow = {
  id: string
  name: string
  slug: string | null
  firstName: string | null
  lastName: string | null
  nationality: string | null
  photoUrl: string | null
  teamId: string | null
  leagueId: string | null
  sportId: string | null
  coachingRole: string | null
  license: string | null
  yearsCoaching: number | null
  isClaimable: boolean | null
  accountUserId: string | null
}

export type NewsRow = {
  id: string
  title: string
  slug: string | null
  body: string | null
  summary: string | null
  imageUrl: string | null
  category: string | null
  tags: string[] | null
  sportId: string | null
  status: string | null
  publishedAt: string | null
  viewCount: number | null
  source: string | null
  source_url: string | null
  is_breaking: boolean | null
  likeCount: number | null
  commentCount: number | null
  shareCount: number | null
  createdAt?: string
}

// ═══════════════════════════════════════════════════════════════
// ROLE CONFIG — maps each role to its profile table + fields
// ═══════════════════════════════════════════════════════════════

export interface RoleFieldDef {
  key: string
  label: string
  type: 'text' | 'number' | 'select' | 'date' | 'textarea' | 'tags'
  placeholder?: string
  options?: string[]
 required?: boolean
}

export interface RoleConfig {
  table: string
  fields: RoleFieldDef[]
}

export const ROLE_CONFIGS: Record<string, RoleConfig> = {
  player: {
    table: 'PlayerProfile',
    fields: [
      { key: 'position', label: 'Position', type: 'select', options: ['Goalkeeper', 'Centre-Back', 'Right-Back', 'Left-Back', 'Defensive Midfielder', 'Central Midfielder', 'Attacking Midfielder', 'Right Winger', 'Left Winger', 'Striker', 'Second Striker'], placeholder: 'Select position', required: true },
      { key: 'secondaryPosition', label: 'Secondary Position', type: 'select', options: ['Goalkeeper', 'Centre-Back', 'Right-Back', 'Left-Back', 'Defensive Midfielder', 'Central Midfielder', 'Attacking Midfielder', 'Right Winger', 'Left Winger', 'Striker', 'Second Striker'], placeholder: 'Select secondary position' },
      { key: 'preferredFoot', label: 'Preferred Foot', type: 'select', options: ['Right', 'Left', 'Both'], placeholder: 'Select foot' },
      { key: 'jerseyNumber', label: 'Jersey Number', type: 'number', placeholder: 'e.g. 10' },
      { key: 'height', label: 'Height (cm)', type: 'number', placeholder: 'e.g. 180' },
      { key: 'weight', label: 'Weight (kg)', type: 'number', placeholder: 'e.g. 75' },
      { key: 'nationality', label: 'Nationality', type: 'text', placeholder: 'e.g. Tanzanian' },
      { key: 'playerType', label: 'Player Type', type: 'select', options: ['Youth', 'Amateur', 'Semi-Professional', 'Professional', 'Retired'], placeholder: 'Select type' },
      { key: 'careerStatus', label: 'Career Status', type: 'select', options: ['Active', 'Injured', 'Suspended', 'Free Agent', 'Retired'], placeholder: 'Select status' },
      { key: 'currentClub', label: 'Current Club', type: 'text', placeholder: 'e.g. Simba SC' },
      { key: 'contractUntil', label: 'Contract Until', type: 'text', placeholder: 'e.g. 2028' },
    ],
  },
  coach: {
    table: 'CoachProfile',
    fields: [
      { key: 'coachingRole', label: 'Coaching Role', type: 'select', options: ['Head Coach', 'Assistant Coach', 'Goalkeeping Coach', 'Fitness Coach', 'Technical Director', 'Youth Coach', 'Interim Coach'], placeholder: 'Select role', required: true },
      { key: 'currentTeam', label: 'Current Team', type: 'text', placeholder: 'e.g. Simba SC', required: true },
      { key: 'license', label: 'License / Certification', type: 'text', placeholder: 'e.g. CAF A License' },
      { key: 'nationality', label: 'Nationality', type: 'text', placeholder: 'e.g. Tanzanian' },
      { key: 'yearsCoaching', label: 'Years Coaching', type: 'number', placeholder: 'e.g. 10' },
      { key: 'matchesManaged', label: 'Matches Managed', type: 'number', placeholder: 'e.g. 200' },
      { key: 'wins', label: 'Wins', type: 'number', placeholder: 'e.g. 120' },
      { key: 'preferredFormation', label: 'Preferred Formation', type: 'select', options: ['4-4-2', '4-3-3', '4-2-3-1', '3-5-2', '3-4-3', '5-3-2', '4-1-4-1', '4-5-1'], placeholder: 'Select formation' },
      { key: 'playingPhilosophy', label: 'Playing Philosophy', type: 'textarea', placeholder: 'e.g. Attacking, possession-based football' },
    ],
  },
  team: {
    table: 'TeamProfile',
    fields: [
      { key: 'nickname', label: 'Nickname', type: 'text', placeholder: 'e.g. Msimbazi Red Devils' },
      { key: 'foundedYear', label: 'Founded Year', type: 'text', placeholder: 'e.g. 1936' },
      { key: 'country', label: 'Country', type: 'text', placeholder: 'e.g. Tanzania' },
      { key: 'city', label: 'City', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'stadium', label: 'Stadium', type: 'text', placeholder: 'e.g. National Stadium' },
      { key: 'capacity', label: 'Stadium Capacity', type: 'number', placeholder: 'e.g. 60000' },
      { key: 'league', label: 'League', type: 'text', placeholder: 'e.g. Ligi Kuu Bara' },
      { key: 'coach', label: 'Coach Name', type: 'text', placeholder: 'e.g. John Doe' },
    ],
  },
  scout: {
    table: 'ScoutProfile',
    fields: [
      { key: 'scoutType', label: 'Scout Type', type: 'select', options: ['Talent Scout', 'Tactical Scout', 'Opposition Analyst Scout', 'Youth Scout', 'Chief Scout'], placeholder: 'Select scout type', required: true },
      { key: 'organization', label: 'Organization', type: 'text', placeholder: 'e.g. Simba SC', required: true },
      { key: 'geographicCoverage', label: 'Geographic Coverage', type: 'text', placeholder: 'e.g. East Africa' },
      { key: 'sportsCovered', label: 'Sports Covered', type: 'tags', placeholder: 'football, basketball, athletics' },
      { key: 'yearsExperience', label: 'Years Experience', type: 'number', placeholder: 'e.g. 5' },
    ],
  },
  agent: {
    table: 'AgentProfile',
    fields: [
      { key: 'agentType', label: 'Agent Type', type: 'select', options: ['FIFA Licensed Agent', 'National Licensed Agent', 'Intermediary', 'Agency Owner'], placeholder: 'Select type', required: true },
      { key: 'agency', label: 'Agency Name', type: 'text', placeholder: 'e.g. Star Agency', required: true },
      { key: 'license', label: 'License Number', type: 'text', placeholder: 'e.g. FIFA-12345' },
      { key: 'federation', label: 'Federation', type: 'text', placeholder: 'e.g. TFF' },
    ],
  },
  journalist: {
    table: 'JournalistProfile',
    fields: [
      { key: 'publication', label: 'Publication / Outlet', type: 'text', placeholder: 'e.g. Mwanaspoti', required: true },
      { key: 'beat', label: 'Beat / Beat Coverage', type: 'select', options: ['Football', 'Basketball', 'Athletics', 'Cricket', 'General Sports', 'Investigative', 'Transfer News'], placeholder: 'Select beat' },
      { key: 'location', label: 'Location', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'yearsActive', label: 'Years Active', type: 'number', placeholder: 'e.g. 8' },
    ],
  },
  creator: {
    table: 'CreatorProfile',
    fields: [
      { key: 'creatorType', label: 'Creator Type', type: 'select', options: ['YouTuber', 'TikToker', 'Blogger', 'Podcaster', 'Vlogger', 'Photographer', 'Graphic Designer'], placeholder: 'Select type', required: true },
      { key: 'platforms', label: 'Platforms', type: 'tags', placeholder: 'YouTube, TikTok, Instagram, X' },
      { key: 'niche', label: 'Content Niche', type: 'text', placeholder: 'e.g. Match Analysis, Transfer News' },
      { key: 'followers', label: 'Follower Count', type: 'text', placeholder: 'e.g. 50K' },
    ],
  },
  analyst: {
    table: 'AnalystProfile',
    fields: [
      { key: 'analystType', label: 'Analyst Type', type: 'select', options: ['Performance Analyst', 'Tactical Analyst', 'Data Scientist', 'Video Analyst', 'Set-Piece Analyst'], placeholder: 'Select type', required: true },
      { key: 'organization', label: 'Organization', type: 'text', placeholder: 'e.g. Simba SC', required: true },
      { key: 'expertise', label: 'Areas of Expertise', type: 'tags', placeholder: 'xG, pressing metrics, player profiling' },
    ],
  },
  commentator: {
    table: 'CommentatorProfile',
    fields: [
      { key: 'commentatorType', label: 'Commentator Type', type: 'select', options: ['Play-by-Play', 'Color Commentator', 'Pundit', 'Sideline Reporter'], placeholder: 'Select type', required: true },
      { key: 'broadcaster', label: 'Broadcaster / Network', type: 'text', placeholder: 'e.g. Azam TV', required: true },
      { key: 'languages', label: 'Languages', type: 'tags', placeholder: 'English, Swahili, French' },
      { key: 'sports', label: 'Sports Covered', type: 'tags', placeholder: 'Football, Basketball' },
    ],
  },
  official: {
    table: 'OfficialProfile',
    fields: [
      { key: 'officialType', label: 'Official Type', type: 'select', options: ['Referee', 'Assistant Referee', 'VAR Operator', 'Fourth Official', 'Match Commissioner'], placeholder: 'Select type', required: true },
      { key: 'federation', label: 'Federation', type: 'text', placeholder: 'e.g. TFF, CAF, FIFA' },
      { key: 'license', label: 'License / Certification', type: 'text', placeholder: 'e.g. CAF Elite Referee' },
      { key: 'yearsActive', label: 'Years Active', type: 'number', placeholder: 'e.g. 12' },
    ],
  },
  academy: {
    table: 'AcademyProfile',
    fields: [
      { key: 'academyName', label: 'Academy Name', type: 'text', placeholder: 'e.g. Simba Academy', required: true },
      { key: 'parentOrg', label: 'Parent Organization', type: 'text', placeholder: 'e.g. Simba SC' },
      { key: 'location', label: 'Location', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'foundedYear', label: 'Founded Year', type: 'text', placeholder: 'e.g. 2010' },
    ],
  },
  league: {
    table: 'LeagueProfile',
    fields: [
      { key: 'leagueName', label: 'League Name', type: 'text', placeholder: 'e.g. Ligi Kuu Bara', required: true },
      { key: 'country', label: 'Country', type: 'text', placeholder: 'e.g. Tanzania' },
      { key: 'division', label: 'Division', type: 'text', placeholder: 'e.g. 1' },
      { key: 'currentSeason', label: 'Current Season', type: 'text', placeholder: 'e.g. 2026/2027' },
    ],
  },
  competition: {
    table: 'CompetitionProfile',
    fields: [
      { key: 'competitionName', label: 'Competition Name', type: 'text', placeholder: 'e.g. FA Cup', required: true },
      { key: 'season', label: 'Season', type: 'text', placeholder: 'e.g. 2026' },
      { key: 'organizer', label: 'Organizer', type: 'text', placeholder: 'e.g. TFF' },
      { key: 'country', label: 'Country', type: 'text', placeholder: 'e.g. Tanzania' },
    ],
  },
  organization: {
    table: 'OrganizationProfile',
    fields: [
      { key: 'orgType', label: 'Organization Type', type: 'select', options: ['Federation', 'Association', 'Non-Profit', 'Government Body', 'Sports Council'], placeholder: 'Select type', required: true },
      { key: 'country', label: 'Country', type: 'text', placeholder: 'e.g. Tanzania' },
      { key: 'headquarters', label: 'Headquarters', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'foundedYear', label: 'Founded Year', type: 'text', placeholder: 'e.g. 1945' },
    ],
  },
  media_broadcast: {
    table: 'MediaBroadcastProfile',
    fields: [
      { key: 'outlet', label: 'Media Outlet', type: 'text', placeholder: 'e.g. Azam TV', required: true },
      { key: 'platform', label: 'Platform', type: 'select', options: ['TV', 'Radio', 'Online / Streaming', 'Print', 'Social Media'], placeholder: 'Select platform' },
      { key: 'coverage', label: 'Coverage Area', type: 'text', placeholder: 'e.g. National, East Africa' },
    ],
  },
  community: {
    table: 'CommunityProfile',
    fields: [
      { key: 'communityName', label: 'Community Name', type: 'text', placeholder: 'e.g. Simba Fans Dar', required: true },
      { key: 'communityType', label: 'Community Type', type: 'select', options: ['Fan Club', 'Supporters Group', 'Discussion Group', 'Regional Fans'], placeholder: 'Select type' },
      { key: 'location', label: 'Location', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'supportedTeam', label: 'Supported Team', type: 'text', placeholder: 'e.g. Simba SC' },
      { key: 'description', label: 'Description', type: 'textarea', placeholder: 'What is this community about?' },
    ],
  },
  business: {
    table: 'BusinessProfile',
    fields: [
      { key: 'companyName', label: 'Company Name', type: 'text', placeholder: 'e.g. SportGear TZ', required: true },
      { key: 'industry', label: 'Industry', type: 'select', options: ['Sports Retail', 'Sports Equipment', 'Apparel', 'Nutrition', 'Technology', 'Media', 'Other'], placeholder: 'Select industry' },
      { key: 'headquarters', label: 'Headquarters', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'website', label: 'Website', type: 'text', placeholder: 'e.g. https://sportgear.tz' },
    ],
  },
  sponsor: {
    table: 'SponsorProfile',
    fields: [
      { key: 'brand', label: 'Brand Name', type: 'text', placeholder: 'e.g. SportPesa', required: true },
      { key: 'industry', label: 'Industry', type: 'text', placeholder: 'e.g. Betting / Gaming' },
      { key: 'website', label: 'Website', type: 'text', placeholder: 'e.g. https://sportpesa.co.tz' },
    ],
  },
  commercial_partner: {
    table: 'CommercialPartnerProfile',
    fields: [
      { key: 'partnerType', label: 'Partner Type', type: 'select', options: ['Kit Sponsor', 'Title Sponsor', 'Broadcast Partner', 'Technical Partner', 'Official Partner'], placeholder: 'Select type', required: true },
      { key: 'brand', label: 'Brand Name', type: 'text', placeholder: 'e.g. Nike', required: true },
      { key: 'sportsCategory', label: 'Sports Category', type: 'text', placeholder: 'e.g. Football' },
      { key: 'website', label: 'Website', type: 'text', placeholder: 'e.g. https://nike.com' },
    ],
  },
  venue: {
    table: 'VenueProfile',
    fields: [
      { key: 'venueName', label: 'Venue Name', type: 'text', placeholder: 'e.g. Benjamin Mkapa Stadium', required: true },
      { key: 'venueType', label: 'Venue Type', type: 'select', options: ['Football Stadium', 'Multi-Purpose Stadium', 'Arena', 'Training Ground', 'Sports Complex'], placeholder: 'Select type' },
      { key: 'location', label: 'Location', type: 'text', placeholder: 'e.g. Dar es Salaam' },
      { key: 'capacity', label: 'Capacity', type: 'number', placeholder: 'e.g. 60000' },
    ],
  },
  support_staff: {
    table: 'SupportStaffProfile',
    fields: [
      { key: 'staffRole', label: 'Staff Role', type: 'select', options: ['Physiotherapist', 'Doctor', 'Strength & Conditioning Coach', 'Kit Manager', 'Team Manager', 'Analyst', 'Masseur', 'Nutritionist'], placeholder: 'Select role', required: true },
      { key: 'organization', label: 'Organization / Team', type: 'text', placeholder: 'e.g. Simba SC', required: true },
      { key: 'specialty', label: 'Specialty', type: 'text', placeholder: 'e.g. Sports Injury Rehabilitation' },
    ],
  },
  moderator: {
    table: 'ModeratorProfile',
    fields: [
      { key: 'scope', label: 'Moderation Scope', type: 'select', options: ['Global', 'Community-Specific', 'Content-Specific'], placeholder: 'Select scope', required: true },
      { key: 'communities', label: 'Assigned Communities', type: 'tags', placeholder: 'Community IDs or names' },
    ],
  },
  // Fan has no dedicated profile table
  fan: {
    table: '',
    fields: [],
  },
}

// All 23 roles for dropdown
export const ALL_ROLES = [
  { value: 'fan', label: 'Fan', category: 'individual' },
  { value: 'player', label: 'Player', category: 'individual' },
  { value: 'team', label: 'Team', category: 'organization' },
  { value: 'coach', label: 'Coach', category: 'individual' },
  { value: 'scout', label: 'Scout', category: 'individual' },
  { value: 'agent', label: 'Agent', category: 'individual' },
  { value: 'support_staff', label: 'Support Staff', category: 'individual' },
  { value: 'analyst', label: 'Analyst', category: 'individual' },
  { value: 'commentator', label: 'Commentator', category: 'individual' },
  { value: 'journalist', label: 'Journalist', category: 'individual' },
  { value: 'creator', label: 'Creator', category: 'individual' },
  { value: 'moderator', label: 'Moderator', category: 'individual' },
  { value: 'official', label: 'Official', category: 'individual' },
  { value: 'academy', label: 'Academy', category: 'organization' },
  { value: 'league', label: 'League', category: 'organization' },
  { value: 'competition', label: 'Competition', category: 'organization' },
  { value: 'organization', label: 'Organization', category: 'organization' },
  { value: 'media_broadcast', label: 'Media / Broadcast', category: 'organization' },
  { value: 'community', label: 'Community', category: 'organization' },
  { value: 'business', label: 'Business', category: 'commerce' },
  { value: 'sponsor', label: 'Sponsor', category: 'commerce' },
  { value: 'commercial_partner', label: 'Commercial Partner', category: 'commerce' },
  { value: 'venue', label: 'Venue', category: 'commerce' },
]
