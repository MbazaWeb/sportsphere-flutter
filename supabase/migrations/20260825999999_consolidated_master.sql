-- =============================================================================
-- SportSphere — Master Consolidated Migration
-- Source: 40 migration files, 3 batches (2026-08-19 → 2026-08-25)
-- Idempotent: every statement uses IF NOT EXISTS / ON CONFLICT / DROP IF EXISTS
-- Order: extensions → enums → core tables → indexes → triggers → RPCs → RLS → seeds
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ENUM TYPES
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  create type "FavoriteTargetType" as enum (
    'TEAM','PLAYER','COACH','COMPETITION','LEAGUE','NATIONAL_TEAM','STADIUM','SPORT'
  );
exception when duplicate_object then null; end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CORE TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- profiles (snake_case — Supabase auth bridge, uuid PK = auth.users.id)
create table if not exists public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  handle            text not null unique,
  role              text not null default 'fan',
  first_name        text not null default '',
  last_name         text not null default '',
  email             text,
  country           text default 'Tanzania',
  avatar_url        text,
  cover_url         text,
  bio               text,
  about_me          text,
  website           text,
  phone             text,
  dob               date,
  is_verified       boolean not null default false,
  is_pro            boolean not null default false,
  post_count        int not null default 0,
  follower_count    int not null default 0,
  following_count   int not null default 0,
  fan_count         int not null default 0,
  theme_color       text default '#168CFF',
  latitude          double precision,
  longitude         double precision,
  location_updated_at timestamptz,
  claim_status      text not null default 'unclaimed',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists profiles_handle_idx on public.profiles(handle);
create index if not exists profiles_location_idx on public.profiles(latitude, longitude)
  where latitude is not null and longitude is not null;

-- User (PascalCase — Prisma-compatible, text PK = auth.users.id::text)
create table if not exists public."User" (
  "id"                text primary key,
  "name"              text not null default '',
  "email"             text not null,
  "handle"            text not null,
  "passwordHash"      text,
  "avatarUrl"         text,
  "avatarInitials"    text,
  "role"              text not null default 'fan',
  "verificationStatus" text not null default 'none',
  "isVerified"        boolean not null default false,
  "bio"               text,
  "location"          text,
  "coverGradient"     text not null default 'from-emerald-600 to-emerald-900',
  "coverUrl"          text,
  "aboutMe"           text,
  "website"           text,
  "phone"             text,
  "gender"            text,
  "nationality"       text,
  "countryOfOrigin"   text,
  "currentCountry"    text,
  "dateOfBirth"       timestamptz,
  "followerCount"     integer not null default 0,
  "followingCount"    integer not null default 0,
  "fanCount"          integer not null default 0,
  "postCount"         integer not null default 0,
  "roleData"          jsonb not null default '{}',
  "sportsFollowing"   jsonb not null default '[]',
  "interests"         jsonb not null default '[]',
  "roleProfile"       jsonb not null default '{}',
  "preferences"       jsonb not null default '{}',
  "privacySettings"   jsonb not null default '{}',
  "notifPrefs"        jsonb not null default '{}',
  "isPro"             boolean not null default false,
  "isBanned"          boolean not null default false,
  "bannedAt"          timestamptz,
  "bannedReason"      text,
  "emailVerified"     boolean not null default false,
  "registeredAt"      timestamptz not null default now(),
  "updatedAt"         timestamptz not null default now(),
  "lastSeenAt"        timestamptz not null default now()
);
create unique index if not exists "User_email_key"   on public."User"("email");
create unique index if not exists "User_handle_key"  on public."User"("handle");
create index if not exists "User_handle_idx"         on public."User"("handle");
create index if not exists "User_role_idx"           on public."User"("role");

-- Social graph (PascalCase)
create table if not exists public."Follow" (
  "followerId"  text not null references public."User"("id") on delete cascade,
  "followingId" text not null references public."User"("id") on delete cascade,
  "createdAt"   timestamptz not null default now(),
  primary key ("followerId", "followingId")
);
create index if not exists "Follow_followerId_idx"  on public."Follow"("followerId");
create index if not exists "Follow_followingId_idx" on public."Follow"("followingId");

-- Self-follow check on PascalCase table
do $$ begin
  if not exists (select 1 from information_schema.table_constraints
                 where constraint_name = 'Follow_no_self_follow_check') then
    delete from public."Follow" where "followerId" = "followingId";
    alter table public."Follow"
      add constraint "Follow_no_self_follow_check"
      check ("followerId" <> "followingId");
  end if;
end $$;

-- fans (snake_case — become a fan of a team/player)
create table if not exists public.fans (
  fan_id    uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (fan_id, target_id),
  check (fan_id <> target_id)
);
alter table public.fans replica identity full;

-- Post (PascalCase)
create table if not exists public."Post" (
  "id"           text primary key default gen_random_uuid()::text,
  "userId"       text not null references public."User"("id") on delete cascade,
  "content"      text not null default '',
  "postType"     text not null default 'post',
  "mediaUrls"    jsonb not null default '[]',
  "hashtags"     jsonb not null default '[]',
  "teamTag"      text,
  "playerTag"    text,
  "communityId"  text,
  "sportTag"     text,
  "matchId"      text,
  "isBreaking"   boolean not null default false,
  "likeCount"    integer not null default 0,
  "commentCount" integer not null default 0,
  "shareCount"   integer not null default 0,
  "viewCount"    integer not null default 0,
  "createdAt"    timestamptz not null default now(),
  "updatedAt"    timestamptz not null default now()
);
create index if not exists "Post_userId_idx"     on public."Post"("userId");
create index if not exists "Post_createdAt_idx"  on public."Post"("createdAt" desc);
create index if not exists "Post_communityId_idx" on public."Post"("communityId") where "communityId" is not null;
create index if not exists "Post_matchId_idx"    on public."Post"("matchId") where "matchId" is not null;
alter table public."Post" replica identity full;

create table if not exists public."PostLike" (
  "postId"    text not null references public."Post"("id") on delete cascade,
  "userId"    text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("postId", "userId")
);
alter table public."PostLike" replica identity full;

create table if not exists public."PostShare" (
  "postId"    text not null references public."Post"("id") on delete cascade,
  "userId"    text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("postId", "userId")
);
create index if not exists "PostShare_userId_idx" on public."PostShare"("userId");

create table if not exists public."Comment" (
  "id"               text primary key default gen_random_uuid()::text,
  "postId"           text not null references public."Post"("id") on delete cascade,
  "userId"           text not null references public."User"("id") on delete cascade,
  "content"          text not null,
  "parentId"         text,
  "mentionedUserIds" jsonb not null default '[]',
  "mediaUrls"        jsonb not null default '[]',
  "mediaType"        text,
  "likeCount"        integer not null default 0,
  "createdAt"        timestamptz not null default now()
);
create index if not exists "Comment_postId_idx"  on public."Comment"("postId");
create index if not exists "Comment_userId_idx"  on public."Comment"("userId");
create index if not exists "Comment_parentId_idx" on public."Comment"("parentId");
alter table public."Comment" replica identity full;

create table if not exists public."CommentLike" (
  "commentId" text not null references public."Comment"("id") on delete cascade,
  "userId"    text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("commentId", "userId")
);

create table if not exists public."Poll" (
  "id"         text primary key default gen_random_uuid()::text,
  "postId"     text not null unique references public."Post"("id") on delete cascade,
  "matchId"    text,
  "question"   text not null,
  "options"    jsonb not null default '[]',
  "totalVotes" integer not null default 0,
  "endsAt"     timestamptz,
  "createdAt"  timestamptz not null default now()
);
create index if not exists "Poll_matchId_idx" on public."Poll"("matchId") where "matchId" is not null;

create table if not exists public."PollVote" (
  "id"          text primary key default gen_random_uuid()::text,
  "pollId"      text not null references public."Poll"("id") on delete cascade,
  "userId"      text not null references public."User"("id") on delete cascade,
  "optionIndex" integer not null,
  "createdAt"   timestamptz not null default now(),
  unique ("pollId", "userId")
);

-- Community (PascalCase)
create table if not exists public."Community" (
  "id"          text primary key default gen_random_uuid()::text,
  "name"        text not null,
  "description" text,
  "topic"       text,
  "teamId"      text,
  "memberCount" integer not null default 0,
  "createdById" text references public."User"("id") on delete set null,
  "createdAt"   timestamptz not null default now()
);
create index if not exists "Community_createdById_idx" on public."Community"("createdById");

create table if not exists public."CommunityMember" (
  "communityId" text not null references public."Community"("id") on delete cascade,
  "userId"      text not null references public."User"("id") on delete cascade,
  "role"        text not null default 'member',
  "joinedAt"    timestamptz not null default now(),
  primary key ("communityId", "userId")
);

-- Notification / Message
create table if not exists public."Notification" (
  "id"          text primary key default gen_random_uuid()::text,
  "userId"      text not null references public."User"("id") on delete cascade,
  "type"        text not null,
  "title"       text not null,
  "body"        text,
  "isRead"      boolean not null default false,
  "actorId"     text references public."User"("id") on delete set null,
  "referenceId" text,
  "targetId"    text,
  "targetType"  text,
  "createdAt"   timestamptz not null default now()
);
create index if not exists "Notification_userId_idx" on public."Notification"("userId", "isRead", "createdAt" desc);
create index if not exists "Notification_actorId_idx" on public."Notification"("actorId") where "actorId" is not null;
alter table public."Notification" replica identity full;

