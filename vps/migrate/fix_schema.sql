-- Add all missing columns to VPS tables so pg_dump restore works perfectly
-- Run this BEFORE the migration

-- Sport
ALTER TABLE public."Sport" ADD COLUMN IF NOT EXISTS "sport_slug" text;
ALTER TABLE public."Sport" ADD COLUMN IF NOT EXISTS "parentSportSlug" text;

-- League
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "competitive_level" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "organization_type" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "gender" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "age_category" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "geographic_scope" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "sport_slug" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "sport_variant" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "competition_type" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "competition_format" text;
ALTER TABLE public."League" ADD COLUMN IF NOT EXISTS "competition_level" text;

-- Team
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "competitive_level" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "organization_type" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "gender" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "age_category" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "geographic_scope" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "sport_slug" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "sport_variant" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "isClaimable" boolean DEFAULT true;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "accountUserId" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "identity_status" text DEFAULT 'pending';
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "claimStatus" text DEFAULT 'unclaimed';
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "leagueId" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "sportId" text;
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "metadata" jsonb DEFAULT '{}';
ALTER TABLE public."Team" ADD COLUMN IF NOT EXISTS "source" text DEFAULT 'admin';

-- Player
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "dateOfBirth" timestamptz;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "heightCm" integer;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "weightKg" integer;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "shirtNumber" integer;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "player_type" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "career_level" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "sport_slug" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "gender" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "age_category" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "teamId" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "leagueId" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "sportId" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "accountUserId" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "authUserId" text;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "isClaimable" boolean DEFAULT true;
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "identity_status" text DEFAULT 'pending';
ALTER TABLE public."Player" ADD COLUMN IF NOT EXISTS "claimStatus" text DEFAULT 'unclaimed';

-- Coach
ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "dateOfBirth" timestamptz;
ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "teamId" text;
ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "leagueId" text;
ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "sportId" text;
ALTER TABLE public."Coach" ADD COLUMN IF NOT EXISTS "metadata" jsonb DEFAULT '{}';

-- UserSport
ALTER TABLE public."UserSport" ADD COLUMN IF NOT EXISTS "is_primary" boolean DEFAULT false;
ALTER TABLE public."UserSport" ADD COLUMN IF NOT EXISTS "weight" integer DEFAULT 1;
ALTER TABLE public."UserSport" ADD COLUMN IF NOT EXISTS "isPrimary" boolean DEFAULT false;

-- NewsItem
ALTER TABLE public."NewsItem" ADD COLUMN IF NOT EXISTS "source_url" text;
ALTER TABLE public."NewsItem" ADD COLUMN IF NOT EXISTS "source" text;
ALTER TABLE public."NewsItem" ADD COLUMN IF NOT EXISTS "is_breaking" boolean DEFAULT false;

-- User
ALTER TABLE public."User" ADD COLUMN IF NOT EXISTS "passwordHash" text;
ALTER TABLE public."User" ADD COLUMN IF NOT EXISTS "currentCountry" text;
ALTER TABLE public."User" ADD COLUMN IF NOT EXISTS "coverGradient" text DEFAULT 'from-emerald-600 to-emerald-900';

-- Post
ALTER TABLE public."Post" ADD COLUMN IF NOT EXISTS "playerTag" text;
ALTER TABLE public."Post" ADD COLUMN IF NOT EXISTS "matchId" text;
ALTER TABLE public."Post" ADD COLUMN IF NOT EXISTS "isBreaking" boolean DEFAULT false;

-- Match
ALTER TABLE public."Match" ADD COLUMN IF NOT EXISTS "homeScoreHT" integer;
ALTER TABLE public."Match" ADD COLUMN IF NOT EXISTS "awayScoreHT" integer;
ALTER TABLE public."Match" ADD COLUMN IF NOT EXISTS "attendance" integer;

-- Community
ALTER TABLE public."Community" ADD COLUMN IF NOT EXISTS "teamId" text;
ALTER TABLE public."Community" ADD COLUMN IF NOT EXISTS "createdById" text;

-- Prediction
ALTER TABLE public."Prediction" ADD COLUMN IF NOT EXISTS "outcome" text;
ALTER TABLE public."Prediction" ADD COLUMN IF NOT EXISTS "closedAt" timestamptz;

-- profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "about_me" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "website" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "phone" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "is_verified" boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "is_pro" boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "cover_url" text;

-- RoleRequest table
CREATE TABLE IF NOT EXISTS public."RoleRequest" (
  id              text PRIMARY KEY,
  "userId"        text NOT NULL,
  "requestedRole" text NOT NULL,
  status          text NOT NULL DEFAULT 'pending',
  notes           text,
  "createdAt"     timestamptz NOT NULL DEFAULT NOW(),
  "reviewedAt"    timestamptz
);

-- Auth tables
CREATE TABLE IF NOT EXISTS public.refresh_tokens (
  id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id    text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.password_resets (
  id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id    text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

SELECT 'Schema patched ✅' as status;
