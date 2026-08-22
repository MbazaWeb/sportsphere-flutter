# Deploy Playify web

flutter build web --release --base-href /playify/ \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

Serve under http://104.152.50.173/playify/
