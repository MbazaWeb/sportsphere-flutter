-- =============================================================================
-- Bump media bucket size limit so users can upload longer / higher-bitrate
-- videos (mp4, mov, mkv, webm, avi, 3gp, …) without hitting "Something went
-- wrong" errors.
--
-- Old limit: 50 MB (52428800 bytes)  — too small for typical 30–60s 1080p clips
-- New limit: 100 MB (104857600 bytes)
--
-- The media bucket already allows ALL MIME types (allowed_mime_types IS NULL),
-- so the only blocker for big video files is the file_size_limit.
-- =============================================================================

update storage.buckets
   set file_size_limit = 104857600  -- 100 MB
 where id = 'media';
