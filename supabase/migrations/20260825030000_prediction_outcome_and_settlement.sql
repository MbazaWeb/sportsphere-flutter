-- =============================================================================
-- PART K (rules 43-46): Predictions — outcome storage + auto-close on match end
-- =============================================================================
-- Requirements from the master spec:
--
--   43. Predictions must use HOME / X / AWAY labels (not team names).
--   44. Store the semantic result (HOME / DRAW / AWAY), not team names.
--   45. Predictions must auto-close when the match ends. Backend must reject
--       late predictions.
--   46. Result calculation uses final score:
--         home_score > away_score → HOME
--         home_score == away_score → X (draw)
--         home_score < away_score → AWAY
--       Then close predictions, determine correct ones, apply scoring, prevent
--       new predictions.
--
-- This migration:
--
--   1. Adds an `outcome` column to Prediction ('home' | 'draw' | 'away').
--      This is the semantic prediction the user made. It's stored alongside
--      predictedHome/predictedAway (which remain for scoreline predictions).
--   2. Adds a `closedAt` column to Prediction. When non-null, the prediction
--      is closed and no further mutations are allowed.
--   3. Adds a trigger on "Match" that fires AFTER UPDATE when status transitions
--      to 'ft'/'finished'/'full time'. The trigger:
--        a. Sets Prediction.closedAt for all predictions linked to that match.
--        b. Computes the result from homeScore/awayScore.
--        c. Stores the result in Prediction.result.
--        d. Sets Prediction.isCorrect = (Prediction.outcome == result).
--   4. Adds an RLS INSERT check on Prediction that rejects new rows when the
--      linked match is already finished.
-- =============================================================================

-- ── 1. Add `outcome` column to Prediction ───────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'Prediction'
      and column_name = 'outcome'
  ) then
    alter table public."Prediction" add column outcome text;
    comment on column public."Prediction".outcome is
      'Semantic prediction: home | draw | away. Stored alongside predictedHome/predictedAway for backward compat.';
  end if;
end$$;

-- ── 2. Add `closedAt` column to Prediction ──────────────────────────────────
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'Prediction'
      and column_name = 'closedAt'
  ) then
    alter table public."Prediction" add column "closedAt" timestamptz;
    comment on column public."Prediction"."closedAt" is
      'When non-null, the prediction is closed (match ended). No further mutations allowed.';
  end if;
end$$;

-- ── 3. Function: settle_match_predictions(p_match_id text) ──────────────────
-- Computes the match result from homeScore/awayScore, sets Prediction.result,
-- Prediction.isCorrect, Prediction.closedAt for all predictions linked to the
-- match. Idempotent — safe to call multiple times.

create or replace function public.settle_match_predictions(p_match_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_home_score int;
  v_away_score int;
  v_status text;
  v_result text;
  v_is_finished boolean := false;
begin
  -- Fetch the match
  select "homeScore", "awayScore", status
  into v_home_score, v_away_score, v_status
  from public."Match"
  where id = p_match_id;

  if not found then
    raise notice 'Match % not found — skipping settlement', p_match_id;
    return;
  end if;

  -- Determine if the match is finished
  v_is_finished := v_status in ('ft', 'finished', 'full time');

  if not v_is_finished then
    raise notice 'Match % not finished (status=%) — skipping', p_match_id, v_status;
    return;
  end if;

  -- Compute the result from the final score
  if v_home_score is null or v_away_score is null then
    raise notice 'Match % has no final score — skipping', p_match_id;
    return;
  end if;

  if v_home_score > v_away_score then
    v_result := 'home';
  elsif v_home_score = v_away_score then
    v_result := 'draw';
  else
    v_result := 'away';
  end if;

  -- Settle all predictions for this match
  update public."Prediction"
     set result = v_result,
         "isCorrect" = (outcome = v_result),
         "closedAt" = coalesce("closedAt", now())
   where "matchId" = p_match_id
     and "closedAt" is null;

  raise notice 'Settled predictions for match % (result=%)', p_match_id, v_result;
end;
$$;

-- ── 4. Trigger: settle predictions when Match status → finished ─────────────
create or replace function public.trg_settle_match_predictions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_finished boolean;
  v_new_finished boolean;
begin
  v_old_finished := coalesce(OLD.status in ('ft', 'finished', 'full time'), false);
  v_new_finished := coalesce(NEW.status in ('ft', 'finished', 'full time'), false);

  -- Only fire when the match transitions TO finished (not on every update)
  if v_new_finished and not v_old_finished then
    perform public.settle_match_predictions(NEW.id);
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_match_settle_predictions on public."Match";
create trigger trg_match_settle_predictions
  after update of status on public."Match"
  for each row
  execute function public.trg_settle_match_predictions();

-- ── 5. RLS: block new predictions when the linked match is finished ─────────
-- Drop the old INSERT policy and recreate it with a check.
do $$
begin
  drop policy if exists "pred_own_create" on public."Prediction";
exception when others then null;
end$$;

-- The new policy allows INSERT only when:
--   1. The user is creating their own prediction (auth.uid()::text = "userId")
--   2. AND the linked match (if any) is not yet finished
create policy "pred_own_create" on public."Prediction"
  for insert to authenticated
  with check (
    auth.uid()::text = "userId"
    and (
      "matchId" is null
      or not exists (
        select 1 from public."Match" m
        where m.id = "matchId"
          and m.status in ('ft', 'finished', 'full time')
      )
    )
  );

-- ── 6. RLS: block prediction updates when closed ───────────────────────────
do $$
begin
  drop policy if exists "pred_own_update" on public."Prediction";
exception when others then null;
end$$;

create policy "pred_own_update" on public."Prediction"
  for update to authenticated
  using (auth.uid()::text = "userId" and "closedAt" is null)
  with check (auth.uid()::text = "userId" and "closedAt" is null);

-- ── 7. Grant execute on the settle function ────────────────────────────────
grant execute on function public.settle_match_predictions(text) to authenticated;
grant execute on function public.trg_settle_match_predictions() to authenticated;

-- ── 8. Backfill: settle any already-finished matches ──────────────────────
do $$
declare
  m record;
begin
  for m in
    select id from public."Match"
    where status in ('ft', 'finished', 'full time')
  loop
    perform public.settle_match_predictions(m.id);
  end loop;
end$$;
