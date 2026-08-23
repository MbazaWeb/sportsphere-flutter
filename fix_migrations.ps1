# Fix Supabase migration history - repair all 37 suffixed versions one by one
$versions = @(
    "20260819194150_init",
    "20260819231000_profile_dob_and_update",
    "20260819232000_full_app_schema",
    "20260820083700_seed_all_roles",
    "20260820084300_team_accounts",
    "20260820084800_claim_requests",
    "20260820095500_admin_console_policies",
    "20260820100200_enable_realtime",
    "20260820104500_fan_social_features",
    "20260820120000_entity_taxonomy",
    "20260820123000_multi_sport_feed",
    "20260820130000_comment_media_pdf",
    "20260820140000_team_profiles",
    "20260820143000_news_feed",
    "20260820150000_news_engagement",
    "20260820152000_unique_counts",
    "20260820180000_profiles_public_read",
    "20260820190000_sync_team_avatars",
    "20260820192000_seed_person_roles",
    "20260820193000_realtime_notification_triggers",
    "20260820194500_share_stats_orders",
    "20260820200000_fix_scan_issues",
    "20260820200100_seed_communities",
    "20260820203000_rls_messages_payment",
    "20260820210000_identity_sync",
    "20260820213000_post_counter_rpc",
    "20260820220000_message_realtime",
    "20260822000000_fix_handle_new_user_trigger",
    "20260822153000_remove_placeholder_leagues",
    "20260822160000_team_primary_color",
    "20260822180000_admin_entity_write_rls",
    "20260822230000_admin_writes_and_post_counts",
    "20260823010000_playify_official_identity",
    "20260824000000_fix_top3_critical_security",
    "20260824010000_fix_all_remaining_db_issues",
    "20260825000000_scan_report_fixes",
    "20260825000001_race_rpc_param_text_fix"
)

$total = $versions.Count
$i = 0
foreach ($v in $versions) {
    $i++
    Write-Host "[$i/$total] Reverting: $v" -ForegroundColor Cyan
    supabase migration repair --status reverted $v
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: failed for $v (may already be gone)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Now re-marking all as applied with bare version numbers..." -ForegroundColor Green

$bareVersions = @(
    "20260819194150","20260819231000","20260819232000",
    "20260820083700","20260820084300","20260820084800",
    "20260820095500","20260820100200","20260820104500",
    "20260820110000",
    "20260820120000","20260820123000","20260820130000",
    "20260820140000","20260820143000","20260820150000",
    "20260820152000","20260820180000","20260820190000",
    "20260820192000","20260820193000","20260820194500",
    "20260820200000","20260820200100","20260820203000",
    "20260820210000","20260820213000","20260820220000",
    "20260822000000","20260822153000","20260822160000",
    "20260822180000","20260822230000","20260823010000",
    "20260824000000","20260824010000",
    "20260825000000","20260825000001",
    "20260825010000","20260825020000","20260825030000","20260825040000"
)

$total2 = $bareVersions.Count
$j = 0
foreach ($v in $bareVersions) {
    $j++
    Write-Host "[$j/$total2] Marking applied: $v" -ForegroundColor Green
    supabase migration repair --status applied $v
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: failed for $v" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Done! Now run: supabase db push" -ForegroundColor White
