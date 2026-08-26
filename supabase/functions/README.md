# Playify Edge Functions

All functions require a valid JWT in the `Authorization: Bearer <token>` header
(except `mpesa-callback`, which is invoked by Safaricom and verified via
`Host` header + `BusinessShortCode` + optional bearer token).

CORS is **whitelisted**, not wildcarded. Set the `ALLOWED_ORIGINS` env var to a
comma-separated list of allowed origins (e.g.
`https://app.playify.com,https://admin.playify.com`). Requests with an
`Origin` header not in this list receive no `Access-Control-Allow-Origin`
header.

| Function | Method | Body | Notes |
|----------|--------|------|-------|
| `approve-claim` | POST | `{ claimId, reviewNotes? }` | Admin only. Calls `approve_claim` RPC. |
| `reject-claim` | POST | `{ claimId, reviewNotes? }` | Admin only. Calls `reject_claim` RPC. |
| `notify-followers` | POST | `{ post_id }` | Caller must be the post author or admin. Looks up author from `post_id`, inserts Notifications via `notify_followers` RPC, sends FCM to followers with device tokens. |
| `send-fcm` | POST | `{ user_id, title, body?, data? }` | Caller must own `user_id` or be admin. Sends FCM via Firebase service account. |
| `ai-assistant` | POST | `{ mode, prompt, provider }` | Authenticated users only. Rate-limited to 20 calls/hour/user. |
| `mpesa-stk-push` | POST | `{ order_id, phone }` | Authenticated. Amount is read from `ShopOrder.amountTzs` (NEVER trusted from client). |
| `mpesa-callback` | POST | (Safaricom callback body) | Invoked by Safaricom. Verifies Host header + BusinessShortCode. Returns 500 on error so Safaricom retries. |
| `admin-delete-user` | POST | `{ user_id }` | Admin only. Uses service-role key to delete the auth.users row; the `trg_cleanup_user_on_auth_delete` trigger cascade-deletes the `User` row. |

## Required env vars

- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- `ALLOWED_ORIGINS` (comma-separated whitelist of allowed CORS origins)
- `FIREBASE_SERVICE_ACCOUNT_JSON` (for `send-fcm`, `notify-followers`)
- `ANTHROPIC_API_KEY` and/or `DEEPSEEK_API_KEY` (for `ai-assistant`)
- `MPESA_CONSUMER_KEY`, `MPESA_CONSUMER_SECRET`, `MPESA_SHORTCODE`,
  `MPESA_PASSKEY`, `MPESA_ENV`, `MPESA_CALLBACK_URL`,
  `MPESA_CALLBACK_HOST` (comma-separated; verified against the `Host` header),
  `MPESA_CALLBACK_TOKEN` (optional bearer token Safaricom must present)

## Deploy

```bash
supabase login
supabase link --project-ref fffqjbrethogesgghjsn
supabase functions deploy approve-claim
supabase functions deploy reject-claim
supabase functions deploy notify-followers
supabase functions deploy send-fcm
supabase functions deploy ai-assistant
supabase functions deploy mpesa-stk-push
supabase functions deploy mpesa-callback
supabase functions deploy admin-delete-user
```

Until deployed, the existing RPCs can still be called directly from the app:

```ts
await supabase.rpc('approve_claim', { p_claim_id: id, p_review_notes: 'ok' })
await supabase.rpc('notify_followers', { p_author_id: uid, p_title: 'New post', p_body: text, p_reference_id: postId })
```

The `admin-delete-user` edge function replaces the client-side
`auth.admin.deleteUser()` call that fails with the anon key. Call it as:

```ts
await supabase.functions.invoke('admin-delete-user', { body: { user_id: uid } })
```
