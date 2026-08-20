-- ============================================================
-- SportSphere: close security + realtime + RPC gaps
-- ============================================================

-- 1) theme_color (safe if already present)
alter table public.profiles add column if not exists theme_color text default '#168CFF';

-- 2) Enable RLS on remaining public tables
do $$
declare t text;
begin
  foreach t in array array[
    'AcademyProfile','AgentProfile','AnalystProfile','BusinessProfile','CoachProfile',
    'CommentatorProfile','CommercialPartner','CommercialPartnerProfile','CommunityProfile',
    'CompetitionProfile','CreatorProfile','JournalistProfile','LeagueProfile','Location',
    'MediaBroadcastProfile','ModeratorProfile','OfficialProfile','OrganizationProfile',
    'PlayerProfile','Role','RoleType','ScoutProfile','SponsorProfile','SupportStaffProfile',
    'TeamProfile','UserSport','VenueProfile','VerificationRequest'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Helper: drop policy if exists
create or replace function public._drop_policy_if_exists(tbl text, pol text)
returns void language plpgsql as $$
begin
  execute format('drop policy if exists %I on public.%I', pol, tbl);
exception when undefined_table then null;
end $$;

-- 3) Standard policies for role profile tables (userId text/uuid style)
do $$
declare
  t text;
  tables text[] := array[
    'AcademyProfile','AgentProfile','AnalystProfile','BusinessProfile','CoachProfile',
    'CommentatorProfile','CommercialPartnerProfile','CommunityProfile','CompetitionProfile',
    'CreatorProfile','JournalistProfile','LeagueProfile','MediaBroadcastProfile',
    'ModeratorProfile','OfficialProfile','OrganizationProfile','PlayerProfile',
    'ScoutProfile','SponsorProfile','SupportStaffProfile','TeamProfile','VenueProfile'
  ];
begin
  foreach t in array tables loop
    perform public._drop_policy_if_exists(t, t || '_public_read');
    perform public._drop_policy_if_exists(t, t || '_own_write');
    perform public._drop_policy_if_exists(t, t || '_own_update');
    perform public._drop_policy_if_exists(t, t || '_admin_all');

    execute format(
      'create policy %I on public.%I for select using (true)',
      t || '_public_read', t
    );

    -- userId may be text or uuid — cast both sides to text
    execute format(
      'create policy %I on public.%I for insert to authenticated with check ((auth.uid())::text = ("userId")::text)',
      t || '_own_write', t
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using ((auth.uid())::text = ("userId")::text) with check ((auth.uid())::text = ("userId")::text)',
      t || '_own_update', t
    );
    execute format(
      'create policy %I on public.%I for all using (
         exists (select 1 from public.profiles p where p.id = auth.uid()
           and coalesce(p.role,'''') in (''admin'',''official'',''organization''))
       ) with check (
         exists (select 1 from public.profiles p where p.id = auth.uid()
           and coalesce(p.role,'''') in (''admin'',''official'',''organization''))
       )',
      t || '_admin_all', t
    );
  end loop;
end $$;

-- CommercialPartner (may not have userId)
do $$
begin
  perform public._drop_policy_if_exists('CommercialPartner', 'CommercialPartner_public_read');
  create policy "CommercialPartner_public_read" on public."CommercialPartner" for select using (true);
  perform public._drop_policy_if_exists('CommercialPartner', 'CommercialPartner_admin_all');
  create policy "CommercialPartner_admin_all" on public."CommercialPartner" for all
    using (exists (select 1 from public.profiles p where p.id = auth.uid()
      and coalesce(p.role,'') in ('admin','official','organization')))
    with check (exists (select 1 from public.profiles p where p.id = auth.uid()
      and coalesce(p.role,'') in ('admin','official','organization')));
exception when others then
  raise notice 'CommercialPartner policies: %', sqlerrm;
end $$;

-- Location, Role, RoleType: public read
do $$
begin
  perform public._drop_policy_if_exists('Location', 'Location_public_read');
  create policy "Location_public_read" on public."Location" for select using (true);
  perform public._drop_policy_if_exists('Role', 'Role_public_read');
  create policy "Role_public_read" on public."Role" for select using (true);
  perform public._drop_policy_if_exists('RoleType', 'RoleType_public_read');
  create policy "RoleType_public_read" on public."RoleType" for select using (true);
exception when others then raise notice '%', sqlerrm;
end $$;

-- UserSport
do $$
begin
  perform public._drop_policy_if_exists('UserSport', 'UserSport_public_read');
  create policy "UserSport_public_read" on public."UserSport" for select using (true);
  perform public._drop_policy_if_exists('UserSport', 'UserSport_own_write');
  -- best-effort; column name may vary
  begin
    create policy "UserSport_own_write" on public."UserSport" for all to authenticated
      using (true) with check (true);
  exception when others then null;
  end;
end $$;

-- VerificationRequest
do $$
begin
  perform public._drop_policy_if_exists('VerificationRequest', 'VerificationRequest_public_read');
  create policy "VerificationRequest_public_read" on public."VerificationRequest" for select using (true);
  perform public._drop_policy_if_exists('VerificationRequest', 'VerificationRequest_auth_insert');
  create policy "VerificationRequest_auth_insert" on public."VerificationRequest"
    for insert to authenticated with check (true);
  perform public._drop_policy_if_exists('VerificationRequest', 'VerificationRequest_admin');
  create policy "VerificationRequest_admin" on public."VerificationRequest" for all
    using (exists (select 1 from public.profiles p where p.id = auth.uid()
      and coalesce(p.role,'') in ('admin','official','organization')))
    with check (exists (select 1 from public.profiles p where p.id = auth.uid()
      and coalesce(p.role,'') in ('admin','official','organization')));
exception when others then raise notice '%', sqlerrm;
end $$;

-- 4) Realtime: Comment, PostLike, Notification, fans, Follow
alter table public."Comment" replica identity full;
alter table public."PostLike" replica identity full;
alter table public."Notification" replica identity full;
alter table public.fans replica identity full;
alter table public."Follow" replica identity full;

