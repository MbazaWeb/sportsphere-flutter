create or replace function public.refresh_user_counts(p_id text)
returns void language plpgsql security definer as $$
begin
  update public."User" u set
    "followerCount" = (select count(*) from public."Follow" f where f."followingId" = p_id),
    "followingCount" = (select count(*) from public."Follow" f where f."followerId" = p_id),
    "fanCount" = (select count(*) from public.fans f where f.target_id::text = p_id),
    "postCount" = (select count(*) from public."Post" p where p."userId" = p_id)
  where u.id = p_id;
end $$;
grant execute on function public.refresh_user_counts(text) to anon, authenticated;
