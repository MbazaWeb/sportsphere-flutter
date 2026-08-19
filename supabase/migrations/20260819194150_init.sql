-- SportSphere initial schema
-- Applied baseline: profiles, social graph, communities, posts

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text not null unique,
  role text not null default 'fan',
  first_name text not null default '',
  last_name text not null default '',
  email text,
  country text default 'Tanzania',
  avatar_url text,
  bio text,
  follower_count int not null default 0,
  following_count int not null default 0,
  fan_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.fans (
  fan_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (fan_id, target_id),
  check (fan_id <> target_id)
);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  topic text,
  description text,
  member_count int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text,
  kind text not null default 'text',
  media_url text,
  like_count int not null default 0,
  comment_count int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists profiles_handle_idx on public.profiles (handle);
create index if not exists posts_author_idx on public.posts (author_id, created_at desc);
create index if not exists comments_post_idx on public.comments (post_id, created_at);

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.fans enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;

drop policy if exists "profiles_read" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_read" on public.profiles for select using (true);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

drop policy if exists "follows_read" on public.follows;
drop policy if exists "follows_write_own" on public.follows;
drop policy if exists "follows_delete_own" on public.follows;
create policy "follows_read" on public.follows for select using (true);
create policy "follows_write_own" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete_own" on public.follows for delete using (auth.uid() = follower_id);

drop policy if exists "fans_read" on public.fans;
drop policy if exists "fans_write_own" on public.fans;
drop policy if exists "fans_delete_own" on public.fans;
create policy "fans_read" on public.fans for select using (true);
create policy "fans_write_own" on public.fans for insert with check (auth.uid() = fan_id);
create policy "fans_delete_own" on public.fans for delete using (auth.uid() = fan_id);

drop policy if exists "communities_read" on public.communities;
create policy "communities_read" on public.communities for select using (true);

drop policy if exists "community_members_read" on public.community_members;
drop policy if exists "community_members_join" on public.community_members;
drop policy if exists "community_members_leave" on public.community_members;
create policy "community_members_read" on public.community_members for select using (true);
create policy "community_members_join" on public.community_members for insert with check (auth.uid() = user_id);
create policy "community_members_leave" on public.community_members for delete using (auth.uid() = user_id);

drop policy if exists "posts_read" on public.posts;
drop policy if exists "posts_insert_own" on public.posts;
drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_read" on public.posts for select using (true);
create policy "posts_insert_own" on public.posts for insert with check (auth.uid() = author_id);
create policy "posts_delete_own" on public.posts for delete using (auth.uid() = author_id);

drop policy if exists "likes_read" on public.post_likes;
drop policy if exists "likes_write_own" on public.post_likes;
drop policy if exists "likes_delete_own" on public.post_likes;
create policy "likes_read" on public.post_likes for select using (true);
create policy "likes_write_own" on public.post_likes for insert with check (auth.uid() = user_id);
create policy "likes_delete_own" on public.post_likes for delete using (auth.uid() = user_id);

drop policy if exists "comments_read" on public.comments;
drop policy if exists "comments_write_own" on public.comments;
create policy "comments_read" on public.comments for select using (true);
create policy "comments_write_own" on public.comments for insert with check (auth.uid() = author_id);

insert into public.communities (slug, name, topic, description, member_count) values
  ('simba-fans', 'Simba SC Official Fans', 'Football · Official', 'Derby week thread is live.', 42100),
  ('tpl-tactics', 'TPL Tactics Room', 'Analysis', 'Post-match xG, lineups and formations.', 8400),
  ('dar-meetups', 'Dar Matchday Meetups', 'Local', 'Find fans going to Mkapa this weekend.', 3200),
  ('women-football-tz', 'Women in Football TZ', 'Community', 'Players, coaches and fans building the game.', 1900),
  ('yanga-union', 'Yanga Union', 'Football · Official', 'Jangwani updates, away days and chants.', 31600),
  ('predictions', 'Predictions League', 'Fantasy', 'Weekly TPL and CAF score predictions.', 6800)
on conflict (slug) do nothing;
