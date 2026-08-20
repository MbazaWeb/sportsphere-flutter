
-- Existing function used p_col; CREATE OR REPLACE cannot rename args.
drop function if exists public.increment_post_counter(text, text, int);

create function public.increment_post_counter(
  p_post_id text,
  p_column text,
  p_delta int
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_column not in ('likeCount', 'commentCount', 'shareCount', 'viewCount') then
    raise exception 'invalid column';
  end if;
  execute format(
    'update public."Post" set %I = greatest(coalesce(%I, 0) + $1, 0) where id = $2',
    p_column, p_column
  ) using p_delta, p_post_id;
end;
$$;

grant execute on function public.increment_post_counter(text, text, int)
  to authenticated, anon, service_role;
