-- Fix migration history: remove suffixed versions, keep bare version numbers
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query)

BEGIN;

-- Delete the suffixed entries that the CLI can't match to local files
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260819194150_init';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260819231000_profile_dob_and_update';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260819232000_full_app_schema';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820083700_seed_all_roles';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820084300_team_accounts';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820084800_claim_requests';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820095500_admin_console_policies';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820100200_enable_realtime';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820104500_fan_social_features';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820120000_entity_taxonomy';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820123000_multi_sport_feed';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820130000_comment_media_pdf';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820140000_team_profiles';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820143000_news_feed';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820150000_news_engagement';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820152000_unique_counts';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820180000_profiles_public_read';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820190000_sync_team_avatars';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820192000_seed_person_roles';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820193000_realtime_notification_triggers';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820194500_share_stats_orders';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820200000_fix_scan_issues';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820200100_seed_communities';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820203000_rls_messages_payment';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820210000_identity_sync';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820213000_post_counter_rpc';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260820220000_message_realtime';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260822000000_fix_handle_new_user_trigger';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260822153000_remove_placeholder_leagues';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260822160000_team_primary_color';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260822180000_admin_entity_write_rls';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260822230000_admin_writes_and_post_counts';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260823010000_playify_official_identity';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260824000000_fix_top3_critical_security';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260824010000_fix_all_remaining_db_issues';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260825000000_scan_report_fixes';
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260825000001_race_rpc_param_text_fix';

-- Insert bare-version entries that match local migration filenames
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260819194150') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260819231000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260819232000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820083700') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820084300') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820084800') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820095500') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820100200') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820104500') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820120000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820123000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820130000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820140000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820143000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820150000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820152000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820180000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820190000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820192000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820193000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820194500') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820200000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820200100') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820203000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820210000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820213000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260820220000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260822000000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260822153000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260822160000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260822180000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260822230000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260823010000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260824000000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260824010000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260825000000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260825000001') ON CONFLICT DO NOTHING;

INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260825010000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260825020000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260825030000') ON CONFLICT DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20260825040000') ON CONFLICT DO NOTHING;

COMMIT;

-- Verify:
SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;