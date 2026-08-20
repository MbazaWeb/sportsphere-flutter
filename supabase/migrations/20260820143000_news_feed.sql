alter table public."NewsItem" add column if not exists source text;
alter table public."NewsItem" add column if not exists source_url text;
alter table public."NewsItem" add column if not exists is_breaking boolean default false;

alter table public."NewsItem" enable row level security;
drop policy if exists news_public_read on public."NewsItem";
create policy news_public_read on public."NewsItem" for select using (true);
