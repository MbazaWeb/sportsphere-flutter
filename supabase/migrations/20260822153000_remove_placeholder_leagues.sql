-- Remove UI placeholder competitions / leagues seeded for demos.
-- Safe: only touches known placeholder names/slugs.

update public."League"
set "isActive" = false
where lower(name) in (
  'nbc premier league',
  'ligi kuu bara',
  'crdb federation cup',
  'tanzania premier league'
);

delete from public."League"
where lower(name) in (
  'nbc premier league',
  'ligi kuu bara',
  'crdb federation cup',
  'tanzania premier league'
);

-- Competition taxonomy seed (entity_taxonomy)
delete from public."Competition"
where id in ('comp-ligi-kuu-bara')
   or lower(name) in ('ligi kuu bara', 'nbc premier league', 'crdb federation cup');