create table if not exists public."Message" (
  "id"         text primary key default gen_random_uuid()::text,
  "senderId"   text not null references public."User"("id") on delete cascade,
  "receiverId" text not null references public."User"("id") on delete cascade,
  "content"    text not null,
  "isRead"     boolean not null default false,
  "createdAt"  timestamptz not null default now()
);
create index if not exists "Message_senderId_idx"   on public."Message"("senderId");
create index if not exists "Message_receiverId_idx" on public."Message"("receiverId");
alter table public."Message" replica identity full;

create table if not exists public.device_tokens (
  id         bigserial primary key,
  user_id    text not null references public."User"("id") on delete cascade,
  token      text not null,
  platform   text,
  updated_at timestamptz not null default now(),
  unique(user_id, token)
);

-- Role / Sport taxonomy
create table if not exists public."Role" (
  "id"           text primary key,
  "name"         text not null unique,
  "slug"         text not null unique,
  "description"  text not null default '',
  "icon"         text not null default '👤',
  "category"     text not null default 'individual',
  "displayOrder" integer not null default 0,
  "isActive"     boolean not null default true,
  "createdAt"    timestamptz not null default now(),
  "updatedAt"    timestamptz not null default now()
);

create table if not exists public."RoleType" (
  "id"           text primary key,
  "roleId"       text not null references public."Role"("id") on delete cascade,
  "name"         text not null,
  "slug"         text not null,
  "description"  text,
  "requirements" jsonb not null default '[]',
  "displayOrder" integer not null default 0,
  "isActive"     boolean not null default true,
  "createdAt"    timestamptz not null default now(),
  "updatedAt"    timestamptz not null default now(),
  unique ("roleId", "slug")
);

create table if not exists public."Sport" (
  "id"           text primary key,
  "name"         text not null unique,
  "slug"         text not null unique,
  "sportSlug"    text,
  "parentSportSlug" text,
  "icon"         text,
  "category"     text,
  "description"  text,
  "tags"         jsonb not null default '[]',
  "isActive"     boolean not null default true,
  "displayOrder" integer not null default 0,
  "createdAt"    timestamptz not null default now(),
  "updatedAt"    timestamptz not null default now()
);

create table if not exists public."UserSport" (
  "id"        text primary key default gen_random_uuid()::text,
  "userId"    text not null references public."User"("id") on delete cascade,
  "sportId"   text not null references public."Sport"("id") on delete cascade,
  "isPrimary" boolean not null default false,
  "weight"    integer not null default 1,
  "createdAt" timestamptz not null default now(),
  unique ("userId", "sportId")
);

create table if not exists public."UserFavorite" (
  "id"           text primary key default gen_random_uuid()::text,
  "userId"       text not null references public."User"("id") on delete cascade,
  "targetType"   "FavoriteTargetType" not null,
  "targetId"     text not null,
  "targetName"   text not null,
  "targetHandle" text,
  "createdAt"    timestamptz not null default now(),
  unique ("userId", "targetType", "targetId")
);

create table if not exists public.taxonomy_term (
  domain     text not null,
  slug       text not null,
  label      text not null,
  parent_slug text,
  sort_order  int not null default 0,
  primary key (domain, slug)
);
create index if not exists taxonomy_term_domain_idx on public.taxonomy_term(domain);

-- Sports data layer
create table if not exists public."League" (
  "id"               text primary key default gen_random_uuid()::text,
  "sportId"          text references public."Sport"("id") on delete set null,
  "accountUserId"    text unique,
  "isClaimable"      boolean not null default true,
  "identityStatus"   text not null default 'pending',
  "claimStatus"      text not null default 'unclaimed',
  "name"             text not null,
  "slug"             text not null unique,
  "country"          text,
  "countryCode"      text,
  "logoUrl"          text,
  "type"             text not null default 'league',
  "division"         text,
  "season"           text,
  "externalId"       text,
  "source"           text default 'admin',
  "verified"         boolean not null default false,
  "isActive"         boolean not null default true,
  "description"      text,
  "metadata"         jsonb not null default '{}',
  "competitiveLevel" text,
  "gender"           text,
  "ageCategory"      text,
  "geographicScope"  text,
  "competitionType"  text,
  "competitionFormat" text,
  "competitionLevel" text,
  "sportSlug"        text,
  "createdAt"        timestamptz not null default now(),
  "updatedAt"        timestamptz not null default now()
);
create index if not exists "League_sportId_idx" on public."League"("sportId") where "sportId" is not null;

create table if not exists public."Team" (
  "id"               text primary key default gen_random_uuid()::text,
  "leagueId"         text references public."League"("id") on delete set null,
  "sportId"          text references public."Sport"("id") on delete set null,
  "accountUserId"    uuid unique references auth.users(id) on delete set null,
  "isClaimable"      boolean not null default true,
  "identityStatus"   text not null default 'pending',
  "claimStatus"      text not null default 'unclaimed',
  "name"             text not null,
  "slug"             text not null unique,
  "shortName"        text,
  "city"             text,
  "country"          text,
  "logoUrl"          text,
  "primaryColor"     text default '#168CFF',
  "venue"            text,
  "foundedYear"      integer,
  "source"           text default 'admin',
  "verified"         boolean not null default false,
  "isActive"         boolean not null default true,
  "description"      text,
  "metadata"         jsonb not null default '{}',
  "competitiveLevel" text,
  "organizationType" text,
  "gender"           text,
  "ageCategory"      text,
  "geographicScope"  text,
  "sportSlug"        text,
  "sportVariant"     text,
  "createdAt"        timestamptz not null default now(),
  "updatedAt"        timestamptz not null default now()
);
create index if not exists "Team_leagueId_idx" on public."Team"("leagueId") where "leagueId" is not null;
create index if not exists "Team_sportId_idx"  on public."Team"("sportId")  where "sportId"  is not null;

create table if not exists public."Player" (
  "id"              text primary key default gen_random_uuid()::text,
  "teamId"          text references public."Team"("id") on delete set null,
  "leagueId"        text references public."League"("id") on delete set null,
  "sportId"         text references public."Sport"("id") on delete set null,
  "accountUserId"   uuid unique references auth.users(id) on delete set null,
  "authUserId"      text,
  "isClaimable"     boolean not null default true,
  "identityStatus"  text not null default 'pending',
  "claimStatus"     text not null default 'unclaimed',
  "name"            text not null,
  "slug"            text not null unique,
  "firstName"       text,
  "lastName"        text,
  "position"        text,
  "nationality"     text,
  "photoUrl"        text,
  "dateOfBirth"     timestamptz,
  "heightCm"        integer,
  "weightKg"        integer,
  "shirtNumber"     integer,
  "verified"        boolean not null default false,
  "isActive"        boolean not null default true,
  "metadata"        jsonb not null default '{}',
  "playerType"      text,
  "gender"          text,
  "ageCategory"     text,
  "careerLevel"     text,
  "sportSlug"       text,
  "createdAt"       timestamptz not null default now(),
  "updatedAt"       timestamptz not null default now()
);
create index if not exists "Player_teamId_idx"   on public."Player"("teamId")   where "teamId"   is not null;
create index if not exists "Player_leagueId_idx" on public."Player"("leagueId") where "leagueId" is not null;
create index if not exists "Player_sportId_idx"  on public."Player"("sportId")  where "sportId"  is not null;

create table if not exists public."Coach" (
  "id"          text primary key default gen_random_uuid()::text,
  "teamId"      text references public."Team"("id") on delete set null,
  "leagueId"    text references public."League"("id") on delete set null,
  "sportId"     text references public."Sport"("id") on delete set null,
  "name"        text not null,
  "slug"        text not null unique,
  "firstName"   text,
  "lastName"    text,
  "nationality" text,
  "photoUrl"    text,
  "dateOfBirth" timestamptz,
  "role"        text not null default 'head_coach',
  "verified"    boolean not null default false,
  "isActive"    boolean not null default true,
  "metadata"    jsonb not null default '{}',
  "createdAt"   timestamptz not null default now(),
  "updatedAt"   timestamptz not null default now()
);
create index if not exists "Coach_teamId_idx"   on public."Coach"("teamId")   where "teamId"   is not null;
create index if not exists "Coach_leagueId_idx" on public."Coach"("leagueId") where "leagueId" is not null;
create index if not exists "Coach_sportId_idx"  on public."Coach"("sportId")  where "sportId"  is not null;

create table if not exists public."Match" (
  "id"         text primary key default gen_random_uuid()::text,
  "league"     text not null default '',
  "homeTeam"   text not null,
  "awayTeam"   text not null,
  "homeScore"  integer,
  "awayScore"  integer,
  "status"     text not null default 'upcoming',
  "minute"     integer,
  "venue"      text,
  "kickoffAt"  timestamptz not null default now(),
  "events"     jsonb not null default '[]',
  "lineups"    jsonb not null default '{}',
  "stats"      jsonb not null default '[]',
  "homeBadge"  text,
  "awayBadge"  text,
  "season"     text,
  "externalId" text,
  "continent"  text default 'Africa',
  "country"    text default 'Tanzania',
  "createdAt"  timestamptz not null default now(),
  "updatedAt"  timestamptz not null default now()
);
create index if not exists "Match_status_idx"   on public."Match"("status");
create index if not exists "Match_kickoffAt_idx" on public."Match"("kickoffAt");
create index if not exists "Match_league_idx"   on public."Match"("league");
alter table public."Match" replica identity full;

create table if not exists public."Competition" (
  "id"                text primary key,
  "name"              text not null,
  "slug"              text unique,
  "sportSlug"         text default 'football',
  "sportVariant"      text,
  "competitionType"   text default 'tournament',
  "competitionFormat" text default 'group_stage',
  "competitionLevel"  text default 'national',
  "gender"            text default 'men',
  "ageCategory"       text default 'senior',
  "geographicScope"   text default 'national',
  "country"           text,
  "season"            text,
  "leagueId"          text,
  "logoUrl"           text,
  "isActive"          boolean default true,
  "createdAt"         timestamptz default now(),
  "updatedAt"         timestamptz default now()
);

