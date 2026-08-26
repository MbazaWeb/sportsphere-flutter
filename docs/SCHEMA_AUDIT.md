# Playify — Schema Audit & Feature Confirmation
## Source: 40 migration files, 3 batches (2026-08-19 → 2026-08-25)

---

## ✅ USER FEATURES — ALL CONFIRMED IN SCHEMA

| Feature | Table(s) | Uniqueness guarantee | Notes |
|---|---|---|---|
| Register | `auth.users` → `on_auth_user_created` → `profiles` + `"User"` | `email` UNIQUE, `handle` UNIQUE + dedup suffix | Trigger never fails signUp |
| Login | Supabase Auth | JWT via `access_token` / `refresh_token` | `"User"."lastSeenAt"` updated |
| Guest mode | No DB row — app-side flag | N/A | Public SELECT on all content tables |
| Like post | `"PostLike"` PK(`postId`,`userId`) | Composite PK = no duplicates | `trg_post_like_count` auto-updates `"Post"."likeCount"` |
| Unlike post | DELETE `"PostLike"` | Same PK | `trg_post_like_count` decrements |
| Like comment | `"CommentLike"` PK(`commentId`,`userId`) | Composite PK | |
| Comment | `"Comment"` — `parentId` nullable for threading | No dup constraint — one user can post multiple comments | `trg_post_comment_count` auto-updates `commentCount` |
| DM / SMS | `"Message"` senderId+receiverId | No dup — DMs are a stream | Realtime via `supabase_realtime`, RLS: own only |
| Become a fan | `fans` PK(`fan_id`,`target_id`) + CHECK(`fan_id<>target_id`) | PK = no duplicates, no self-fan | snake_case table, `fanCount` updated |
| Follow | `"Follow"` PK(`followerId`,`followingId`) + CHECK no self-follow | PK + CHECK constraint | `trg_follow_notify` fires notification |
| Followed (receive) | `"Notification"` type=`follow` | — | `"User"."followerCount"` via `refresh_user_counts()` |
| Unfollow | DELETE `"Follow"` | PK prevents phantom rows | |
| Edit profile | UPDATE `profiles` + `"User"` | own-row RLS | All fields: bio, website, gender, nationality, DOB, cover, about |
| Update avatar | Supabase Storage `avatars` bucket → `"User"."avatarUrl"` + `profiles.avatar_url` | `sync_team_avatars_safe()` won't overwrite custom | 10 MB limit, WebP/JPEG/PNG |
| Upload image | Storage `posts` bucket | Path per post | Max 52 MB, image/jpeg/png/webp/gif |
| Upload video | Storage `media` bucket | Path per post | **100 MB** (bumped batch 3), all MIME types |
| Create post | `"Post"` — `likeCount/commentCount/shareCount` all trigger-maintained | `"postId"+"userId"` on like/share | Realtime via publication |
| Share post | `"PostShare"` PK(`postId`,`userId`) | PK = no dup shares | `trg_post_share_count` auto-updates |
| Poll | `"Poll"` UNIQUE(`postId`) + `"PollVote"` UNIQUE(`pollId`,`userId`) | One poll per post, one vote per user | `increment_poll_votes()` atomic (no race) |
| Prediction | `"Prediction"` with `outcome`(home/draw/away) | RLS blocks after match ends | Auto-settled by `trg_match_settle_predictions` |
| Nearby fans | `profiles.latitude/longitude` + `nearby_fans()` RPC | Excludes self | Haversine, 50km default radius |
| Join community | `"CommunityMember"` PK(`communityId`,`userId`) | PK = no dup | `join_community_atomic()` — race-free counter |
| Leave community | DELETE `"CommunityMember"` | PK | `leave_community_atomic()` |
| Become team fan | `entity_follows` UNIQUE(`follower_id`,`entity_type`,`entity_id`) | Composite UNIQUE | is_fan=true variant |
| Notifications | `"Notification"` — own-only RLS | — | Realtime, `my_notifications()` filtered |
| Push notification | `device_tokens` + `send-fcm` edge fn | UNIQUE(`user_id`,`token`) | FCM HTTP v1, RS256 JWT |

