-- =============================================================================
-- Fix Top-3 Critical Security Issues (scan ref: #9.10, #9.1, #9.2)
-- =============================================================================
-- #9.10  Handle-squatting privilege escalation
--        `is_app_admin()` was granting admin powers to ANY account whose
--        handle matched a legacy alias list (sportsphere_app, playify_app, ...).
--        Combined with the bulk UPDATE that set role='admin' for the same
--        handle list, anyone who registered with one of those handles was
--        auto-promoted on the next migration re-run.
--
-- #9.1   ShopOrder readable by anyone (anon)
--        `order_own_read` policy used `using (auth.uid()::text = "userId" or true)`
--        which is effectively `using(true)` — anon & any authenticated user
--        could dump every order row (payment method, payment ref, amount,
--        buyer identity).
--
-- #9.2   Anonymous post-counter manipulation
--        `increment_post_counter` (SECURITY DEFINER) was granted to anon —
--        anonymous callers could bump likeCount/commentCount/shareCount/
--        viewCount by arbitrary deltas on any post. Same issue applied to
--        `refresh_user_counts`, `count_fans_of`, `feed_for_user`.
--
-- All changes are IDEMPOTENT and safe to re-run.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- FIX #9.10 — Strip handle-based admin grant from is_app_admin()
-- -----------------------------------------------------------------------------
-- The role column on profiles/User is the single source of truth for admin
-- powers. Handles can be squat; verified emails cannot (Supabase auth flow).
-- The bulk UPDATE that follows still promotes the canonical Playify account,
-- but only by EMAIL match — not by handle.

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and lower(coalesce(p.role, '')) in ('admin', 'official', 'organization', 'moderator')
      )
      or exists (
        select 1 from public."User" u
        where u.id = auth.uid()::text
          and lower(coalesce(u.role, '')) in ('admin', 'official', 'organization', 'moderator')
      )
    );
$$;

-- Function signature did not change, but grant must persist after CREATE OR REPLACE.
grant execute on function public.is_app_admin() to authenticated, anon, service_role;


-- -----------------------------------------------------------------------------
-- FIX #9.10 — Promote ONLY the canonical Playify account, by verified email
-- -----------------------------------------------------------------------------
-- Previously: matched by handle list → squatting risk.
-- Now:        matched ONLY by the two known verified owner emails.
--             Handle-based matching is removed entirely. Anyone who registered
--             with handle='playify_app' or 'sportsphere_app' will NO LONGER
--             be promoted; their role remains whatever they signed up with.

update public.profiles
set role = 'admin',
    is_verified = true
where lower(coalesce(email, '')) in (
  'playify@playify.com',
  'sportsphere.app@sportsphere.com'
);

update public."User"
set role = 'admin',
    "isVerified" = true,
    "verificationStatus" = 'verified'
where lower(coalesce(email, '')) in (
  'playify@playify.com',
  'sportsphere.app@sportsphere.com'
);

-- Demote any non-canonical account that was previously auto-promoted by
-- handle-squatting. We only demote accounts whose email is NOT one of the two
-- canonical owner emails AND whose handle is in the legacy alias list. This
-- reverts the privilege escalation without touching genuine admins.
update public.profiles
set role = 'fan',
    is_verified = false
where lower(coalesce(email, '')) not in (
  'playify@playify.com',
  'sportsphere.app@sportsphere.com'
)
  and lower(coalesce(handle, '')) in (
    'sportsphere', 'sportsphere_official', 'sportsphere_app',
    'playify', 'playify_official', 'playify_app'
  )
  and lower(coalesce(role, '')) = 'admin';

update public."User"
set role = 'fan',
    "isVerified" = false,
    "verificationStatus" = 'unverified'
where lower(coalesce(email, '')) not in (
  'playify@playify.com',
  'sportsphere.app@sportsphere.com'
)
  and lower(coalesce(handle, '')) in (
    'sportsphere', 'sportsphere_official', 'sportsphere_app',
    'playify', 'playify_official', 'playify_app'
  )
  and lower(coalesce(role, '')) = 'admin';


-- -----------------------------------------------------------------------------
-- FIX #9.1 — ShopOrder: restrict read to buyer, seller, admin
-- -----------------------------------------------------------------------------
-- Buyer:   auth.uid() = "userId"
-- Seller:  auth.uid()'s handle matches "sellerHandle"
-- Admin:   is_app_admin()

drop policy if exists "order_own_read" on public."ShopOrder";
create policy "order_own_read" on public."ShopOrder"
  for select to authenticated
  using (
    auth.uid()::text = "userId"
    or exists (
      select 1
      from public."User" u
      where u.id = auth.uid()::text
        and u.handle is not null
        and lower(u.handle) = lower(coalesce("ShopOrder"."sellerHandle", ''))
    )
    or public.is_app_admin()
  );

-- Anon is intentionally NOT granted SELECT — they have no business reading
-- payment records. (Original policy allowed anon via `or true`.)


-- -----------------------------------------------------------------------------
-- FIX #9.1 (cont.) — ShopOrder UPDATE policy
-- -----------------------------------------------------------------------------
-- The original migration defined only SELECT and INSERT policies. UPDATE was
-- missing entirely, so `confirmOrderPaid(orderId)` in commerce_repository.dart
-- silently failed RLS. Add an UPDATE policy mirroring the SELECT scope:
-- buyer can update their own order; admin can update any.

drop policy if exists "order_own_update" on public."ShopOrder";
create policy "order_own_update" on public."ShopOrder"
  for update to authenticated
  using (
    auth.uid()::text = "userId"
    or public.is_app_admin()
  )
  with check (
    auth.uid()::text = "userId"
    or public.is_app_admin()
  );


-- -----------------------------------------------------------------------------
-- FIX #9.2 — Revoke anon from SECURITY DEFINER counter / feed RPCs
-- -----------------------------------------------------------------------------
-- These functions mutate counters or fetch user-scoped data. Granting them
-- to anon enables counter manipulation, cheap DoS via refresh storms, and
-- anonymous feed scraping. All Flutter callers are authenticated, so anon
-- access is not needed.

-- increment_post_counter — bumps likeCount/commentCount/shareCount/viewCount
revoke execute on function public.increment_post_counter(text, text, int) from anon;
grant  execute on function public.increment_post_counter(text, text, int) to authenticated, service_role;

-- refresh_user_counts — recomputes follower/following/fan/post counts for any uid
revoke execute on function public.refresh_user_counts(text) from anon;
grant  execute on function public.refresh_user_counts(text) to authenticated, service_role;

-- count_fans_of — fan count for any target uid
revoke execute on function public.count_fans_of(text) from anon;
grant  execute on function public.count_fans_of(text) to authenticated, service_role;

-- feed_for_user — full personalized feed (post bodies, media urls)
revoke execute on function public.feed_for_user(text, int) from anon;
grant  execute on function public.feed_for_user(text, int) to authenticated, service_role;


-- -----------------------------------------------------------------------------
-- Verification helpers (run manually after applying migration to confirm)
-- -----------------------------------------------------------------------------
-- select proname, proacl from pg_proc
--  where proname in (
--    'is_app_admin','increment_post_counter','refresh_user_counts',
--    'count_fans_of','feed_for_user'
--  );
--
-- select polname, polqual from pg_policy
--  where polrelid = 'public."ShopOrder"'::regclass;
--
-- select handle, email, role, is_verified from public.profiles
--  where lower(coalesce(handle,'')) in
--    ('sportsphere','sportsphere_official','sportsphere_app',
--     'playify','playify_official','playify_app');
