-- Claim requests for admin-created team / player / coach profiles
create table if not exists public."ClaimRequest" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "profileType" text not null,
  "profileId" text not null,
  "profileName" text not null,
  "leagueId" text,
  "teamId" text,
  "playerId" text,
  "coachId" text,
  "claimEmail" text,
  "claimPhone" text,
  "evidenceNotes" text,
  "evidenceUrls" jsonb not null default '[]',
  "status" text not null default 'pending',
  "reviewerId" text,
  "reviewNotes" text,
  "submittedAt" timestamptz not null default now(),
  "reviewedAt" timestamptz
);
create index if not exists "ClaimRequest_userId_idx" on public."ClaimRequest"("userId");
create index if not exists "ClaimRequest_status_idx" on public."ClaimRequest"("status");
alter table public."ClaimRequest" enable row level security;
drop policy if exists "claim_own_read" on public."ClaimRequest";
drop policy if exists "claim_auth_create" on public."ClaimRequest";
create policy "claim_own_read" on public."ClaimRequest" for select using (auth.uid()::text = "userId");
create policy "claim_auth_create" on public."ClaimRequest" for insert with check (auth.uid()::text = "userId");
alter table public."Team" add column if not exists "isClaimable" boolean not null default true;
alter table public."Player" add column if not exists "isClaimable" boolean not null default true;
alter table public."Coach" add column if not exists "isClaimable" boolean not null default true;
alter table public."Player" add column if not exists "accountUserId" text;
alter table public."Coach" add column if not exists "accountUserId" text;