---

## ✅ UNIQUENESS — ALL ENFORCED AT DB LEVEL

| What | Constraint | Location |
|---|---|---|
| Email | UNIQUE index | `"User"."email"` |
| Handle | UNIQUE index | `"User"."handle"`, `profiles.handle` |
| No self-follow | CHECK constraint | `"Follow"` + `fans` |
| No duplicate follows | PK | `"Follow"(followerId,followingId)` |
| No duplicate likes | PK | `"PostLike"(postId,userId)` |
| No duplicate shares | PK | `"PostShare"(postId,userId)` |
| No duplicate poll votes | UNIQUE | `"PollVote"(pollId,userId)` |
| No duplicate news likes | PK | `news_likes(news_id,user_id)` |
| No duplicate community members | PK | `"CommunityMember"(communityId,userId)` |
| No duplicate entity follows | UNIQUE | `entity_follows(follower_id,entity_type,entity_id)` |
| One fan community per team | UNIQUE | `"Community"."teamId"` |
| One team per auth account | UNIQUE | `"Team"."accountUserId"` |
| One player per auth account | UNIQUE | `"Player"."accountUserId"` |
| One league per auth account | UNIQUE | `"League"."accountUserId"` |
| Device token uniqueness | UNIQUE | `device_tokens(user_id,token)` |
| Shop order idempotent payment | UNIQUE paymentRef | `"ShopOrder"."paymentRef"` |

---

## ✅ REALTIME — CONFIGURED FOR BIG TRAFFIC

Tables in `supabase_realtime` publication (REPLICA IDENTITY FULL):

| Table | Use case |
|---|---|
| `"Match"` | Live scores, minute updates |
| `"Post"` | Feed new posts |
| `"Comment"` | Live comment threads |
| `"PostLike"` | Like counts |
| `"Notification"` | Push-to-client notifications (use `userId=eq.<uid>` filter) |
| `"Message"` | DM delivery |
| `"Follow"` | Follower count updates |
| `fans` | Fan count updates |

---

## ✅ COUNTER INTEGRITY — TRIGGER-AUTHORITATIVE

All counters maintained by DB triggers (no app-level drift):

| Counter | Trigger | Fallback RPC |
|---|---|---|
| `"Post"."likeCount"` | `trg_post_like_count` | `increment_post_counter()` |
| `"Post"."commentCount"` | `trg_post_comment_count` | `increment_post_counter()` |
| `"Post"."shareCount"` | `trg_post_share_count` | `increment_post_counter()` |
| `"NewsItem"."likeCount"` | `trg_news_like_count` | — |
| `"NewsItem"."commentCount"` | `trg_news_comment_count` | — |
| `"Poll"."totalVotes"` | `increment_poll_votes()` RPC (atomic) | — |
| `"Community"."memberCount"` | `join/leave_community_atomic()` RPC | — |

---

## ✅ SECURITY — ALL CRITICAL ISSUES FIXED

