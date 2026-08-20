-- SportSphere composable taxonomy (not one giant enum)

create table if not exists public.taxonomy_term (
  domain text not null,
  slug text not null,
  label text not null,
  parent_slug text,
  sort_order int not null default 0,
  primary key (domain, slug)
);

create index if not exists taxonomy_term_domain_idx on public.taxonomy_term (domain);

alter table public.taxonomy_term enable row level security;
drop policy if exists taxonomy_term_read on public.taxonomy_term;
create policy taxonomy_term_read on public.taxonomy_term for select using (true);
drop policy if exists taxonomy_term_admin on public.taxonomy_term;
create policy taxonomy_term_admin on public.taxonomy_term for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid()
    and coalesce(p.role,'') in ('admin','official','organization')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid()
    and coalesce(p.role,'') in ('admin','official','organization')));

insert into public.taxonomy_term (domain, slug, label, parent_slug, sort_order) values
-- competitive_level
('competitive_level','professional','Professional',null,10),
('competitive_level','semi_professional','Semi-professional',null,20),
('competitive_level','amateur','Amateur',null,30),
('competitive_level','recreational','Recreational',null,40),
-- organization_type
('organization_type','club','Club',null,10),
('organization_type','academy','Academy',null,20),
('organization_type','university','University',null,30),
('organization_type','college','College',null,40),
('organization_type','school','School',null,50),
('organization_type','community','Community',null,60),
('organization_type','company','Company',null,70),
('organization_type','organization','Organization',null,80),
('organization_type','national_association','National association',null,90),
('organization_type','national_team','National team',null,100),
('organization_type','regional_association','Regional association',null,110),
-- gender
('gender','men','Men',null,10),
('gender','women','Women',null,20),
('gender','mixed','Mixed',null,30),
('gender','open','Open',null,40),
-- age_category
('age_category','u7','U7',null,7),
('age_category','u9','U9',null,9),
('age_category','u11','U11',null,11),
('age_category','u13','U13',null,13),
('age_category','u15','U15',null,15),
('age_category','u17','U17',null,17),
('age_category','u18','U18',null,18),
('age_category','u20','U20',null,20),
('age_category','u21','U21',null,21),
('age_category','u23','U23',null,23),
('age_category','senior','Senior',null,50),
('age_category','veteran','Veteran',null,60),
('age_category','masters','Masters',null,70),
('age_category','university','University',null,40),
-- geographic_scope
('geographic_scope','local','Local',null,10),
('geographic_scope','community','Community',null,20),
('geographic_scope','district','District',null,30),
('geographic_scope','city','City',null,40),
('geographic_scope','regional','Regional',null,50),
('geographic_scope','national','National',null,60),
('geographic_scope','continental','Continental',null,70),
('geographic_scope','international','International',null,80),
('geographic_scope','global','Global',null,90),
-- player_type
('player_type','professional','Professional player',null,10),
('player_type','semi_professional','Semi-professional player',null,20),
('player_type','amateur','Amateur player',null,30),
('player_type','university','University / college player',null,40),
('player_type','school','School player',null,50),
('player_type','academy','Academy player',null,60),
('player_type','community','Community player',null,70),
('player_type','youth','Youth player',null,80),
('player_type','veteran','Veteran player',null,90),
('player_type','recreational','Recreational player',null,100),
-- sport (top)
('sport','football','Football',null,10),
('sport','basketball','Basketball',null,20),
('sport','tennis','Tennis',null,30),
('sport','athletics','Athletics',null,40),
('sport','volleyball','Volleyball',null,50),
('sport','rugby','Rugby',null,60),
('sport','cricket','Cricket',null,70),
('sport','boxing','Boxing',null,80),
('sport','mma','MMA',null,90),
('sport','swimming','Swimming',null,100),
('sport','cycling','Cycling',null,110),
('sport','motorsport','Motorsport',null,120),
('sport','golf','Golf',null,130),
('sport','hockey','Hockey',null,140),
('sport','handball','Handball',null,150),
('sport','netball','Netball',null,160),
('sport','badminton','Badminton',null,170),
('sport','table_tennis','Table tennis',null,180),
('sport','wrestling','Wrestling',null,190),
('sport','esports','Esports',null,200),
-- sport variants
('sport_variant','association_football','Association football','football',10),
('sport_variant','futsal','Futsal','football',20),
('sport_variant','beach_soccer','Beach soccer','football',30),
('sport_variant','seven_a_side','Seven-a-side','football',40),
('sport_variant','five_a_side','Five-a-side','football',50),
('sport_variant','basketball_5v5','Basketball 5v5','basketball',10),
('sport_variant','basketball_3x3','3x3 basketball','basketball',20),
('sport_variant','wheelchair_basketball','Wheelchair basketball','basketball',40),
-- competition_type
('competition_type','league','League',null,10),
('competition_type','cup','Cup',null,20),
('competition_type','tournament','Tournament',null,30),
('competition_type','championship','Championship',null,40),
('competition_type','playoffs','Playoffs',null,50),
('competition_type','knockout','Knockout',null,60),
('competition_type','friendly','Friendly',null,70),
('competition_type','qualifier','Qualifier',null,80),
('competition_type','super_cup','Super cup',null,90),
('competition_type','exhibition','Exhibition',null,100),
('competition_type','season','Season',null,110),
('competition_type','meet','Meet',null,120),
('competition_type','race','Race',null,130),
('competition_type','event','Event',null,140),
-- competition_format
('competition_format','single_match','Single match',null,10),
('competition_format','home_and_away','Home & away',null,20),
('competition_format','round_robin','Round robin',null,30),
('competition_format','league','League',null,40),
('competition_format','group_stage','Group stage',null,50),
('competition_format','knockout','Knockout',null,60),
('competition_format','single_elimination','Single elimination',null,70),
('competition_format','double_elimination','Double elimination',null,80),
('competition_format','swiss','Swiss system',null,90),
('competition_format','best_of_3','Best of 3',null,100),
('competition_format','best_of_5','Best of 5',null,110),
('competition_format','points','Points based',null,120),
-- competition_level
('competition_level','international','International',null,10),
('competition_level','continental','Continental',null,20),
('competition_level','national','National',null,30),
('competition_level','regional','Regional',null,40),
('competition_level','district','District',null,50),
('competition_level','city','City',null,60),
('competition_level','university','University',null,70),
('competition_level','college','College',null,80),
('competition_level','school','School',null,90),
('competition_level','community','Community',null,100),
('competition_level','corporate','Corporate',null,110)
on conflict (domain, slug) do update set label = excluded.label, parent_slug = excluded.parent_slug, sort_order = excluded.sort_order;

