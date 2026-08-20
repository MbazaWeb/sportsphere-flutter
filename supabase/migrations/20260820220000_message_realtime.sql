
-- Realtime for DMs
do $$
begin
  begin
    alter publication supabase_realtime add table public."Message";
  exception when duplicate_object then null;
  end;
end $$;

-- Replica identity full for postgres_changes filters if needed
alter table public."Message" replica identity full;