| Issue | Fix |
|---|---|
| #9.10 Handle-squatting admin escalation | `is_app_admin()` checks role column ONLY |
| #9.10 Bulk handle-based admin promotion | Canonical admin by EMAIL only |
| #9.1 ShopOrder globally readable | `order_own_read`: buyer OR seller OR admin only |
| #9.1 ShopOrder UPDATE missing | `order_own_update` policy added |
| #9.2 Anon counter manipulation | `increment_post_counter`, `feed_for_user`, `count_fans_of`, `refresh_user_counts` revoked from anon |
| #9.3 news_likes no RLS/FK | FKs + full RLS added |
| #9.7 ClaimRequest no FKs | FK constraints to League/Team/Player/Coach |
| #9.9 Counter drift | DB triggers replace app-side increment |
| #9.11 Poll anyone can create | `auth.uid() is not null` required |
| #9.13 UserSport open write | Own-row only |
| #9.14 VerificationRequest open insert | Own userId required |
| #9.16 Post.communityId no FK | FK + ON DELETE SET NULL added |
| #9.17 "Follow" no self-follow check | CHECK constraint added + self-follows deleted |
| #9.19 Prediction.postId no FK | FK added |
| #9.21 Notification broadcast | `my_notifications()` RPC + realtime userId filter |
| #9.24 Share trigger coalesce bug | Fixed explicit if/else |
| #9.25 identity_sync overwrites | ON CONFLICT DO NOTHING |
| #9.31 Team avatar clobbers user | `sync_team_avatars_safe()` only fills NULL |
| #9.32 Realtime undefined_object | `_safe_add_to_realtime()` catches both exceptions |
| #9.34 News counter double-counting | Old INVOKER triggers dropped, SECURITY DEFINER only |
| C9 User table anon read | `user_public_read` restricted to `authenticated` |
| H1 Poll vote TOCTOU | `increment_poll_votes()` atomic insert+recount |
| H2 Community count TOCTOU | `join/leave_community_atomic()` atomic |
| H3 Order payment ownership | `confirm_order_paid()` checks ownership first |
| H9 approve/reject_claim no guard | `is_app_admin()` guard added to both |
| H10 M-Pesa client amount | `mpesa-stk-push` reads `amountTzs` from DB, ignores client |
| H11 User orphan on auth delete | `trg_cleanup_user_on_auth_delete` on `auth.users` |
| H12 23 missing FK indexes | All added |
| M22 Admin RPC no auth check | `approve_claim`/`reject_claim` hardened |

---

## ✅ EDGE FUNCTIONS — 8 DEPLOYED

| Function | Auth | Purpose |
|---|---|---|
| `admin-delete-user` | Admin JWT | Service-role delete + cascade cleanup |
| `send-fcm` | Authenticated | FCM HTTP v1, own devices or admin |
| `notify-followers` | Post author or admin | Inserts Notifications + sends FCM |
| `reject-claim` | Admin | Calls `reject_claim` RPC |
| `approve-claim` | Admin | Calls `approve_claim` RPC |
| `mpesa-stk-push` | Authenticated | STK Push — amount from DB only |
| `mpesa-callback` | Safaricom (Host+code verify) | Updates ShopOrder, 500 on error (retryable) |
| `ai-assistant` | Authenticated | Rate-limited 20/hr, Anthropic + DeepSeek |

---

## ✅ MEDIA / STORAGE

| Bucket | Max size | MIME types | Use |
|---|---|---|---|
| `avatars` | 10 MB | jpeg/png/webp/gif | Profile photos |
| `covers` | 10 MB | jpeg/png/webp | Profile cover images |
| `posts` | 52 MB | jpeg/png/webp/gif/mp4/quicktime/pdf | Post media |
| `media` | **100 MB** | All types | Long-form video, podcast audio |

---

## Scale Architecture Notes

For 100M users + live video + podcast + realtime scores:

1. **Database**: Supabase Postgres — all indexes in place, 23 FK indexes added (H12)
2. **Realtime**: `supabase_realtime` publication on 8 tables — use `filter: userId=eq.<uid>` on Notification channel to prevent broadcast
3. **Video/Podcast delivery**: Upload via `media` bucket (100 MB), serve via Cloudflare CDN (B2 Bandwidth Alliance = zero egress)
4. **Live scores**: `"Match"` in Realtime publication — Flutter subscribes with `filter: status=eq.live`
5. **Feed scoring**: `feed_for_user()` RPC — weighted by follows + fans + sports + recency
6. **FCM**: `device_tokens` table → `notify-followers` edge fn → Firebase HTTP v1
7. **M-Pesa**: `mpesa-stk-push` → `mpesa-callback` (Host verified, amount from DB)
8. **AI**: `ai-assistant` — Anthropic claude-3-5-haiku + DeepSeek, 20 calls/hr rate limit
9. **Identity**: `entity_follows` + claim flow for Team/Player/League entity accounts
10. **Counters**: All trigger-authoritative — no drift under high concurrency
