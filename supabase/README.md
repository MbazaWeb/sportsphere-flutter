# Supabase

Project: `fffqjbrethogesgghjsn`

`20260819232000_full_app_schema.sql` is the full app migration (already applied).

Flutter uses `profiles`. Backend tables use PascalCase (`User`, `Post`, …).
Signup trigger writes both.

## Team logos

```bash
export SUPABASE_URL=...
export SUPABASE_SERVICE_ROLE_KEY=...
export DATABASE_URL=...
python scripts/fetch_team_logos.py
```

Sources: `supabase/team_logo_sources.json`
