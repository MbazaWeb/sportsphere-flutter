-- Team entities become real account profiles (Auth + profiles + User + TeamProfile).
-- Applied via Admin API for 46 seeded teams. Password for all: Test123
-- Login: handle e.g. simba_sc  OR email simba-sc@teams.sportsphere.test

alter table public."Team" add column if not exists "accountUserId" text;