create table if not exists public."Venue" (
  "id"       uuid primary key default gen_random_uuid(),
  "name"     text not null,
  "city"     text,
  "country"  text default 'Tanzania',
  "capacity" integer,
  "createdAt" timestamptz default now(),
  unique("name", "city")
);

create table if not exists public."PlayerMatchStat" (
  "id"          text primary key default gen_random_uuid()::text,
  "playerId"    text not null references public."Player"("id") on delete cascade,
  "matchId"     text references public."Match"("id") on delete set null,
  "season"      text not null default '2026/2027',
  "competition" text,
  "played"      boolean not null default true,
  "minutes"     integer not null default 0,
  "goals"       integer not null default 0,
  "assists"     integer not null default 0,
  "saves"       integer not null default 0,
  "yellowCards" integer not null default 0,
  "redCards"    integer not null default 0,
  "createdAt"   timestamptz not null default now(),
  "updatedAt"   timestamptz not null default now()
);
create index if not exists "PlayerMatchStat_player_idx" on public."PlayerMatchStat"("playerId");
create index if not exists "PlayerMatchStat_matchId_idx" on public."PlayerMatchStat"("matchId") where "matchId" is not null;

create table if not exists public."Prediction" (
  "id"            text primary key default gen_random_uuid()::text,
  "userId"        text not null references public."User"("id") on delete cascade,
  "matchId"       text references public."Match"("id") on delete set null,
  "postId"        text unique,
  "homeTeam"      text not null,
  "awayTeam"      text not null,
  "predictedHome" integer,
  "predictedAway" integer,
  "outcome"       text,          -- home|draw|away
  "confidence"    text,
  "result"        text,
  "isCorrect"     boolean,
  "closedAt"      timestamptz,   -- non-null = locked (match ended)
  "pointsEarned"  integer not null default 0,
  "createdAt"     timestamptz not null default now()
);
create index if not exists "Prediction_userId_idx"  on public."Prediction"("userId");
create index if not exists "Prediction_matchId_idx" on public."Prediction"("matchId") where "matchId" is not null;

create table if not exists public."NewsItem" (
  "id"           text primary key default gen_random_uuid()::text,
  "title"        text not null,
  "slug"         text not null unique,
  "body"         text not null default '',
  "summary"      text,
  "imageUrl"     text,
  "category"     text not null default 'general',
  "tags"         jsonb not null default '[]',
  "sportId"      text references public."Sport"("id") on delete set null,
  "status"       text not null default 'draft',
  "source"       text,
  "sourceUrl"    text,
  "isBreaking"   boolean not null default false,
  "likeCount"    integer not null default 0,
  "commentCount" integer not null default 0,
  "shareCount"   integer not null default 0,
  "viewCount"    integer not null default 0,
  "publishedAt"  timestamptz,
  "createdAt"    timestamptz not null default now(),
  "updatedAt"    timestamptz not null default now()
);

create table if not exists public.news_likes (
  news_id    text not null,
  user_id    text not null,
  created_at timestamptz default now(),
  primary key (news_id, user_id)
);
create table if not exists public.news_comments (
  id         text primary key default gen_random_uuid()::text,
  news_id    text not null,
  user_id    text not null,
  content    text not null,
  created_at timestamptz default now()
);
create index if not exists "news_comments_user_id_idx" on public.news_comments(user_id);
create index if not exists "news_comments_news_id_idx" on public.news_comments(news_id);

-- FK constraints on news tables
do $$ begin
  if not exists (select 1 from information_schema.table_constraints where constraint_name='news_likes_news_id_fkey') then
    alter table public.news_likes add constraint news_likes_news_id_fkey foreign key (news_id) references public."NewsItem"("id") on delete cascade;
    alter table public.news_likes add constraint news_likes_user_id_fkey foreign key (user_id) references public."User"("id") on delete cascade;
    alter table public.news_comments add constraint news_comments_news_id_fkey foreign key (news_id) references public."NewsItem"("id") on delete cascade;
    alter table public.news_comments add constraint news_comments_user_id_fkey foreign key (user_id) references public."User"("id") on delete cascade;
  end if;
end $$;

create table if not exists public."ShopOrder" (
  "id"            text primary key default gen_random_uuid()::text,
  "userId"        text not null references public."User"("id") on delete cascade,
  "sellerHandle"  text,
  "sellerName"    text,
  "itemId"        text not null,
  "itemName"      text not null,
  "kind"          text not null default 'ticket',
  "quantity"      integer not null default 1,
  "unitPriceTzs"  integer not null default 0,
  "amountTzs"     integer not null default 0,
  "status"        text not null default 'paid',
  "paymentMethod" text,
  "paymentRef"    text,
  "createdAt"     timestamptz not null default now(),
  "updatedAt"     timestamptz not null default now()
);
create index if not exists "ShopOrder_user_idx"   on public."ShopOrder"("userId");
create index if not exists "ShopOrder_seller_idx" on public."ShopOrder"("sellerHandle");

create table if not exists public."ClaimRequest" (
  "id"            text primary key default gen_random_uuid()::text,
  "userId"        text not null references public."User"("id") on delete cascade,
  "profileType"   text not null,
  "profileId"     text not null,
  "profileName"   text not null,
  "leagueId"      text,
  "teamId"        text,
  "playerId"      text,
  "coachId"       text,
  "claimEmail"    text,
  "claimPhone"    text,
  "evidenceNotes" text,
  "evidenceUrls"  jsonb not null default '[]',
  "status"        text not null default 'pending',
  "reviewerId"    text,
  "reviewNotes"   text,
  "submittedAt"   timestamptz not null default now(),
  "reviewedAt"    timestamptz
);
create index if not exists "ClaimRequest_userId_idx"   on public."ClaimRequest"("userId");
create index if not exists "ClaimRequest_status_idx"   on public."ClaimRequest"("status");
create index if not exists "ClaimRequest_teamId_idx"   on public."ClaimRequest"("teamId")   where "teamId"   is not null;
create index if not exists "ClaimRequest_playerId_idx" on public."ClaimRequest"("playerId") where "playerId" is not null;
create index if not exists "ClaimRequest_coachId_idx"  on public."ClaimRequest"("coachId")  where "coachId"  is not null;

do $$ begin
  if not exists (select 1 from information_schema.table_constraints where constraint_name='claim_request_league_fkey') then
    alter table public."ClaimRequest" add constraint claim_request_league_fkey foreign key ("leagueId") references public."League"("id") on delete set null;
    alter table public."ClaimRequest" add constraint claim_request_team_fkey   foreign key ("teamId")   references public."Team"("id")   on delete set null;
    alter table public."ClaimRequest" add constraint claim_request_player_fkey foreign key ("playerId") references public."Player"("id") on delete set null;
    alter table public."ClaimRequest" add constraint claim_request_coach_fkey  foreign key ("coachId")  references public."Coach"("id")  on delete set null;
  end if;
end $$;

create table if not exists public."VerificationRequest" (
  "id"          text primary key default gen_random_uuid()::text,
  "userId"      text not null references public."User"("id") on delete cascade,
  "role"        text not null,
  "roleData"    jsonb not null default '{}',
  "roleId"      text,
  "roleTypeId"  text,
  "status"      text not null default 'pending',
  "adminNotes"  text,
  "reviewedBy"  text,
  "submittedAt" timestamptz not null default now(),
  "reviewedAt"  timestamptz
);
create index if not exists "VerificationRequest_userId_idx" on public."VerificationRequest"("userId");

create table if not exists public."RoleRequest" (
  "id"            text primary key,
  "userId"        uuid not null references auth.users(id) on delete cascade,
  "requestedRole" text not null,
  "status"        text not null default 'pending' check ("status" in ('pending','approved','rejected')),
  "notes"         text,
  "createdAt"     timestamptz not null default now(),
  "reviewedAt"    timestamptz,
  unique ("userId", "requestedRole", "status")
);

