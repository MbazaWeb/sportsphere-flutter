# SportSphere Admin Console

Web admin for the SportSphere Flutter app. Uses the **same Supabase project** (Auth + REST + Storage).

## Pages

1. **Dashboard** — summary cards, charts, DB health  
2. **User Management** — roles, verify, claim approve/reject  
3. **SportSphere** — official posts / polls / predictions  
4. **League · Team · Player** — entity management  
5. **Match Updates** — create match, FT results, postpone  
6. **Posts & News** — moderation delete  
7. **Data Sync & APIs** — endpoint map shared with the mobile app  

## Run locally

```bash
cd admin
cp .env.example .env   # set VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```

Open http://localhost:5173  

Sign in with an official account (e.g. `official@sportsphere.app`).

## API

All data goes through Supabase:

- `profiles`, `User`, `Team`, `Match`, `Post`, `League`, `ClaimRequest`
- Flutter app reads the same tables for scores, feed, profiles, claims

Admin writes (results, deletes) require RLS policies that allow the signed-in admin/official role, or a service-role proxy for production.
