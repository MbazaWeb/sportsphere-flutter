-- (1) Unique shares
create table if not exists public."PostShare" (
  "postId" text not null references public."Post"("id") on delete cascade,
  "userId" text not null references public."User"("id") on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("postId", "userId")
);
create index if not exists "PostShare_userId_idx" on public."PostShare"("userId");
alter table public."PostShare" enable row level security;
drop policy if exists "post_share_public_read" on public."PostShare";
drop policy if exists "post_share_auth_create" on public."PostShare";
drop policy if exists "post_share_own_delete" on public."PostShare";
create policy "post_share_public_read" on public."PostShare" for select using (true);
create policy "post_share_auth_create" on public."PostShare" for insert with check (auth.uid()::text = "userId");
create policy "post_share_own_delete" on public."PostShare" for delete using (auth.uid()::text = "userId");

-- (3) Player match stats
create table if not exists public."PlayerMatchStat" (
  "id" text primary key default gen_random_uuid()::text,
  "playerId" text not null references public."Player"("id") on delete cascade,
  "matchId" text references public."Match"("id") on delete set null,
  "season" text not null default '2026/2027',
  "competition" text,
  "played" boolean not null default true,
  "minutes" integer not null default 0,
  "goals" integer not null default 0,
  "assists" integer not null default 0,
  "saves" integer not null default 0,
  "yellowCards" integer not null default 0,
  "redCards" integer not null default 0,
  "createdAt" timestamptz not null default now(),
  "updatedAt" timestamptz not null default now()
);
create index if not exists "PlayerMatchStat_player_idx" on public."PlayerMatchStat"("playerId");
alter table public."PlayerMatchStat" enable row level security;
drop policy if exists "pms_public_read" on public."PlayerMatchStat";
drop policy if exists "pms_auth_write" on public."PlayerMatchStat";
create policy "pms_public_read" on public."PlayerMatchStat" for select using (true);
create policy "pms_auth_write" on public."PlayerMatchStat" for all to authenticated using (true) with check (true);

-- (4) Orders / tickets sold
create table if not exists public."ShopOrder" (
  "id" text primary key default gen_random_uuid()::text,
  "userId" text not null references public."User"("id") on delete cascade,
  "sellerHandle" text,
  "sellerName" text,
  "itemId" text not null,
  "itemName" text not null,
  "kind" text not null default 'ticket',
  "quantity" integer not null default 1,
  "unitPriceTzs" integer not null default 0,
  "amountTzs" integer not null default 0,
  "status" text not null default 'paid',
  "createdAt" timestamptz not null default now()
);
create index if not exists "ShopOrder_user_idx" on public."ShopOrder"("userId");
create index if not exists "ShopOrder_seller_idx" on public."ShopOrder"("sellerHandle");
alter table public."ShopOrder" enable row level security;
drop policy if exists "order_own_read" on public."ShopOrder";
drop policy if exists "order_auth_create" on public."ShopOrder";
create policy "order_own_read" on public."ShopOrder" for select using (
  auth.uid()::text = "userId" or true
);
create policy "order_auth_create" on public."ShopOrder" for insert with check (auth.uid()::text = "userId");

-- CommunityMember already has PK (communityId, userId) — ensure policies
alter table public."CommunityMember" enable row level security;
