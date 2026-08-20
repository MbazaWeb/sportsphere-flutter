alter table public."NewsItem" add column if not exists "likeCount" int default 0;
alter table public."NewsItem" add column if not exists "commentCount" int default 0;
alter table public."NewsItem" add column if not exists "shareCount" int default 0;
create table if not exists public.news_likes (
  news_id text not null, user_id text not null, created_at timestamptz default now(),
  primary key (news_id, user_id)
);
create table if not exists public.news_comments (
  id text primary key, news_id text not null, user_id text not null, content text not null,
  created_at timestamptz default now()
);
alter table public.news_likes enable row level security;
alter table public.news_comments enable row level security;