-- Entity columns
alter table public."Team" add column if not exists competitive_level text default 'professional';
alter table public."Team" add column if not exists organization_type text default 'club';
alter table public."Team" add column if not exists gender text default 'men';
alter table public."Team" add column if not exists age_category text default 'senior';
alter table public."Team" add column if not exists geographic_scope text default 'national';
alter table public."Team" add column if not exists sport_slug text default 'football';
alter table public."Team" add column if not exists sport_variant text default 'association_football';

alter table public."Player" add column if not exists player_type text default 'professional';
alter table public."Player" add column if not exists gender text;
alter table public."Player" add column if not exists age_category text default 'senior';
alter table public."Player" add column if not exists career_level text default 'professional';
alter table public."Player" add column if not exists sport_slug text default 'football';

alter table public."League" add column if not exists competitive_level text default 'professional';
alter table public."League" add column if not exists gender text default 'men';
alter table public."League" add column if not exists age_category text default 'senior';
alter table public."League" add column if not exists geographic_scope text default 'national';
alter table public."League" add column if not exists competition_type text default 'league';
alter table public."League" add column if not exists competition_format text default 'league';
alter table public."League" add column if not exists competition_level text default 'national';
alter table public."League" add column if not exists sport_slug text default 'football';

alter table public."Sport" add column if not exists sport_slug text;
alter table public."Sport" add column if not exists parent_sport_slug text;

create table if not exists public."Competition" (
  id text primary key,
  name text not null,
  slug text unique,
  sport_slug text default 'football',
  sport_variant text,
  competition_type text default 'tournament',
  competition_format text default 'group_stage',
  competition_level text default 'national',
  gender text default 'men',
  age_category text default 'senior',
  geographic_scope text default 'national',
  country text,
  season text,
  league_id text,
  logo_url text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public."Competition" enable row level security;
drop policy if exists competition_public_read on public."Competition";
create policy competition_public_read on public."Competition" for select using (true);
drop policy if exists competition_admin on public."Competition";
create policy competition_admin on public."Competition" for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid()
    and coalesce(p.role,'') in ('admin','official','organization')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid()
    and coalesce(p.role,'') in ('admin','official','organization')));

-- Seed NBC / national defaults
update public."Team"
set competitive_level = 'professional',
    organization_type = 'club',
    gender = 'men',
    age_category = 'senior',
    geographic_scope = 'national',
    sport_slug = 'football',
    sport_variant = 'association_football'
where coalesce(sport_slug, 'football') = 'football';

update public."League"
set competitive_level = 'professional',
    gender = 'men',
    age_category = 'senior',
    geographic_scope = 'national',
    competition_type = 'league',
    competition_format = 'league',
    competition_level = 'national',
    sport_slug = 'football'
where name ilike '%ligi%' or name ilike '%nbc%' or name ilike '%premier%' or type = 'league';

insert into public."Competition" (id, name, slug, sport_slug, competition_type, competition_format, competition_level, gender, country, season)
values
  ('comp-ligi-kuu-bara','Ligi Kuu Bara','ligi-kuu-bara','football','league','league','national','men','Tanzania','2026/2027'),
  ('comp-federation-cup','Tanzania Federation Cup','federation-cup','football','cup','knockout','national','men','Tanzania','2026/2027'),
  ('comp-taifa-stars','Tanzania National Team','taifa-stars','football','friendly','single_match','international','men','Tanzania',null)
on conflict (id) do update set name = excluded.name;

create or replace view public.v_taxonomy as
  select domain, slug, label, parent_slug, sort_order from public.taxonomy_term;

grant select on public.v_taxonomy to anon, authenticated;
