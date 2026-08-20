
-- =============================================================================
-- SportSphere FULL APP SCHEMA (idempotent)
-- Combines: core social, sports data, role profiles, commercial, location,
-- performance ranking, RLS, storage buckets.
-- Preserves existing Flutter tables: profiles, follows, fans, communities,
-- community_members, posts, post_likes, comments.
-- =============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 0. Bridge: ensure profiles has full columns Flutter needs
-- -----------------------------------------------------------------------------
alter table public.profiles add column if not exists dob date;
alter table public.profiles add column if not exists website text;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists about_me text;
alter table public.profiles add column if not exists cover_url text;
alter table public.profiles add column if not exists is_verified boolean default false;
alter table public.profiles add column if not exists is_pro boolean default false;
alter table public.profiles add column if not exists post_count int default 0;


-- -----------------------------------------------------------------------------
-- 1. Core User (PascalCase Prisma-compatible, id = auth.users.id as text)
-- -----------------------------------------------------------------------------
create table if not exists public."User" (
  "id" text primary key,
  "name" text not null default '',
  "email" text not null,
  "handle" text not null,
  "passwordHash" text,
  "avatarUrl" text,
  "avatarInitials" text,
  "role" text not null default 'fan',
  "verificationStatus" text not null default 'none',
  "isVerified" boolean not null default false,
  "bio" text,
  "location" text,
  "coverGradient" text not null default 'from-emerald-600 to-emerald-900',
  "coverUrl" text,
  "aboutMe" text,
  "website" text,
  "phone" text,
  "gender" text,
  "nationality" text,
  "countryOfOrigin" text,
  "currentCountry" text,
  "dateOfBirth" timestamptz,
  "followerCount" integer not null default 0,
  "followingCount" integer not null default 0,
  "fanCount" integer not null default 0,
  "postCount" integer not null default 0,
  "roleData" jsonb not null default '{}',
  "sportsFollowing" jsonb not null default '[]',
  "interests" jsonb not null default '[]',
  "roleProfile" jsonb not null default '{}',
  "preferences" jsonb not null default '{}',
  "privacySettings" jsonb not null default '{}',
  "notifPrefs" jsonb not null default '{}',
  "isPro" boolean not null default false,
  "isBanned" boolean not null default false,
  "bannedAt" timestamptz,
  "bannedReason" text,
  "emailVerified" boolean not null default false,
  "registeredAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  "lastSeenAt" timestamptz not null default now()
);

create unique index if not exists "User_email_key" on public."User"("email");
create unique index if not exists "User_handle_key" on public."User"("handle");
create index if not exists "User_handle_idx" on public."User"("handle");
create index if not exists "User_role_idx" on public."User"("role");


-- -----------------------------------------------------------------------------
-- 2. Social graph + feed (Prisma-compatible)
-- -----------------------------------------------------------------------------
create table if not exists public."Follow" (
  "followerId" text not null references public."User"("id") on delete cascade,
  "followingId" text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("followerId", "followingId")
);
create index if not exists "Follow_followerId_idx" on public."Follow"("followerId");
create index if not exists "Follow_followingId_idx" on public."Follow"("followingId");

create table if not exists public."Post" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "content" text not null default '',
  "postType" text not null default 'post',
  "mediaUrls" jsonb not null default '[]',
  "hashtags" jsonb not null default '[]',
  "teamTag" text,
  "playerTag" text,
  "communityId" text,
  "sportTag" text,
  "isBreaking" boolean not null default false,
  "likeCount" integer not null default 0,
  "commentCount" integer not null default 0,
  "shareCount" integer not null default 0,
  "viewCount" integer not null default 0,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);
create index if not exists "Post_userId_idx" on public."Post"("userId");
create index if not exists "Post_createdAt_idx" on public."Post"("createdAt" desc);

create table if not exists public."PostLike" (
  "postId" text not null references public."Post"("id") on delete cascade,
  "userId" text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("postId", "userId")
);

create table if not exists public."Comment" (
  "id" text primary key default gen_random_uuid()::text,
  "postId" text not null references public."Post"("id") on delete cascade,
  "userId" text not null references public."User"("id") on delete cascade,
  "content" text not null,
  "parentId" text,
  "mentionedUserIds" jsonb not null default '[]',
  "likeCount" integer not null default 0,
  "createdAt" timestamptz not null default now()
);
create index if not exists "Comment_postId_idx" on public."Comment"("postId");
create index if not exists "Comment_userId_idx" on public."Comment"("userId");
create index if not exists "Comment_parentId_idx" on public."Comment"("parentId");

