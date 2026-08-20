
create or replace function public.increment_post_counter(
  p_post_id text,
  p_column text,
  p_delta int
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_column = 'likeCount' then
    update public."Post" set "likeCount" = greatest(coalesce("likeCount",0) + p_delta, 0) where id = p_post_id;
  elsif p_column = 'commentCount' then
    update public."Post" set "commentCount" = greatest(coalesce("commentCount",0) + p_delta, 0) where id = p_post_id;
  elsif p_column = 'shareCount' then
    update public."Post" set "shareCount" = greatest(coalesce("shareCount",0) + p_delta, 0) where id = p_post_id;
  end if;
end;
$$;
grant execute on function public.increment_post_counter(text,text,int) to authenticated, anon, service_role;