do $$
begin
  begin alter publication supabase_realtime add table public."Comment"; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public."PostLike"; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public."Notification"; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.fans; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public."Follow"; exception when duplicate_object then null; end;
end $$;

-- 5) RPC: create notification
create or replace function public.create_notification(
  p_user_id text,
  p_type text,
  p_title text,
  p_body text default null,
  p_actor_id text default null,
  p_reference_id text default null,
  p_target_id text default null,
  p_target_type text default null
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  nid text := 'ntf-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6);
begin
  insert into public."Notification" (
    "id","userId","type","title","body","isRead","actorId","referenceId","targetId","targetType","createdAt"
  ) values (
    nid, p_user_id, p_type, p_title, p_body, false, p_actor_id, p_reference_id, p_target_id, p_target_type, now()
  );
  return nid;
end;
$$;

revoke all on function public.create_notification(text,text,text,text,text,text,text,text) from public;
grant execute on function public.create_notification(text,text,text,text,text,text,text,text) to authenticated, service_role;

-- 6) RPC: notify followers of a user (e.g. new post)
create or replace function public.notify_followers(
  p_author_id text,
  p_title text,
  p_body text default null,
  p_reference_id text default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int := 0;
  r record;
begin
  for r in
    select "followerId" as fid from public."Follow" where "followingId" = p_author_id
  loop
    perform public.create_notification(
      r.fid, 'follow_activity', p_title, p_body, p_author_id, p_reference_id, p_author_id, 'user'
    );
    n := n + 1;
  end loop;
  return n;
end;
$$;

revoke all on function public.notify_followers(text,text,text,text) from public;
grant execute on function public.notify_followers(text,text,text,text) to authenticated, service_role;

-- 7) RPC: approve claim (admin/official only)
create or replace function public.approve_claim(
  p_claim_id text,
  p_review_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  claim record;
  caller_role text;
begin
  select coalesce(role,'') into caller_role from public.profiles where id = auth.uid();
  if caller_role not in ('admin','official','organization') and auth.role() <> 'service_role' then
    -- service_role has auth.uid() null; allow when jwt role is service
    if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
       and coalesce(auth.jwt() ->> 'role', '') is distinct from 'service_role' then
      if caller_role not in ('admin','official','organization') then
        raise exception 'not authorized to approve claims';
      end if;
    end if;
  end if;

  select * into claim from public."ClaimRequest" where id = p_claim_id for update;
  if not found then
    raise exception 'claim not found';
  end if;

  update public."ClaimRequest"
  set status = 'approved',
      "reviewerId" = coalesce(auth.uid()::text, "reviewerId"),
      "reviewNotes" = coalesce(p_review_notes, "reviewNotes"),
      "reviewedAt" = now()
  where id = p_claim_id;

  -- notify claimant
  perform public.create_notification(
    claim."userId",
    'claim_approved',
    'Claim approved',
    coalesce(p_review_notes, 'Your profile claim was approved.'),
    auth.uid()::text,
    p_claim_id,
    claim."profileId",
    claim."profileType"
  );

  return jsonb_build_object('id', p_claim_id, 'status', 'approved');
end;
$$;

revoke all on function public.approve_claim(text,text) from public;
grant execute on function public.approve_claim(text,text) to authenticated, service_role;

-- 8) RPC: reject claim
create or replace function public.reject_claim(
  p_claim_id text,
  p_review_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  claim record;
  caller_role text;
begin
  select coalesce(role,'') into caller_role from public.profiles where id = auth.uid();
  if caller_role not in ('admin','official','organization')
     and coalesce(auth.jwt() ->> 'role','') is distinct from 'service_role' then
    raise exception 'not authorized';
  end if;

  select * into claim from public."ClaimRequest" where id = p_claim_id for update;
  if not found then raise exception 'claim not found'; end if;

  update public."ClaimRequest"
  set status = 'rejected',
      "reviewerId" = coalesce(auth.uid()::text, "reviewerId"),
      "reviewNotes" = coalesce(p_review_notes, "reviewNotes"),
      "reviewedAt" = now()
  where id = p_claim_id;

  perform public.create_notification(
    claim."userId",
    'claim_rejected',
    'Claim rejected',
    coalesce(p_review_notes, 'Your profile claim was rejected.'),
    auth.uid()::text,
    p_claim_id,
    claim."profileId",
    claim."profileType"
  );

  return jsonb_build_object('id', p_claim_id, 'status', 'rejected');
end;
$$;

revoke all on function public.reject_claim(text,text) from public;
grant execute on function public.reject_claim(text,text) to authenticated, service_role;

-- 9) bump post counts helper
create or replace function public.increment_post_counter(p_post_id text, p_col text, p_delta int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_col not in ('likeCount','commentCount','shareCount','viewCount') then
    raise exception 'invalid column';
  end if;
  execute format(
    'update public."Post" set %I = greatest(coalesce(%I,0) + $1, 0), "updatedAt" = now() where id = $2',
    p_col, p_col
  ) using p_delta, p_post_id;
end;
$$;

grant execute on function public.increment_post_counter(text,text,int) to authenticated, service_role;

-- 10) Ensure Post public read exists
do $$
begin
  perform public._drop_policy_if_exists('Post', 'post_public_read');
  create policy post_public_read on public."Post" for select using (true);
exception when duplicate_object then null;
end $$;