create table if not exists public."CommentLike" (
  "commentId" text not null references public."Comment"("id") on delete cascade,
  "userId" text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("commentId", "userId")
);

create table if not exists public."Poll" (
  "id" text primary key default gen_random_uuid()::text,
  "postId" text not null unique references public."Post"("id") on delete cascade,
  "question" text not null,
  "options" jsonb not null default '[]',
  "totalVotes" integer not null default 0,
  "endsAt" timestamptz,
  "createdAt" timestamptz not null default now()
);

create table if not exists public."PollVote" (
  "id" text primary key default gen_random_uuid()::text,
  "pollId" text not null references public."Poll"("id") on delete cascade,
  "userId" text not null references public."User"("id") on delete cascade,
  "optionIdx" integer not null,
  "createdAt" timestamptz not null default now(),
  unique ("pollId", "userId")
);

create table if not exists public."Community" (
  "id" text primary key default gen_random_uuid()::text,
  "name" text not null,
  "description" text,
  "topic" text,
  "memberCount" integer not null default 0,
  "createdById" text references public."User"("id") on delete set null,
  "createdAt" timestamptz not null default now()
);

create table if not exists public."CommunityMember" (
  "communityId" text not null references public."Community"("id") on delete cascade,
  "userId" text not null references public."User"("id") on delete cascade,
  "role" text not null default 'member',
  "joinedAt" timestamptz not null default now(),
  primary key ("communityId", "userId")
);

create table if not exists public."Notification" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "type" text not null,
  "title" text not null,
  "body" text,
  "isRead" boolean not null default false,
  "actorId" text references public."User"("id") on delete set null,
  "referenceId" text,
  "targetId" text,
  "targetType" text,
  "createdAt" timestamptz not null default now()
);
create index if not exists "Notification_userId_idx" on public."Notification"("userId", "isRead", "createdAt" desc);

create table if not exists public."Message" (
  "id" text primary key default gen_random_uuid()::text,
  "senderId" text not null references public."User"("id") on delete cascade,
  "receiverId" text not null references public."User"("id") on delete cascade,
  "content" text not null,
  "isRead" boolean not null default false,
  "createdAt" timestamptz not null default now()
);
create index if not exists "Message_senderId_idx" on public."Message"("senderId");
create index if not exists "Message_receiverId_idx" on public."Message"("receiverId");


-- -----------------------------------------------------------------------------
-- 3. Roles, sports, favorites
-- -----------------------------------------------------------------------------
create table if not exists public."Role" (
  "id" text primary key,
  "name" text not null unique,
  "slug" text not null unique,
  "description" text not null default '',
  "icon" text not null default '👤',
  "category" text not null default 'individual',
  "displayOrder" integer not null default 0,
  "isActive" boolean not null default true,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."RoleType" (
  "id" text primary key,
  "roleId" text not null references public."Role"("id") on delete cascade,
  "name" text not null,
  "slug" text not null,
  "description" text,
  "requirements" jsonb not null default '[]',
  "displayOrder" integer not null default 0,
  "isActive" boolean not null default true,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now(),
  unique ("roleId", "slug")
);

create table if not exists public."Sport" (
  "id" text primary key,
  "name" text not null unique,
  "slug" text not null unique,
  "icon" text,
  "category" text,
  "description" text,
  "tags" jsonb not null default '[]',
  "isActive" boolean not null default true,
  "displayOrder" integer not null default 0,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."UserSport" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "sportId" text not null references public."Sport"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  unique ("userId", "sportId")
);

do $$ begin
  create type "FavoriteTargetType" as enum (
    'TEAM','PLAYER','COACH','COMPETITION','LEAGUE','NATIONAL_TEAM','STADIUM','SPORT'
  );
exception when duplicate_object then null;
end $$;

create table if not exists public."UserFavorite" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "targetType" "FavoriteTargetType" not null,
  "targetId" text not null,
  "targetName" text not null,
  "targetHandle" text,
  "createdAt" timestamptz not null default now(),
  unique ("userId", "targetType", "targetId")
);


