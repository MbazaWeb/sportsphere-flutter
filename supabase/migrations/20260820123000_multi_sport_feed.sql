insert into public."Sport" (id, name, slug, sport_slug, category, "isActive", "displayOrder", description)
select 'sport-' || slug, label, slug, slug, 'sport', true, sort_order, label
from public.taxonomy_term where domain = 'sport'
on conflict (id) do update set name = excluded.name, slug = excluded.slug, sport_slug = excluded.sport_slug;

alter table public."UserSport" add column if not exists is_primary boolean default false;
alter table public."UserSport" add column if not exists weight int default 1;

create or replace function public.feed_for_user(p_user_id text, p_limit int default 40)
returns table (
  id text, "userId" text, content text, "postType" text, "mediaUrls" jsonb,
  "hashtags" jsonb, "teamTag" text, "sportTag" text,
  "likeCount" int, "commentCount" int, "shareCount" int,
  "createdAt" timestamptz, score numeric
)
language sql stable security definer set search_path = public
as $$
  with sports as (
    select s.slug from public."UserSport" us
    join public."Sport" s on s.id = us."sportId"
    where us."userId" = p_user_id
  ),
  followed as (
    select "followingId" as uid from public."Follow" where "followerId" = p_user_id
  ),
  fanned as (
    select t.id as team_id, t."accountUserId"::text as uid
    from public.fans f
    join public."Team" t on t."accountUserId"::text = f.target_id::text
    where f.fan_id::text = p_user_id
  )
  select p.id, p."userId", p.content, p."postType", p."mediaUrls", p."hashtags",
    p."teamTag", p."sportTag", p."likeCount", p."commentCount", p."shareCount",
    p."createdAt",
    (1.0
      + case when coalesce(p."sportTag",'') in (select slug from sports) then 4.0 else 0 end
      + case when p."userId" in (select uid from followed) then 5.0 else 0 end
      + case when p."userId" in (select uid from fanned) then 4.0 else 0 end
      + case when coalesce(p."teamTag",'') in (select team_id from fanned) then 4.0 else 0 end
      + least(coalesce(p."likeCount",0), 50) * 0.05
      + least(coalesce(p."commentCount",0), 30) * 0.08
      + case when p."postType" = 'live_coverage' then 2.0 else 0 end
      + case when p."createdAt" > now() - interval '6 hours' then 3.0
             when p."createdAt" > now() - interval '2 days' then 1.5 else 0.2 end
    )::numeric
  from public."Post" p
  order by 13 desc, p."createdAt" desc
  limit p_limit;
$$;

grant execute on function public.feed_for_user(text, int) to anon, authenticated;
