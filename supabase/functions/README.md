# SportSphere Edge Functions

These functions wrap SECURITY DEFINER RPCs already live in Postgres.

| Function | Method | Body | RPC |
|----------|--------|------|-----|
| `approve-claim` | POST | `{ claimId, reviewNotes? }` | `approve_claim` |
| `reject-claim` | POST | `{ claimId, reviewNotes? }` | `reject_claim` |
| `notify-followers` | POST | `{ authorId, title, body?, referenceId? }` | `notify_followers` |

## Deploy

```bash
supabase login
supabase link --project-ref fffqjbrethogesgghjsn
supabase functions deploy approve-claim
supabase functions deploy reject-claim
supabase functions deploy notify-followers
```

Until deployed, call RPCs directly from the app or admin:

```ts
await supabase.rpc('approve_claim', { p_claim_id: id, p_review_notes: 'ok' })
await supabase.rpc('notify_followers', { p_author_id: uid, p_title: 'New post', p_body: text, p_reference_id: postId })
```
