alter table public."Comment" add column if not exists "mediaUrls" jsonb default '[]'::jsonb;
alter table public."Comment" add column if not exists "mediaType" text;

update storage.buckets set allowed_mime_types = array[
  'image/jpeg','image/png','image/webp','image/gif',
  'video/mp4','video/quicktime','application/pdf'
] where id = 'posts';

update storage.buckets set allowed_mime_types = array[
  'image/jpeg','image/png','image/webp','image/gif','application/pdf'
] where id = 'media';
