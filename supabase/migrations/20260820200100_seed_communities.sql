
insert into public."Community" ("id","name","description","topic","memberCount","createdAt")
values
  ('com-simba-fans','Simba SC Official Fans','Derby threads and meet-ups','Football',0,now()),
  ('com-yanga-union','Yanga Union','Jangwani updates and away days','Football',0,now()),
  ('com-tpl-tactics','TPL Tactics Room','Post-match analysis','Analysis',0,now()),
  ('com-dar-meetups','Dar Matchday Meetups','Fans going to the stadium','Local',0,now()),
  ('com-predictions','Predictions League','Weekly score predictions','Fantasy',0,now())
on conflict ("id") do nothing;