-- Typed role profiles (all 23)
create table if not exists public."PlayerProfile" ("userId" text primary key references public."User"("id") on delete cascade, "position" text, "secondaryPosition" text, "preferredFoot" text, "jerseyNumber" text, "height" double precision, "weight" double precision, "dateOfBirth" timestamptz, "nationality" text, "playerType" text, "careerStatus" text, "appearances" double precision, "goals" double precision, "assists" double precision, "currentClub" text, "contractUntil" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."TeamProfile" ("userId" text primary key references public."User"("id") on delete cascade, "nickname" text, "foundedYear" text, "country" text, "city" text, "stadium" text, "capacity" double precision, "league" text, "coach" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."CoachProfile" ("userId" text primary key references public."User"("id") on delete cascade, "coachingRole" text, "currentTeam" text, "license" text, "nationality" text, "yearsCoaching" double precision, "matchesManaged" double precision, "wins" double precision, "preferredFormation" text, "playingPhilosophy" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."ScoutProfile" ("userId" text primary key references public."User"("id") on delete cascade, "scoutType" text, "organization" text, "geographicCoverage" text, "sportsCovered" text[], "yearsExperience" double precision, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."AgentProfile" ("userId" text primary key references public."User"("id") on delete cascade, "agentType" text, "agency" text, "license" text, "federation" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."AnalystProfile" ("userId" text primary key references public."User"("id") on delete cascade, "analystType" text, "organization" text, "expertise" text[], "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."JournalistProfile" ("userId" text primary key references public."User"("id") on delete cascade, "publication" text, "beat" text, "location" text, "yearsActive" double precision, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."CreatorProfile" ("userId" text primary key references public."User"("id") on delete cascade, "creatorType" text, "platforms" text[], "niche" text, "followers" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."CommentatorProfile" ("userId" text primary key references public."User"("id") on delete cascade, "commentatorType" text, "broadcaster" text, "languages" text[], "sports" text[], "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."OfficialProfile" ("userId" text primary key references public."User"("id") on delete cascade, "officialType" text, "federation" text, "license" text, "yearsActive" double precision, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."ModeratorProfile" ("userId" text primary key references public."User"("id") on delete cascade, "scope" text, "communities" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."SupportStaffProfile" ("userId" text primary key references public."User"("id") on delete cascade, "staffRole" text, "organization" text, "specialty" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."SponsorProfile" ("userId" text primary key references public."User"("id") on delete cascade, "brand" text, "industry" text, "website" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."MediaBroadcastProfile" ("userId" text primary key references public."User"("id") on delete cascade, "outlet" text, "platform" text, "coverage" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."OrganizationProfile" ("userId" text primary key references public."User"("id") on delete cascade, "orgType" text, "country" text, "headquarters" text, "foundedYear" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."LeagueProfile" ("userId" text primary key references public."User"("id") on delete cascade, "leagueName" text, "country" text, "division" text, "currentSeason" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."CompetitionProfile" ("userId" text primary key references public."User"("id") on delete cascade, "competitionName" text, "season" text, "organizer" text, "country" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."AcademyProfile" ("userId" text primary key references public."User"("id") on delete cascade, "academyName" text, "parentOrg" text, "location" text, "foundedYear" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."VenueProfile" ("userId" text primary key references public."User"("id") on delete cascade, "venueName" text, "venueType" text, "location" text, "capacity" double precision, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."BusinessProfile" ("userId" text primary key references public."User"("id") on delete cascade, "companyName" text, "industry" text, "headquarters" text, "website" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."CommercialPartnerProfile" ("userId" text primary key references public."User"("id") on delete cascade, "partnerType" text, "brand" text, "sportsCategory" text, "website" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());
create table if not exists public."CommunityProfile" ("userId" text primary key references public."User"("id") on delete cascade, "communityName" text, "communityType" text, "location" text, "supportedTeam" text, "memberCount" double precision, "description" text, "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now());

create table if not exists public."CommercialPartner" (
  "id" text primary key default gen_random_uuid()::text, "name" text not null, "slug" text not null unique, "partnerType" text not null default 'brand', "industry" text, "website" text, "logoUrl" text, "country" text, "description" text, "status" text not null default 'pending', "tier" text not null default 'bronze', "isActive" boolean not null default true, "metadata" jsonb not null default '{}', "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

create table if not exists public."Location" (
  "id" text primary key default gen_random_uuid()::text, "name" text not null, "nameLower" text not null, "type" text not null default 'city', "parentId" text, "countryCode" text, "displayLabel" text not null, "searchTokens" text[] default array[]::text[], "isPopular" boolean not null default false, "createdAt" timestamptz not null default now()
);
create index if not exists "Location_nameLower_idx" on public."Location"("nameLower");

-- Entity identity tables
create table if not exists public.entity_follows (
  id          uuid primary key default gen_random_uuid(),
  follower_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id   text not null,
  account_uid uuid,
  is_fan      boolean not null default false,
  created_at  timestamptz not null default now(),
  unique(follower_id, entity_type, entity_id)
);
create index if not exists entity_follows_entity_idx  on public.entity_follows(entity_type, entity_id);
create index if not exists entity_follows_account_idx on public.entity_follows(account_uid);

create table if not exists public.entity_communities (
  id           uuid primary key default gen_random_uuid(),
  entity_type  text not null default 'team',
  entity_id    text not null unique,
  name         text not null,
  slug         text not null unique,
  description  text,
  member_count int not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.identity_audit (
  id                uuid primary key default gen_random_uuid(),
  entity_type       text not null,
  entity_id         text not null,
  entity_name       text,
  old_auth_user_id  text,
  new_auth_user_id  text,
  action            text not null,
  reason            text,
  created_by        text,
  created_at        timestamptz not null default now()
);
create index if not exists idx_identity_audit_entity     on public.identity_audit(entity_type, entity_id);
create index if not exists idx_identity_audit_created_at on public.identity_audit(created_at desc);

-- FK constraints for Post/Community/Prediction
do $$ begin
  if not exists (select 1 from information_schema.table_constraints where constraint_name='Post_community_fkey') then
    alter table public."Post" add constraint "Post_community_fkey" foreign key ("communityId") references public."Community"("id") on delete set null;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name='Post_match_fkey') then
    alter table public."Post" add constraint "Post_match_fkey" foreign key ("matchId") references public."Match"("id") on delete set null;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name='Poll_match_fkey') then
    alter table public."Poll" add constraint "Poll_match_fkey" foreign key ("matchId") references public."Match"("id") on delete set null;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name='Prediction_post_fkey') then
    alter table public."Prediction" add constraint "Prediction_post_fkey" foreign key ("postId") references public."Post"("id") on delete cascade;
  end if;
  if not exists (select 1 from information_schema.table_constraints where constraint_name='Community_teamId_unique') then
    alter table public."Community" add constraint "Community_teamId_unique" unique ("teamId");
    alter table public."Community" add constraint "Community_team_fkey" foreign key ("teamId") references public."Team"(id) on delete set null;
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. STORAGE BUCKETS
-- ─────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars','avatars',true,10485760,array['image/jpeg','image/png','image/webp','image/gif']),
  ('covers', 'covers', true,10485760,array['image/jpeg','image/png','image/webp']),
  ('posts',  'posts',  true,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','application/pdf']),
  ('media',  'media',  true,104857600,null)   -- 100 MB, all types (bumped batch 3)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public_read_all"  on storage.objects;
drop policy if exists "auth_upload_own"  on storage.objects;
drop policy if exists "auth_update_own"  on storage.objects;
create policy "public_read_all"  on storage.objects for select using (bucket_id in ('avatars','covers','posts','media'));
create policy "auth_upload_own"  on storage.objects for insert to authenticated with check (bucket_id in ('avatars','covers','posts','media'));
create policy "auth_update_own"  on storage.objects for update to authenticated using (auth.uid()::text = owner_id) with check (bucket_id in ('avatars','covers','posts','media'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. FUNCTIONS & TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────

-- is_app_admin (SECURITY FIX: role-only, no handle-squatting)
create or replace function public.is_app_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from public.profiles p where p.id = auth.uid() and lower(coalesce(p.role,'')) in ('admin','official','organization','moderator'))
    or exists (select 1 from public."User" u where u.id = auth.uid()::text and lower(coalesce(u.role,'')) in ('admin','official','organization','moderator'))
  );
$$;
grant execute on function public.is_app_admin() to authenticated, anon, service_role;

-- handle_new_user trigger (deduplicates handles, never fails signUp)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  h text; fn text; ln text; role_v text; country_v text; display text;
  suffix int := 0; h_try text;
begin
  fn := trim(coalesce(new.raw_user_meta_data->>'first_name',''));
  ln := trim(coalesce(new.raw_user_meta_data->>'last_name',''));
  role_v := coalesce(new.raw_user_meta_data->>'role','fan');
  country_v := coalesce(new.raw_user_meta_data->>'country','Tanzania');
  h := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'handle', split_part(new.email,'@',1)),'^@+',''));
  h := regexp_replace(h,'[^a-z0-9_]','','g');
  if h = '' then h := split_part(new.email,'@',1); end if;
  display := trim(fn||' '||ln);
  if display = '' then display := h; end if;
  h_try := h;
  loop
    exit when not exists (select 1 from public.profiles where handle = h_try);
    suffix := suffix + 1; h_try := h||suffix::text;
    exit when suffix > 999;
  end loop;
  h := h_try;
  begin
    insert into public.profiles (id,handle,role,first_name,last_name,email,country,dob,bio)
    values (new.id,h,role_v,fn,ln,new.email,country_v,
            nullif(new.raw_user_meta_data->>'dob','')::date,
            coalesce(new.raw_user_meta_data->>'bio',''))
    on conflict (id) do update set handle=excluded.handle,first_name=excluded.first_name,
      last_name=excluded.last_name,email=excluded.email,country=excluded.country,
      dob=coalesce(excluded.dob,profiles.dob),updated_at=now();
  exception when others then
    raise warning '[handle_new_user] profiles insert failed for %: %', new.id, sqlerrm;
  end;
  begin
    insert into public."User" ("id","name","email","handle","role","bio","currentCountry","dateOfBirth","emailVerified","updatedAt")
    values (new.id::text,display,new.email,h,role_v,
            coalesce(new.raw_user_meta_data->>'bio',''),country_v,
            nullif(new.raw_user_meta_data->>'dob','')::timestamptz,
            coalesce(new.email_confirmed_at is not null,false),now())
    on conflict ("id") do update set "name"=excluded."name","email"=excluded."email",
      "handle"=excluded."handle","role"=excluded."role","updatedAt"=now();
  exception when others then
    raise warning '[handle_new_user] User insert failed for %: %', new.id, sqlerrm;
  end;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- cleanup User on auth delete
create or replace function public.cleanup_user_on_auth_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin delete from public."User" where id = old.id::text; return old; end; $$;
drop trigger if exists trg_cleanup_user_on_auth_delete on auth.users;
create trigger trg_cleanup_user_on_auth_delete after delete on auth.users for each row execute function public.cleanup_user_on_auth_delete();

-- Counter triggers (authoritative — no app-level drift possible)
create or replace function public.trg_post_like_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op='INSERT' then update public."Post" set "likeCount"=coalesce("likeCount",0)+1 where id=new."postId"; return new;
  elsif tg_op='DELETE' then update public."Post" set "likeCount"=greatest(coalesce("likeCount",0)-1,0) where id=old."postId"; return old; end if; return null;
end; $$;
drop trigger if exists trg_post_like_count on public."PostLike";
create trigger trg_post_like_count after insert or delete on public."PostLike" for each row execute function public.trg_post_like_count();

create or replace function public.trg_post_comment_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op='INSERT' then update public."Post" set "commentCount"=coalesce("commentCount",0)+1 where id=new."postId"; return new;
  elsif tg_op='DELETE' then update public."Post" set "commentCount"=greatest(coalesce("commentCount",0)-1,0) where id=old."postId"; return old; end if; return null;
end; $$;
drop trigger if exists trg_post_comment_count on public."Comment";
create trigger trg_post_comment_count after insert or delete on public."Comment" for each row execute function public.trg_post_comment_count();

create or replace function public.trg_post_share_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op='INSERT' then update public."Post" set "shareCount"=coalesce("shareCount",0)+1 where id=new."postId"; return new;
  elsif tg_op='DELETE' then update public."Post" set "shareCount"=greatest(coalesce("shareCount",0)-1,0) where id=old."postId"; return old; end if; return null;
end; $$;
drop trigger if exists trg_post_share_count on public."PostShare";
create trigger trg_post_share_count after insert or delete on public."PostShare" for each row execute function public.trg_post_share_count();

create or replace function public.trg_news_like_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op='INSERT' then update public."NewsItem" set "likeCount"=coalesce("likeCount",0)+1 where id=new.news_id; return new;
  elsif tg_op='DELETE' then update public."NewsItem" set "likeCount"=greatest(coalesce("likeCount",0)-1,0) where id=old.news_id; return old; end if; return null;
end; $$;
drop trigger if exists trg_news_like_count on public.news_likes;
create trigger trg_news_like_count after insert or delete on public.news_likes for each row execute function public.trg_news_like_count();

create or replace function public.trg_news_comment_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op='INSERT' then update public."NewsItem" set "commentCount"=coalesce("commentCount",0)+1 where id=new.news_id; return new;
  elsif tg_op='DELETE' then update public."NewsItem" set "commentCount"=greatest(coalesce("commentCount",0)-1,0) where id=old.news_id; return old; end if; return null;
end; $$;
drop trigger if exists trg_news_comment_count on public.news_comments;
create trigger trg_news_comment_count after insert or delete on public.news_comments for each row execute function public.trg_news_comment_count();

-- Notification triggers
create or replace function public.trg_notify_post_like() returns trigger language plpgsql security definer set search_path = public as $$
declare author_id text; begin
  select "userId" into author_id from public."Post" where id=new."postId";
  if author_id is null or author_id=new."userId" then return new; end if;
  perform public.create_notification(author_id,'like','New like','Someone liked your post',new."userId",new."postId",new."postId",'post');
  return new; end; $$;
drop trigger if exists trg_post_like_notify on public."PostLike";
create trigger trg_post_like_notify after insert on public."PostLike" for each row execute function public.trg_notify_post_like();

create or replace function public.trg_notify_post_comment() returns trigger language plpgsql security definer set search_path = public as $$
declare author_id text; snippet text; begin
  select "userId" into author_id from public."Post" where id=new."postId";
  if author_id is null or author_id=new."userId" then return new; end if;
  snippet := left(coalesce(new.content,'New comment'),80);
  perform public.create_notification(author_id,'comment','New comment',snippet,new."userId",new."postId",new.id,'comment');
  return new; end; $$;
drop trigger if exists trg_post_comment_notify on public."Comment";
create trigger trg_post_comment_notify after insert on public."Comment" for each row execute function public.trg_notify_post_comment();

create or replace function public.trg_notify_follow() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new."followerId"=new."followingId" then return new; end if;
  perform public.create_notification(new."followingId",'follow','New follower','Someone started following you',new."followerId",new."followerId",new."followerId",'user');
  return new; end; $$;
drop trigger if exists trg_follow_notify on public."Follow";
create trigger trg_follow_notify after insert on public."Follow" for each row execute function public.trg_notify_follow();

-- Prediction settlement trigger
create or replace function public.settle_match_predictions(p_match_id text) returns void language plpgsql security definer set search_path = public as $$
declare v_home int; v_away int; v_status text; v_result text; begin
  select "homeScore","awayScore",status into v_home,v_away,v_status from public."Match" where id=p_match_id;
  if not found then return; end if;
  if v_status not in ('ft','finished','full time') then return; end if;
  if v_home is null or v_away is null then return; end if;
  v_result := case when v_home>v_away then 'home' when v_home=v_away then 'draw' else 'away' end;
  update public."Prediction" set result=v_result,"isCorrect"=(outcome=v_result),"closedAt"=coalesce("closedAt",now())
    where "matchId"=p_match_id and "closedAt" is null;
end; $$;
grant execute on function public.settle_match_predictions(text) to authenticated, service_role;

create or replace function public.trg_settle_match_predictions() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.status in ('ft','finished','full time'),false) and not coalesce(old.status in ('ft','finished','full time'),false) then
    perform public.settle_match_predictions(new.id);
  end if; return new; end; $$;
drop trigger if exists trg_match_settle_predictions on public."Match";
create trigger trg_match_settle_predictions after update of status on public."Match" for each row execute function public.trg_settle_match_predictions();

-- Team fan community trigger
create or replace function public.create_team_fan_community(p_team_id text) returns void language plpgsql security definer set search_path = public as $$
declare v_name text; v_slug text; v_existing text; begin
  select "name",slug into v_name,v_slug from public."Team" where id=p_team_id;
  if not found then return; end if;
  select id into v_existing from public."Community" where "teamId"=p_team_id;
  if v_existing is not null then return; end if;
  insert into public."Community"(id,name,description,topic,"teamId","createdAt")
  values('comm-team-'||v_slug, v_name||' Fan Community','Official fan community for '||v_name,'team_fan',p_team_id,now())
  on conflict (id) do nothing;
end; $$;
grant execute on function public.create_team_fan_community(text) to authenticated, service_role;

create or replace function public.trg_team_create_fan_community() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.create_team_fan_community(new.id); return new; end; $$;
drop trigger if exists trg_team_create_fan_community on public."Team";
create trigger trg_team_create_fan_community after insert on public."Team" for each row execute function public.trg_team_create_fan_community();

-- Core RPCs
create or replace function public.create_notification(p_user_id text,p_type text,p_title text,p_body text default null,p_actor_id text default null,p_reference_id text default null,p_target_id text default null,p_target_type text default null) returns text language plpgsql security definer set search_path = public as $$
declare nid text:='ntf-'||extract(epoch from now())::bigint||'-'||substr(md5(random()::text),1,6); begin
  insert into public."Notification"("id","userId","type","title","body","isRead","actorId","referenceId","targetId","targetType","createdAt")
  values(nid,p_user_id,p_type,p_title,p_body,false,p_actor_id,p_reference_id,p_target_id,p_target_type,now());
  return nid; end; $$;
revoke all on function public.create_notification(text,text,text,text,text,text,text,text) from public;
grant execute on function public.create_notification(text,text,text,text,text,text,text,text) to authenticated, service_role;

create or replace function public.notify_followers(p_author_id text,p_title text,p_body text default null,p_reference_id text default null) returns integer language plpgsql security definer set search_path = public as $$
declare n int:=0; r record; begin
  for r in select "followerId" as fid from public."Follow" where "followingId"=p_author_id loop
    perform public.create_notification(r.fid,'follow_activity',p_title,p_body,p_author_id,p_reference_id,p_author_id,'user');
    n:=n+1; end loop; return n; end; $$;
revoke all on function public.notify_followers(text,text,text,text) from public;
grant execute on function public.notify_followers(text,text,text,text) to authenticated, service_role;

-- Atomic RPCs (race-condition-free)
create or replace function public.increment_post_counter(p_post_id text,p_column text,p_delta int) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_column not in ('likeCount','commentCount','shareCount','viewCount') then raise exception 'invalid column'; end if;
  execute format('update public."Post" set %I=greatest(coalesce(%I,0)+$1,0) where id=$2',p_column,p_column) using p_delta,p_post_id;
end; $$;
revoke all on function public.increment_post_counter(text,text,int) from public;
grant execute on function public.increment_post_counter(text,text,int) to authenticated, service_role;

create or replace function public.increment_poll_votes(p_poll_id text,p_user_id text,p_option_index int) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public."PollVote"("pollId","userId","optionIndex","createdAt") values(p_poll_id,p_user_id,p_option_index,now()) on conflict("pollId","userId") do nothing;
  update public."Poll" set "totalVotes"=(select count(*) from public."PollVote" where "pollId"=p_poll_id) where id=p_poll_id;
end; $$;
revoke all on function public.increment_poll_votes(text,text,int) from public;
grant execute on function public.increment_poll_votes(text,text,int) to authenticated, service_role;

create or replace function public.join_community_atomic(p_community_id text,p_user_id text) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public."CommunityMember"("communityId","userId","role","joinedAt") values(p_community_id,p_user_id,'member',now()) on conflict("communityId","userId") do nothing;
  update public."Community" set "memberCount"=(select count(*) from public."CommunityMember" where "communityId"=p_community_id) where id=p_community_id;
end; $$;
revoke all on function public.join_community_atomic(text,text) from public;
grant execute on function public.join_community_atomic(text,text) to authenticated, service_role;

create or replace function public.leave_community_atomic(p_community_id text,p_user_id text) returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public."CommunityMember" where "communityId"=p_community_id and "userId"=p_user_id;
  update public."Community" set "memberCount"=(select count(*) from public."CommunityMember" where "communityId"=p_community_id) where id=p_community_id;
end; $$;
revoke all on function public.leave_community_atomic(text,text) from public;
grant execute on function public.leave_community_atomic(text,text) to authenticated, service_role;

create or replace function public.confirm_order_paid(p_order_id text,p_provider_ref text default null) returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from public."ShopOrder" where id=p_order_id and "userId"=auth.uid()::text) and not public.is_app_admin() then
    raise exception 'permission denied: not order owner'; end if;
  update public."ShopOrder" set status='paid',"paymentRef"=coalesce(p_provider_ref,"paymentRef"),"updatedAt"=now() where id=p_order_id;
end; $$;
revoke all on function public.confirm_order_paid(text,text) from public;
grant execute on function public.confirm_order_paid(text,text) to authenticated, service_role;

create or replace function public.approve_claim(p_claim_id text,p_review_notes text default '') returns jsonb language plpgsql security definer set search_path = public as $$
declare claim record; begin
  if not public.is_app_admin() then raise exception 'permission denied: admin only'; end if;
  select * into claim from public."ClaimRequest" where id=p_claim_id;
  if not found then raise exception 'claim not found'; end if;
  update public."ClaimRequest" set status='approved',"reviewerId"=auth.uid()::text,"reviewNotes"=p_review_notes,"reviewedAt"=now() where id=p_claim_id;
  insert into public."Notification"("userId","type","body","actorId","targetId","createdAt")
  values(claim."userId",'claim_approved',coalesce(p_review_notes,'Your profile claim was approved.'),auth.uid()::text,p_claim_id,now());
  return jsonb_build_object('id',p_claim_id,'status','approved'); end; $$;
revoke all on function public.approve_claim(text,text) from public;
grant execute on function public.approve_claim(text,text) to authenticated, service_role;

create or replace function public.reject_claim(p_claim_id text,p_review_notes text default '') returns jsonb language plpgsql security definer set search_path = public as $$
declare claim record; begin
  if not public.is_app_admin() then raise exception 'permission denied: admin only'; end if;
  select * into claim from public."ClaimRequest" where id=p_claim_id;
  if not found then raise exception 'claim not found'; end if;
  update public."ClaimRequest" set status='rejected',"reviewerId"=auth.uid()::text,"reviewNotes"=p_review_notes,"reviewedAt"=now() where id=p_claim_id;
  insert into public."Notification"("userId","type","body","actorId","targetId","createdAt")
  values(claim."userId",'claim_rejected',coalesce(p_review_notes,'Your profile claim was rejected.'),auth.uid()::text,p_claim_id,now());
  return jsonb_build_object('id',p_claim_id,'status','rejected'); end; $$;
revoke all on function public.reject_claim(text,text) from public;
grant execute on function public.reject_claim(text,text) to authenticated, service_role;

create or replace function public.admin_set_profile_role(p_profile_id uuid,p_role text) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_app_admin() then raise exception 'permission denied: admin only'; end if;
  if p_role not in ('fan','player','team','coach','scout','agent','support_staff','analyst','commentator','journalist','creator','moderator','official','academy','league','competition','organization','media_broadcast','community','business','sponsor','commercial_partner','venue','admin') then raise exception 'invalid role: %',p_role; end if;
  update public.profiles set role=p_role,updated_at=now() where id=p_profile_id;
  update public."User" set role=p_role,"updatedAt"=now() where id=p_profile_id::text;
end; $$;
revoke all on function public.admin_set_profile_role(uuid,text) from public;
grant execute on function public.admin_set_profile_role(uuid,text) to authenticated, service_role;

-- Count helpers (authenticated + service_role only — anon REVOKED)
create or replace function public.refresh_user_counts(p_id text) returns void language plpgsql security definer as $$
begin
  update public."User" u set
    "followerCount"=(select count(*) from public."Follow" f where f."followingId"=p_id),
    "followingCount"=(select count(*) from public."Follow" f where f."followerId"=p_id),
    "fanCount"=(select count(*) from public.fans f where f.target_id::text=p_id),
    "postCount"=(select count(*) from public."Post" p where p."userId"=p_id)
  where u.id=p_id; end; $$;
revoke all on function public.refresh_user_counts(text) from public;
grant execute on function public.refresh_user_counts(text) to authenticated, service_role;

create or replace function public.count_posts_for_user(p_id text) returns integer language sql stable security definer set search_path=public as $$ select count(*)::int from public."Post" p where p."userId"=p_id; $$;
create or replace function public.count_followers(p_id text) returns integer language sql stable security definer set search_path=public as $$ select count(*)::int from public."Follow" f where f."followingId"=p_id; $$;
create or replace function public.count_following(p_id text) returns integer language sql stable security definer set search_path=public as $$ select count(*)::int from public."Follow" f where f."followerId"=p_id; $$;
create or replace function public.count_fans_of(p_id text) returns integer language sql stable security definer set search_path=public as $$ select count(*)::int from public.fans f where f.target_id::text=p_id; $$;
revoke all on function public.count_fans_of(text) from public;
grant execute on function public.count_fans_of(text)       to authenticated, service_role;
grant execute on function public.count_posts_for_user(text) to authenticated, service_role;
grant execute on function public.count_followers(text)     to authenticated, service_role;
grant execute on function public.count_following(text)     to authenticated, service_role;

-- Feed (authenticated only — anon REVOKED)
create or replace function public.feed_for_user(p_user_id text,p_limit int default 40)
returns table(id text,"userId" text,content text,"postType" text,"mediaUrls" jsonb,"hashtags" jsonb,"teamTag" text,"sportTag" text,"likeCount" int,"commentCount" int,"shareCount" int,"createdAt" timestamptz,score numeric)
language sql stable security definer set search_path=public as $$
  with sports as (select s.slug from public."UserSport" us join public."Sport" s on s.id=us."sportId" where us."userId"=p_user_id),
  followed as (select "followingId" as uid from public."Follow" where "followerId"=p_user_id),
  fanned as (select t.id as team_id,t."accountUserId"::text as uid from public.fans f join public."Team" t on t."accountUserId"::text=f.target_id::text where f.fan_id::text=p_user_id)
  select p.id,p."userId",p.content,p."postType",p."mediaUrls",p."hashtags",p."teamTag",p."sportTag",p."likeCount",p."commentCount",p."shareCount",p."createdAt",
    (1.0
      +case when coalesce(p."sportTag",'') in(select slug from sports) then 4.0 else 0 end
      +case when p."userId" in(select uid from followed) then 5.0 else 0 end
      +case when p."userId" in(select uid from fanned) then 4.0 else 0 end
      +case when coalesce(p."teamTag",'') in(select team_id from fanned) then 4.0 else 0 end
      +least(coalesce(p."likeCount",0),50)*0.05
      +least(coalesce(p."commentCount",0),30)*0.08
      +case when p."postType"='live_coverage' then 2.0 else 0 end
      +case when p."createdAt">now()-interval'6 hours' then 3.0 when p."createdAt">now()-interval'2 days' then 1.5 else 0.2 end
    )::numeric
  from public."Post" p order by 13 desc,p."createdAt" desc limit p_limit;
$$;
revoke all on function public.feed_for_user(text,int) from public;
grant execute on function public.feed_for_user(text,int) to authenticated, service_role;

-- My notifications (filtered — no broadcast)
create or replace function public.my_notifications(p_limit int default 50) returns setof public."Notification"
language sql stable security definer set search_path=public as $$
  select * from public."Notification" where "userId"=auth.uid()::text order by "createdAt" desc limit p_limit; $$;
revoke all on function public.my_notifications(int) from public;
grant execute on function public.my_notifications(int) to authenticated, service_role;

-- bump_news_share
create or replace function public.bump_news_share(p_id text) returns void language plpgsql security definer set search_path=public as $$
begin update public."NewsItem" set "shareCount"=coalesce("shareCount",0)+1 where id=p_id; end; $$;
revoke all on function public.bump_news_share(text) from public;
grant execute on function public.bump_news_share(text) to authenticated, service_role;

-- Nearby fans
create or replace function public.haversine_meters(p_lat1 double precision,p_lng1 double precision,p_lat2 double precision,p_lng2 double precision) returns double precision language sql immutable as $$
  select 6371000.0*2.0*asin(sqrt(power(sin(radians(p_lat2-p_lat1)/2.0),2)+cos(radians(p_lat1))*cos(radians(p_lat2))*power(sin(radians(p_lng2-p_lng1)/2.0),2))); $$;
revoke all on function public.haversine_meters(double precision,double precision,double precision,double precision) from public;
grant execute on function public.haversine_meters(double precision,double precision,double precision,double precision) to authenticated, service_role;

create or replace function public.nearby_fans(p_lat double precision,p_lng double precision,p_radius_m int default 50000,p_limit int default 50)
returns table(id text,handle text,name text,"avatarUrl" text,role text,latitude double precision,longitude double precision,distance_m double precision,"currentCountry" text,location text)
language sql stable security definer set search_path=public as $$
  select u.id,u.handle,u.name,u."avatarUrl",u.role,p.latitude,p.longitude,
    public.haversine_meters(p_lat,p_lng,p.latitude,p.longitude) as distance_m,
    u."currentCountry",u.location
  from public.profiles p join public."User" u on u.id=p.id::text
  where p.latitude is not null and p.longitude is not null and p.id::text<>auth.uid()::text
    and public.haversine_meters(p_lat,p_lng,p.latitude,p.longitude)<=p_radius_m
  order by distance_m asc limit p_limit; $$;
revoke all on function public.nearby_fans(double precision,double precision,int,int) from public;
grant execute on function public.nearby_fans(double precision,double precision,int,int) to authenticated, service_role;

-- sync_user_from_profile (safe bidirectional backfill)
create or replace function public.sync_user_from_profile() returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public."User"("id","name","email","handle","role","bio","isVerified")
  select p.id::text,coalesce(nullif(trim(coalesce(p.first_name,'')||' '||coalesce(p.last_name,'')),'' ),p.handle,p.id::text),
    coalesce(nullif(p.email,''),p.id::text||'@users.local'),coalesce(nullif(p.handle,''),left(replace(p.id::text,'-',''),10)),
    coalesce(p.role,'fan'),coalesce(p.bio,''),false
  from public.profiles p where not exists(select 1 from public."User" u where u.id=p.id::text) on conflict("id") do nothing;
  insert into public.profiles(id,handle,role,first_name,last_name,email,bio)
  select u.id::uuid,u.handle,u.role,split_part(u.name,' ',1),nullif(trim(substr(u.name,length(split_part(u.name,' ',1))+1)),''),u.email,coalesce(u.bio,'')
  from public."User" u where u.id~'^[0-9a-f-]{36}$' and not exists(select 1 from public.profiles p where p.id::text=u.id) on conflict(id) do nothing;
end; $$;
revoke all on function public.sync_user_from_profile() from public;
grant execute on function public.sync_user_from_profile() to authenticated, service_role;

-- _safe_add_to_realtime
create or replace function public._safe_add_to_realtime(p_table regclass) returns void language plpgsql security definer set search_path=public as $$
begin begin execute format('alter publication supabase_realtime add table %s',p_table);
  exception when duplicate_object then null; when undefined_object then null; end; end; $$;
revoke all on function public._safe_add_to_realtime(regclass) from public;
grant execute on function public._safe_add_to_realtime(regclass) to service_role;

-- Realtime publications
do $$ begin
  perform public._safe_add_to_realtime('public."Match"');
  perform public._safe_add_to_realtime('public."Post"');
  perform public._safe_add_to_realtime('public."Comment"');
  perform public._safe_add_to_realtime('public."PostLike"');
  perform public._safe_add_to_realtime('public."Notification"');
  perform public._safe_add_to_realtime('public."Message"');
  perform public._safe_add_to_realtime('public."Follow"');
  perform public._safe_add_to_realtime('public.fans');
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RLS — enable + policies (consolidated, no duplicates)
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.profiles              enable row level security;
alter table public."User"                enable row level security;
alter table public."Follow"              enable row level security;
alter table public.fans                  enable row level security;
alter table public."Post"                enable row level security;
alter table public."PostLike"            enable row level security;
alter table public."PostShare"           enable row level security;
alter table public."Comment"             enable row level security;
alter table public."CommentLike"         enable row level security;
alter table public."Poll"                enable row level security;
alter table public."PollVote"            enable row level security;
alter table public."Community"           enable row level security;
alter table public."CommunityMember"     enable row level security;
alter table public."Notification"        enable row level security;
alter table public."Message"             enable row level security;
alter table public.device_tokens         enable row level security;
alter table public."Match"               enable row level security;
alter table public."League"              enable row level security;
alter table public."Team"                enable row level security;
alter table public."Player"              enable row level security;
alter table public."Coach"               enable row level security;
alter table public."Sport"               enable row level security;
alter table public."NewsItem"            enable row level security;
alter table public.news_likes            enable row level security;
alter table public.news_comments         enable row level security;
alter table public."UserFavorite"        enable row level security;
alter table public."Prediction"          enable row level security;
alter table public."ShopOrder"           enable row level security;
alter table public."ClaimRequest"        enable row level security;
alter table public."VerificationRequest" enable row level security;
alter table public."RoleRequest"         enable row level security;
alter table public."PlayerMatchStat"     enable row level security;
alter table public.entity_follows        enable row level security;
alter table public.entity_communities    enable row level security;
alter table public.identity_audit        enable row level security;
alter table public.taxonomy_term         enable row level security;

-- Drop all policies then recreate cleanly
do $$ declare r record; begin
  for r in select policyname,tablename from pg_policies where schemaname='public' loop
    execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename);
  end loop; end $$;

-- profiles
create policy "profiles_read"       on public.profiles for select to authenticated using(true);
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check(auth.uid()=id);
create policy "profiles_update_own" on public.profiles for update to authenticated using(auth.uid()=id) with check(auth.uid()=id);
create policy "profiles_admin_update" on public.profiles for update to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
grant select on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;

-- User (authenticated only — C9 fix)
create policy "user_public_read"   on public."User" for select to authenticated using(true);
create policy "user_own_update"    on public."User" for update to authenticated using(auth.uid()::text="id");
create policy "user_own_insert"    on public."User" for insert to authenticated with check(auth.uid()::text="id");

-- Follow
create policy "follow_public_read"  on public."Follow" for select using(true);
create policy "follow_auth_create"  on public."Follow" for insert to authenticated with check(auth.uid()::text="followerId");
create policy "follow_own_delete"   on public."Follow" for delete to authenticated using(auth.uid()::text="followerId");

-- fans (snake_case)
create policy "fans_read"       on public.fans for select using(true);
create policy "fans_write_own"  on public.fans for insert to authenticated with check(auth.uid()=fan_id);
create policy "fans_delete_own" on public.fans for delete to authenticated using(auth.uid()=fan_id);

-- Post
create policy "post_public_read"  on public."Post" for select using(true);
create policy "post_auth_create"  on public."Post" for insert to authenticated with check(auth.uid()::text="userId");
create policy "post_own_update"   on public."Post" for update to authenticated using(auth.uid()::text="userId" or public.is_app_admin());
create policy "post_own_delete"   on public."Post" for delete to authenticated using(auth.uid()::text="userId" or public.is_app_admin());

-- PostLike / PostShare / CommentLike
create policy "post_like_read"   on public."PostLike" for select using(true);
create policy "post_like_create" on public."PostLike" for insert to authenticated with check(auth.uid()::text="userId");
create policy "post_like_delete" on public."PostLike" for delete to authenticated using(auth.uid()::text="userId");
create policy "post_share_read"   on public."PostShare" for select using(true);
create policy "post_share_create" on public."PostShare" for insert to authenticated with check(auth.uid()::text="userId");
create policy "post_share_delete" on public."PostShare" for delete to authenticated using(auth.uid()::text="userId");
create policy "comment_like_read"   on public."CommentLike" for select using(true);
create policy "comment_like_create" on public."CommentLike" for insert to authenticated with check(auth.uid()::text="userId");
create policy "comment_like_delete" on public."CommentLike" for delete to authenticated using(auth.uid()::text="userId");

-- Comment
create policy "comment_public_read"  on public."Comment" for select using(true);
create policy "comment_auth_create"  on public."Comment" for insert to authenticated with check(auth.uid()::text="userId");
create policy "comment_own_delete"   on public."Comment" for delete to authenticated using(auth.uid()::text="userId" or public.is_app_admin());

-- Poll / PollVote
create policy "poll_public_read"  on public."Poll" for select using(true);
create policy "poll_auth_create"  on public."Poll" for insert to authenticated with check(auth.uid() is not null);
create policy "poll_vote_read"    on public."PollVote" for select using(true);
create policy "poll_vote_auth"    on public."PollVote" for insert to authenticated with check(auth.uid()::text="userId");

-- Community
create policy "community_public_read" on public."Community" for select using(true);
create policy "community_auth_create" on public."Community" for insert to authenticated with check(auth.uid() is not null);
create policy "cm_public_read"  on public."CommunityMember" for select using(true);
create policy "cm_auth_join"    on public."CommunityMember" for insert to authenticated with check(auth.uid()::text="userId");
create policy "cm_own_leave"    on public."CommunityMember" for delete to authenticated using(auth.uid()::text="userId");

-- Notification / Message
create policy "notif_own_read"   on public."Notification" for select to authenticated using(auth.uid()::text="userId");
create policy "notif_own_update" on public."Notification" for update to authenticated using(auth.uid()::text="userId");
create policy "msg_participants_read" on public."Message" for select to authenticated using(auth.uid()::text="senderId" or auth.uid()::text="receiverId");
create policy "msg_auth_send"   on public."Message" for insert to authenticated with check(auth.uid()::text="senderId");
create policy "msg_own_update"  on public."Message" for update to authenticated using(auth.uid()::text="receiverId" or auth.uid()::text="senderId");
create policy "device_tokens_own" on public.device_tokens for all to authenticated using(auth.uid()::text=user_id) with check(auth.uid()::text=user_id);

-- Sports data (public read, admin write)
create policy "match_public"   on public."Match"  for select using(true);
create policy "match_admin"    on public."Match"  for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "league_public"  on public."League" for select using(true);
create policy "league_admin"   on public."League" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "team_public"    on public."Team"   for select using(true);
create policy "team_admin"     on public."Team"   for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "player_public"  on public."Player" for select using(true);
create policy "player_admin"   on public."Player" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "coach_public"   on public."Coach"  for select using(true);
create policy "coach_admin"    on public."Coach"  for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "sport_public"   on public."Sport"  for select using(true);
create policy "news_public"    on public."NewsItem" for select using(true);
create policy "news_admin"     on public."NewsItem" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "taxonomy_read"  on public.taxonomy_term for select using(true);
create policy "taxonomy_admin" on public.taxonomy_term for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());

-- news engagement
create policy "news_likes_read"         on public.news_likes for select using(true);
create policy "news_likes_auth_insert"  on public.news_likes for insert to authenticated with check(auth.uid()::text=user_id);
create policy "news_likes_own_delete"   on public.news_likes for delete to authenticated using(auth.uid()::text=user_id);
create policy "news_comments_read"      on public.news_comments for select using(true);
create policy "news_comments_auth_insert" on public.news_comments for insert to authenticated with check(auth.uid()::text=user_id);
create policy "news_comments_own_update" on public.news_comments for update to authenticated using(auth.uid()::text=user_id) with check(auth.uid()::text=user_id);
create policy "news_comments_own_delete" on public.news_comments for delete to authenticated using(auth.uid()::text=user_id);

-- Favorites
create policy "fav_own_read"   on public."UserFavorite" for select to authenticated using(auth.uid()::text="userId");
create policy "fav_auth_create" on public."UserFavorite" for insert to authenticated with check(auth.uid()::text="userId");
create policy "fav_own_delete" on public."UserFavorite" for delete to authenticated using(auth.uid()::text="userId");

-- Predictions
create policy "pred_public_read" on public."Prediction" for select using(true);
create policy "pred_own_create"  on public."Prediction" for insert to authenticated
  with check(auth.uid()::text="userId" and ("matchId" is null or not exists(select 1 from public."Match" m where m.id="matchId" and m.status in('ft','finished','full time'))));
create policy "pred_own_update"  on public."Prediction" for update to authenticated
  using(auth.uid()::text="userId" and "closedAt" is null) with check(auth.uid()::text="userId" and "closedAt" is null);

-- Shop
create policy "order_own_read"   on public."ShopOrder" for select to authenticated
  using(auth.uid()::text="userId" or exists(select 1 from public."User" u where u.id=auth.uid()::text and lower(u.handle)=lower(coalesce("ShopOrder"."sellerHandle",''))) or public.is_app_admin());
create policy "order_auth_create" on public."ShopOrder" for insert to authenticated with check(auth.uid()::text="userId");
create policy "order_own_update"  on public."ShopOrder" for update to authenticated using(auth.uid()::text="userId" or public.is_app_admin()) with check(auth.uid()::text="userId" or public.is_app_admin());

-- Claims / Verification
create policy "claim_own_read"    on public."ClaimRequest" for select to authenticated using(auth.uid()::text="userId");
create policy "claim_auth_create" on public."ClaimRequest" for insert to authenticated with check(auth.uid()::text="userId");
create policy "claim_admin"       on public."ClaimRequest" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "verif_own_read"    on public."VerificationRequest" for select to authenticated using(auth.uid()::text="userId" or public.is_app_admin());
create policy "verif_auth_insert" on public."VerificationRequest" for insert to authenticated with check(auth.uid()::text="userId");
create policy "verif_admin"       on public."VerificationRequest" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());
create policy "role_req_own_read"   on public."RoleRequest" for select to authenticated using(auth.uid()="userId");
create policy "role_req_own_insert" on public."RoleRequest" for insert with check(auth.uid()="userId");
create policy "role_req_admin"      on public."RoleRequest" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());

-- PlayerMatchStat (admin-only write)
create policy "pms_public_read" on public."PlayerMatchStat" for select using(true);
create policy "pms_admin_write" on public."PlayerMatchStat" for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());

-- Entity identity
create policy "entity_follows_read"   on public.entity_follows for select using(true);
create policy "entity_follows_create" on public.entity_follows for insert with check(auth.uid()=follower_id);
create policy "entity_follows_delete" on public.entity_follows for delete using(auth.uid()=follower_id);
create policy "entity_communities_read" on public.entity_communities for select using(true);
create policy "entity_communities_admin" on public.entity_communities for all using(auth.role()='service_role');
create policy "audit_own_read"   on public.identity_audit for select to authenticated using(public.is_app_admin() or (entity_type='profile' and entity_id=auth.uid()::text));
create policy "audit_admin_write" on public.identity_audit for all to authenticated using(public.is_app_admin()) with check(public.is_app_admin());

-- Promote canonical admin accounts (by verified email ONLY — no handle squatting)
update public.profiles set role='admin',is_verified=true
  where lower(coalesce(email,'')) in ('playify@playify.com','sportsphere.app@sportsphere.com');
update public."User" set role='admin',"isVerified"=true,"verificationStatus"='verified'
  where lower(coalesce(email,'')) in ('playify@playify.com','sportsphere.app@sportsphere.com');

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. SEED DATA
-- ─────────────────────────────────────────────────────────────────────────────

-- 23 Roles
insert into public."Role"("id","name","slug","description","icon","category","displayOrder","isActive") values
  ('role-fan','Fan','fan','Follow teams, vote, predict, join communities','👤','individual',1,true),
  ('role-player','Player','player','Athlete / player profile','⚽','individual',2,true),
  ('role-team','Team','team','Club or team account','🛡️','organization',3,true),
  ('role-coach','Coach','coach','Coach or technical staff','📋','individual',4,true),
  ('role-scout','Scout','scout','Talent scout','🔎','individual',5,true),
  ('role-agent','Agent','agent','Player / coach agent','💼','individual',6,true),
  ('role-support-staff','Support Staff','support_staff','Physio, analyst staff, kit','🩺','individual',7,true),
  ('role-analyst','Analyst','analyst','Performance / tactical analyst','📊','individual',8,true),
  ('role-commentator','Commentator','commentator','Match commentator','🎙️','individual',9,true),
  ('role-journalist','Journalist','journalist','Sports journalist','📰','individual',10,true),
  ('role-creator','Creator','creator','Content creator','🎬','individual',11,true),
  ('role-moderator','Moderator','moderator','Community moderator','🛡️','individual',12,true),
  ('role-official','Official','official','Referee / match official','🟨','individual',13,true),
  ('role-academy','Academy','academy','Youth academy','🎓','organization',14,true),
  ('role-league','League','league','League body','🏆','organization',15,true),
  ('role-competition','Competition','competition','Cup / tournament','🥇','organization',16,true),
  ('role-organization','Organization','organization','Federation / association','🏛️','organization',17,true),
  ('role-media-broadcast','Media/Broadcast','media_broadcast','Media or broadcaster','📡','organization',18,true),
  ('role-community','Community','community','Fan community page','👥','organization',19,true),
  ('role-business','Business','business','Retail / brand business','🛒','commerce',20,true),
  ('role-sponsor','Sponsor','sponsor','Sponsor brand','💎','commerce',21,true),
  ('role-commercial-partner','Commercial Partner','commercial_partner','Commercial partner','🤝','commerce',22,true),
  ('role-venue','Venue','venue','Stadium or venue','🏟️','commerce',23,true)
on conflict("id") do update set "name"=excluded."name","slug"=excluded."slug","isActive"=true;

-- Sports
insert into public."Sport"("id","name","slug","icon","category","displayOrder") values
  ('sport-football','Football','football','⚽','team',1),
  ('sport-basketball','Basketball','basketball','🏀','team',2),
  ('sport-athletics','Athletics','athletics','🏃','individual',3),
  ('sport-tennis','Tennis','tennis','🎾','individual',4),
  ('sport-volleyball','Volleyball','volleyball','🏐','team',5),
  ('sport-rugby','Rugby','rugby','🏉','team',6),
  ('sport-cricket','Cricket','cricket','🏏','team',7),
  ('sport-boxing','Boxing','boxing','🥊','individual',8)
on conflict("id") do nothing;

-- Venues
insert into public."Venue"("name","city","country","capacity") values
  ('Benjamin Mkapa Stadium','Dar es Salaam','Tanzania',60000),
  ('Uhuru Stadium','Dar es Salaam','Tanzania',25000),
  ('Azam Complex','Dar es Salaam','Tanzania',15000),
  ('Amaan Stadium','Zanzibar','Tanzania',15000),
  ('Sokoine Stadium','Mbeya','Tanzania',15000),
  ('Jamhuri Stadium','Dodoma','Tanzania',15000),
  ('Arusha Stadium','Arusha','Tanzania',10000)
on conflict("name","city") do nothing;

-- Communities
insert into public."Community"("id","name","description","topic","memberCount","createdAt") values
  ('com-simba-fans','Simba SC Official Fans','Derby threads and meet-ups','Football',0,now()),
  ('com-yanga-union','Yanga Union','Jangwani updates and away days','Football',0,now()),
  ('com-tpl-tactics','TPL Tactics Room','Post-match analysis','Analysis',0,now()),
  ('com-dar-meetups','Dar Matchday Meetups','Fans going to the stadium','Local',0,now()),
  ('com-predictions','Predictions League','Weekly score predictions','Fantasy',0,now()),
  ('com-women-football','Women in Football TZ','Players, coaches and fans','Community',0,now())
on conflict("id") do nothing;

-- Backfill counters (idempotent)
update public."Post" p set
  "likeCount"=(select count(*) from public."PostLike" l where l."postId"=p.id),
  "commentCount"=(select count(*) from public."Comment" c where c."postId"=p.id),
  "shareCount"=(select count(*) from public."PostShare" s where s."postId"=p.id);
update public."NewsItem" n set
  "likeCount"=(select count(*) from public.news_likes l where l.news_id=n.id),
  "commentCount"=(select count(*) from public.news_comments c where c.news_id=n.id);

-- Settle already-finished matches
do $$ declare m record; begin
  for m in select id from public."Match" where status in('ft','finished','full time') loop
    perform public.settle_match_predictions(m.id); end loop; end $$;

-- Backfill team fan communities
do $$ declare t record; begin
  for t in select id from public."Team" loop
    perform public.create_team_fan_community(t.id); end loop; end $$;