-- -----------------------------------------------------------------------------
-- 4. Sports data layer
-- -----------------------------------------------------------------------------
create table if not exists public."League" (
  "id" text primary key default gen_random_uuid()::text,
  "sportId" text references public."Sport"("id") on delete set null,
  "name" text not null,
  "slug" text not null unique,
  "country" text,
  "countryCode" text,
  "logoUrl" text,
  "type" text not null default 'league',
  "division" text,
  "season" text,
  "externalId" text,
  "source" text default 'admin',
  "verified" boolean not null default false,
  "isActive" boolean not null default true,
  "description" text,
  "metadata" jsonb not null default '{}',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."Team" (
  "id" text primary key default gen_random_uuid()::text,
  "leagueId" text references public."League"("id") on delete set null,
  "sportId" text references public."Sport"("id") on delete set null,
  "name" text not null,
  "slug" text not null unique,
  "shortName" text,
  "city" text,
  "country" text,
  "logoUrl" text,
  "venue" text,
  "foundedYear" integer,
  "source" text default 'admin',
  "verified" boolean not null default false,
  "isActive" boolean not null default true,
  "description" text,
  "metadata" jsonb not null default '{}',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."Player" (
  "id" text primary key default gen_random_uuid()::text,
  "teamId" text references public."Team"("id") on delete set null,
  "leagueId" text references public."League"("id") on delete set null,
  "sportId" text references public."Sport"("id") on delete set null,
  "name" text not null,
  "slug" text not null unique,
  "firstName" text,
  "lastName" text,
  "position" text,
  "nationality" text,
  "photoUrl" text,
  "dateOfBirth" timestamptz,
  "heightCm" integer,
  "weightKg" integer,
  "shirtNumber" integer,
  "verified" boolean not null default false,
  "isActive" boolean not null default true,
  "metadata" jsonb not null default '{}',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."Coach" (
  "id" text primary key default gen_random_uuid()::text,
  "teamId" text references public."Team"("id") on delete set null,
  "leagueId" text references public."League"("id") on delete set null,
  "sportId" text references public."Sport"("id") on delete set null,
  "name" text not null,
  "slug" text not null unique,
  "firstName" text,
  "lastName" text,
  "nationality" text,
  "photoUrl" text,
  "dateOfBirth" timestamptz,
  "role" text not null default 'head_coach',
  "verified" boolean not null default false,
  "isActive" boolean not null default true,
  "metadata" jsonb not null default '{}',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."Match" (
  "id" text primary key default gen_random_uuid()::text,
  "league" text not null default '',
  "homeTeam" text not null,
  "awayTeam" text not null,
  "homeScore" integer,
  "awayScore" integer,
  "status" text not null default 'upcoming',
  "minute" integer,
  "venue" text,
  "kickoffAt" timestamptz not null default now(),
  "events" jsonb not null default '[]',
  "lineups" jsonb not null default '{}',
  "stats" jsonb not null default '[]',
  "homeBadge" text,
  "awayBadge" text,
  "season" text,
  "externalId" text,
  "continent" text default 'Africa',
  "country" text default 'Tanzania',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);
create index if not exists "Match_status_idx" on public."Match"("status");
create index if not exists "Match_kickoffAt_idx" on public."Match"("kickoffAt");

create table if not exists public."Prediction" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "matchId" text references public."Match"("id") on delete set null,
  "postId" text unique,
  "homeTeam" text not null,
  "awayTeam" text not null,
  "predictedHome" integer,
  "predictedAway" integer,
  "confidence" text,
  "result" text,
  "isCorrect" boolean,
  "pointsEarned" integer not null default 0,
  "createdAt" timestamptz not null default now()
);

create table if not exists public."NewsItem" (
  "id" text primary key default gen_random_uuid()::text,
  "title" text not null,
  "slug" text not null unique,
  "body" text not null default '',
  "summary" text,
  "imageUrl" text,
  "category" text not null default 'general',
  "tags" jsonb not null default '[]',
  "sportId" text,
  "status" text not null default 'draft',
  "publishedAt" timestamptz,
  "viewCount" integer not null default 0,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."VerificationRequest" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "role" text not null,
  "roleData" jsonb not null default '{}',
  "roleId" text,
  "roleTypeId" text,
  "status" text not null default 'pending',
  "adminNotes" text,
  "reviewedBy" text,
  "submittedAt" timestamptz not null default now(),
  "reviewedAt" timestamptz
);


-- -----------------------------------------------------------------------------
-- 5. Typed role profile tables (1:1 with User)
-- -----------------------------------------------------------------------------
create table if not exists public."PlayerProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "position" text, "secondaryPosition" text, "preferredFoot" text,
  "jerseyNumber" text, "height" double precision, "weight" double precision,
  "dateOfBirth" timestamptz, "nationality" text, "playerType" text,
  "careerStatus" text, "appearances" double precision, "goals" double precision,
  "assists" double precision, "currentClub" text, "contractUntil" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."CoachProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "coachingRole" text, "currentTeam" text, "license" text,
  "nationality" text, "yearsCoaching" double precision,
  "matchesManaged" double precision, "wins" double precision,
  "preferredFormation" text, "playingPhilosophy" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."TeamProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "nickname" text, "foundedYear" text, "country" text, "city" text,
  "stadium" text, "capacity" double precision, "league" text, "coach" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."ScoutProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "scoutType" text, "organization" text, "geographicCoverage" text,
  "sportsCovered" text[], "yearsExperience" double precision,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."JournalistProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "publication" text, "beat" text, "location" text, "yearsActive" double precision,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."CreatorProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "creatorType" text, "platforms" text[], "niche" text, "followers" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."AnalystProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "analystType" text, "organization" text, "expertise" text[],
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."AgentProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "agentType" text, "agency" text, "license" text, "federation" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."OrganizationProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "orgType" text, "country" text, "headquarters" text, "foundedYear" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."CompetitionProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "competitionName" text, "season" text, "organizer" text, "country" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."LeagueProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "leagueName" text, "country" text, "division" text, "currentSeason" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."AcademyProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "academyName" text, "parentOrg" text, "location" text, "foundedYear" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."VenueProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "venueName" text, "venueType" text, "location" text, "capacity" double precision,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."BusinessProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "companyName" text, "industry" text, "headquarters" text, "website" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."CommercialPartnerProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "partnerType" text, "brand" text, "sportsCategory" text, "website" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."CommunityProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "communityName" text, "communityType" text, "location" text, "supportedTeam" text,
  "memberCount" double precision, "description" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."CommentatorProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "commentatorType" text, "broadcaster" text, "languages" text[], "sports" text[],
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- 6. Commercial + Location (minimal)
-- -----------------------------------------------------------------------------
create table if not exists public."CommercialPartner" (
  "id" text primary key default gen_random_uuid()::text,
  "name" text not null,
  "slug" text not null unique,
  "partnerType" text not null default 'brand',
  "industry" text,
  "website" text,
  "logoUrl" text,
  "country" text,
  "description" text,
  "status" text not null default 'pending',
  "tier" text not null default 'bronze',
  "isActive" boolean not null default true,
  "metadata" jsonb not null default '{}',
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);

create table if not exists public."Location" (
  "id" text primary key default gen_random_uuid()::text,
  "name" text not null,
  "nameLower" text not null,
  "type" text not null default 'city',
  "parentId" text,
  "countryCode" text,
  "displayLabel" text not null,
  "searchTokens" text[] default array[]::text[],
  "isPopular" boolean not null default false,
  "createdAt" timestamptz not null default now()
);
create index if not exists "Location_nameLower_idx" on public."Location"("nameLower");

-- -----------------------------------------------------------------------------
-- 7. Sync auth.users -> profiles + User
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  h text;
  fn text;
  ln text;
  role_name text;
  country_name text;
  display text;
begin
  h := lower(coalesce(new.raw_user_meta_data->>'handle', split_part(new.email, '@', 1)));
  fn := coalesce(new.raw_user_meta_data->>'first_name', '');
  ln := coalesce(new.raw_user_meta_data->>'last_name', '');
  role_name := coalesce(new.raw_user_meta_data->>'role', 'fan');
  country_name := coalesce(new.raw_user_meta_data->>'country', 'Tanzania');
  display := trim(both from (fn || ' ' || ln));
  if display = '' then display := h; end if;

  insert into public.profiles (id, handle, role, first_name, last_name, email, country, dob, bio)
  values (
    new.id,
    h,
    role_name,
    fn,
    ln,
    new.email,
    country_name,
    nullif(new.raw_user_meta_data->>'dob', '')::date,
    coalesce(new.raw_user_meta_data->>'bio', '')
  )
  on conflict (id) do update set
    handle = excluded.handle,
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    email = excluded.email,
    country = excluded.country,
    dob = coalesce(excluded.dob, public.profiles.dob);

  insert into public."User" ("id","name","email","handle","role","bio","location","currentCountry","dateOfBirth","emailVerified","updatedAt")
  values (
    new.id::text,
    display,
    new.email,
    h,
    role_name,
    coalesce(new.raw_user_meta_data->>'bio', ''),
    country_name,
    country_name,
    nullif(new.raw_user_meta_data->>'dob', '')::timestamptz,
    coalesce(new.email_confirmed_at is not null, false),
    now()
  )
  on conflict ("id") do update set
    "name" = excluded."name",
    "email" = excluded."email",
    "handle" = excluded."handle",
    "role" = excluded."role",
    "updatedAt" = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill User from existing profiles
insert into public."User" ("id","name","email","handle","role","bio","location","currentCountry","dateOfBirth","followerCount","followingCount","fanCount","updatedAt")
select
  p.id::text,
  trim(both from (coalesce(p.first_name,'') || ' ' || coalesce(p.last_name,''))),
  coalesce(p.email, p.handle || '@sportsphere.local'),
  p.handle,
  p.role,
  coalesce(p.bio, ''),
  p.country,
  p.country,
  p.dob::timestamptz,
  p.follower_count,
  p.following_count,
  p.fan_count,
  now()
from public.profiles p
on conflict ("id") do nothing;

-- -----------------------------------------------------------------------------
-- 8. RLS
-- -----------------------------------------------------------------------------
alter table public."User" enable row level security;
alter table public."Follow" enable row level security;
alter table public."Post" enable row level security;
alter table public."PostLike" enable row level security;
alter table public."Comment" enable row level security;
alter table public."CommentLike" enable row level security;
alter table public."Poll" enable row level security;
alter table public."PollVote" enable row level security;
alter table public."Community" enable row level security;
alter table public."CommunityMember" enable row level security;
alter table public."Notification" enable row level security;
alter table public."Message" enable row level security;
alter table public."Match" enable row level security;
alter table public."League" enable row level security;
alter table public."Team" enable row level security;
alter table public."Player" enable row level security;
alter table public."Coach" enable row level security;
alter table public."Sport" enable row level security;
alter table public."NewsItem" enable row level security;
alter table public."UserFavorite" enable row level security;
alter table public."Prediction" enable row level security;

-- drop old policies if re-running
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies where schemaname='public'
      and tablename in ('User','Follow','Post','PostLike','Comment','CommentLike','Poll','PollVote','Community','CommunityMember','Notification','Message','Match','League','Team','Player','Coach','Sport','NewsItem','UserFavorite','Prediction')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- User
create policy "user_public_read" on public."User" for select using (true);
create policy "user_own_update" on public."User" for update using (auth.uid()::text = "id");
create policy "user_own_insert" on public."User" for insert with check (auth.uid()::text = "id");

-- Post
create policy "post_public_read" on public."Post" for select using (true);
create policy "post_auth_create" on public."Post" for insert with check (auth.uid()::text = "userId");
create policy "post_own_update" on public."Post" for update using (auth.uid()::text = "userId");
create policy "post_own_delete" on public."Post" for delete using (auth.uid()::text = "userId");

-- Follow
create policy "follow_public_read" on public."Follow" for select using (true);
create policy "follow_auth_create" on public."Follow" for insert with check (auth.uid()::text = "followerId");
create policy "follow_own_delete" on public."Follow" for delete using (auth.uid()::text = "followerId");

-- Comment
create policy "comment_public_read" on public."Comment" for select using (true);
create policy "comment_auth_create" on public."Comment" for insert with check (auth.uid()::text = "userId");
create policy "comment_own_delete" on public."Comment" for delete using (auth.uid()::text = "userId");

-- PostLike
create policy "post_like_public_read" on public."PostLike" for select using (true);
create policy "post_like_auth_create" on public."PostLike" for insert with check (auth.uid()::text = "userId");
create policy "post_like_own_delete" on public."PostLike" for delete using (auth.uid()::text = "userId");

-- CommentLike
create policy "comment_like_public_read" on public."CommentLike" for select using (true);
create policy "comment_like_auth_create" on public."CommentLike" for insert with check (auth.uid()::text = "userId");
create policy "comment_like_own_delete" on public."CommentLike" for delete using (auth.uid()::text = "userId");

-- Poll / vote
create policy "poll_public_read" on public."Poll" for select using (true);
create policy "poll_auth_create" on public."Poll" for insert with check (auth.uid() is not null);
create policy "poll_vote_public_read" on public."PollVote" for select using (true);
create policy "poll_vote_auth_create" on public."PollVote" for insert with check (auth.uid()::text = "userId");

-- Community
create policy "community_public_read" on public."Community" for select using (true);
create policy "community_auth_create" on public."Community" for insert with check (auth.uid() is not null);
create policy "cm_public_read" on public."CommunityMember" for select using (true);
create policy "cm_auth_join" on public."CommunityMember" for insert with check (auth.uid()::text = "userId");
create policy "cm_own_leave" on public."CommunityMember" for delete using (auth.uid()::text = "userId");

-- Message / Notification
create policy "message_own_read" on public."Message" for select using (auth.uid()::text = "senderId" or auth.uid()::text = "receiverId");
create policy "message_auth_send" on public."Message" for insert with check (auth.uid()::text = "senderId");
create policy "notif_own_read" on public."Notification" for select using (auth.uid()::text = "userId");
create policy "notif_own_update" on public."Notification" for update using (auth.uid()::text = "userId");

-- Public sports data
create policy "match_public" on public."Match" for select using (true);
create policy "league_public" on public."League" for select using (true);
create policy "team_public" on public."Team" for select using (true);
create policy "player_public" on public."Player" for select using (true);
create policy "coach_public" on public."Coach" for select using (true);
create policy "sport_public" on public."Sport" for select using (true);
create policy "news_public" on public."NewsItem" for select using (true);

-- Favorites / predictions
create policy "fav_own_read" on public."UserFavorite" for select using (auth.uid()::text = "userId");
create policy "fav_auth_create" on public."UserFavorite" for insert with check (auth.uid()::text = "userId");
create policy "fav_own_delete" on public."UserFavorite" for delete using (auth.uid()::text = "userId");
create policy "pred_public_read" on public."Prediction" for select using (true);
create policy "pred_own_create" on public."Prediction" for insert with check (auth.uid()::text = "userId");

-- Keep existing Flutter table RLS (profiles etc already enabled)

-- -----------------------------------------------------------------------------
-- 9. Storage buckets
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif']),
  ('covers',  'covers',  true, 10485760, array['image/jpeg','image/png','image/webp']),
  ('posts',   'posts',   true, 52428800, array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']),
  ('media',   'media',   true, 52428800, null)
on conflict (id) do update set public = excluded.public;

drop policy if exists "public_read_all" on storage.objects;
drop policy if exists "service_role_all" on storage.objects;
drop policy if exists "auth_upload_own" on storage.objects;

create policy "public_read_all" on storage.objects
  for select using (bucket_id in ('avatars','covers','posts','media'));

create policy "auth_upload_own" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('avatars','covers','posts','media'));

create policy "auth_update_own" on storage.objects
  for update to authenticated
  using (auth.uid()::text = owner_id)
  with check (bucket_id in ('avatars','covers','posts','media'));

-- -----------------------------------------------------------------------------
-- 10. Seed sports + communities if empty
-- -----------------------------------------------------------------------------
insert into public."Sport" ("id","name","slug","icon","category","displayOrder")
values
  ('sport-football', 'Football', 'football', '⚽', 'team', 1),
  ('sport-basketball', 'Basketball', 'basketball', '🏀', 'team', 2),
  ('sport-athletics', 'Athletics', 'athletics', '🏃', 'individual', 3)
on conflict ("id") do nothing;

insert into public."Community" ("id","name","description","topic","memberCount")
select gen_random_uuid()::text, c.name, c.description, c.topic, c.member_count
from public.communities c
where not exists (select 1 from public."Community" x where x."name" = c.name);

insert into public."Role" ("id","name","slug","description","displayOrder") values
  ('role-fan','Fan','fan','Sports fan',1),
  ('role-player','Player','player','Athlete',2),
  ('role-team','Team','team','Club / team',3),
  ('role-coach','Coach','coach','Coach / manager',4)
on conflict ("id") do nothing;
