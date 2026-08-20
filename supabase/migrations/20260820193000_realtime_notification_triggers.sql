-- Auto-create Notification rows on social events + device token table for future FCM

create table if not exists public.device_tokens (
  id bigserial primary key,
  user_id text not null references public."User"("id") on delete cascade,
  token text not null,
  platform text,
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.device_tokens enable row level security;
drop policy if exists "device_tokens_own" on public.device_tokens;
create policy "device_tokens_own" on public.device_tokens
  for all to authenticated
  using (auth.uid()::text = user_id)
  with check (auth.uid()::text = user_id);

-- Like → notify post author
create or replace function public.trg_notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  author_id text;
begin
  select "userId" into author_id from public."Post" where id = new."postId";
  if author_id is null or author_id = new."userId" then
    return new;
  end if;
  perform public.create_notification(
    author_id,
    'like',
    'New like',
    'Someone liked your post',
    new."userId",
    new."postId",
    new."postId",
    'post'
  );
  return new;
end;
$$;

drop trigger if exists trg_post_like_notify on public."PostLike";
create trigger trg_post_like_notify
  after insert on public."PostLike"
  for each row execute function public.trg_notify_post_like();

-- Comment → notify post author
create or replace function public.trg_notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  author_id text;
  snippet text;
begin
  select "userId" into author_id from public."Post" where id = new."postId";
  if author_id is null or author_id = new."userId" then
    return new;
  end if;
  snippet := left(coalesce(new.content, 'New comment'), 80);
  perform public.create_notification(
    author_id,
    'comment',
    'New comment',
    snippet,
    new."userId",
    new."postId",
    new.id,
    'comment'
  );
  return new;
end;
$$;

drop trigger if exists trg_post_comment_notify on public."Comment";
create trigger trg_post_comment_notify
  after insert on public."Comment"
  for each row execute function public.trg_notify_post_comment();

-- Follow → notify target
create or replace function public.trg_notify_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new."followerId" = new."followingId" then
    return new;
  end if;
  perform public.create_notification(
    new."followingId",
    'follow',
    'New follower',
    'Someone started following you',
    new."followerId",
    new."followerId",
    new."followerId",
    'user'
  );
  return new;
end;
$$;

drop trigger if exists trg_follow_notify on public."Follow";
create trigger trg_follow_notify
  after insert on public."Follow"
  for each row execute function public.trg_notify_follow();
