-- Add outcome column to Prediction table
alter table public."Prediction"
  add column if not exists "outcome" text check ("outcome" in ('home', 'draw', 'away'));

-- Backfill existing predictions from predictedHome/predictedAway scores
update public."Prediction"
set "outcome" = case
  when "predictedHome" > "predictedAway" then 'home'
  when "predictedHome" < "predictedAway" then 'away'
  else 'draw'
end
where "outcome" is null
  and "predictedHome" is not null
  and "predictedAway" is not null;

-- Settlement function: derive result from final match score
create or replace function public.settle_predictions_for_match(p_match_id text)
returns void language plpgsql security definer as $$
declare
  v_home_score int;
  v_away_score int;
  v_result text;
begin
  select "homeScore", "awayScore"
  into v_home_score, v_away_score
  from public."Match"
  where id = p_match_id;

  if not found then return; end if;

  v_result := case
    when v_home_score > v_away_score then 'home'
    when v_home_score < v_away_score then 'away'
    else 'draw'
  end;

  update public."Prediction"
  set
    "result"    = v_result,
    "isCorrect" = ("outcome" = v_result)
  where "matchId" = p_match_id
    and "outcome" is not null
    and "result" is null;
end;
$$;
