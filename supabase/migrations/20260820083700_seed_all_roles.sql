-- Full 23-role catalog. Admin stays on the web console.

insert into public."Role" ("id","name","slug","description","icon","category","displayOrder","isActive")
values
  ('role-fan','Fan','fan','Follow teams, vote, predict, join communities','👤','individual',1,true),
  ('role-player','Player','player','Athlete / player profile','⚽','individual',2,true),
  ('role-team','Team','team','Club or team account','🛡️','organization',3,true),
  ('role-coach','Coach','coach','Coach or technical staff','📋','individual',4,true),
  ('role-scout','Scout','scout','Talent scout','🔎','individual',5,true),
  ('role-agent','Agent','agent','Player / coach agent','💼','individual',6,true),
  ('role-support-staff','Support Staff','support_staff','Physio, analyst staff, kit','🩺','individual',7,true),
  ('role-analyst','Analyst','analyst','Performance / tactical analyst','📊','individual',8,true),
  ('role-commentator','Commentator','commentator','Match commentator','🎙️','individual',9,true),
  ('role-journalist','Journalist','journalist','Sports journalist','📰','individual',10,true),
  ('role-creator','Creator','creator','Content creator','🎬','individual',11,true),
  ('role-moderator','Moderator','moderator','Community moderator','🛡️','individual',12,true),
  ('role-official','Official','official','Referee / match official','🟨','individual',13,true),
  ('role-academy','Academy','academy','Youth academy','🎓','organization',14,true),
  ('role-league','League','league','League body','🏆','organization',15,true),
  ('role-competition','Competition','competition','Cup / tournament','🥇','organization',16,true),
  ('role-organization','Organization','organization','Federation / association','🏛️','organization',17,true),
  ('role-media-broadcast','Media/Broadcast','media_broadcast','Media or broadcaster','📡','organization',18,true),
  ('role-community','Community','community','Fan community page','👥','organization',19,true),
  ('role-business','Business','business','Retail / brand business','🛒','commerce',20,true),
  ('role-sponsor','Sponsor','sponsor','Sponsor brand','💎','commerce',21,true),
  ('role-commercial-partner','Commercial Partner','commercial_partner','Commercial partner','🤝','commerce',22,true),
  ('role-venue','Venue','venue','Stadium or venue','🏟️','commerce',23,true)
on conflict ("id") do update set
  "name" = excluded."name",
  "slug" = excluded."slug",
  "description" = excluded."description",
  "category" = excluded."category",
  "displayOrder" = excluded."displayOrder",
  "isActive" = true;

create table if not exists public."OfficialProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "officialType" text, "federation" text, "license" text, "yearsActive" double precision,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);
create table if not exists public."SupportStaffProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "staffRole" text, "organization" text, "specialty" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);
create table if not exists public."ModeratorProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "scope" text, "communities" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);
create table if not exists public."SponsorProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "brand" text, "industry" text, "website" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);
create table if not exists public."MediaBroadcastProfile" (
  "userId" text primary key references public."User"("id") on delete cascade,
  "outlet" text, "platform" text, "coverage" text,
  "createdAt" timestamptz not null default now(), "updatedAt" timestamptz not null default now()
);

insert into public."RoleType" ("id","roleId","name","slug","description","displayOrder")
select
  'type-' || r."slug",
  r."id",
  r."name",
  r."slug" || '-default',
  'Default ' || r."name" || ' type',
  1
from public."Role" r
on conflict ("id") do nothing;
