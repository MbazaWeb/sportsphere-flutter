-- Enable websocket (Realtime) for live scores + feed.
alter table public."Match" replica identity full;
alter table public."Post" replica identity full;
alter table public.posts replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public."Match";
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public."Post";
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.posts;
  exception when duplicate_object then null;
  end;
end $$;
