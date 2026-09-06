# Production security release — 6 September 2026

Deployed with the user's explicit approval.

- Release: `/opt/playify/releases/20260906T192044Z`
- Configuration/database rollback backup: `/var/backups/playify-release-20260906T192044Z`
- API: `playify-api.service`, running as `playify-api`, bound to `127.0.0.1:3000`, zero restarts at verification.
- Admin: https://playifysport.fun/admin/
- Secrets: release `.env` owned by `root:playify-api`, mode `0640`.
- Daily local database backup: 02:00 server time, `/usr/local/sbin/playify-backup`, 14-day retention. Installer created and checked a predeployment dump and an initial scheduled-format dump using `pg_restore --list`. A full restore/offsite backup has not been tested.
- The old five-minute git-pull/root-PM2 restart cron is disabled. Future source changes require an explicit release; editing `/var/playify/app` does not update the running release.

## Validation

Before deployment: admin production build, API TypeScript check, 4 security tests (28 assertions), and 78 integration checks passed. Integration checks used disposable accounts and records, removed afterward. Covered public/member/admin reads, role denial, registration, login, refresh rotation/replay rejection, logout revocation, single-use OTP recovery, sports entity creation, role-profile creation, news/post creation/deletion, R2 image upload/download, and signed WebSocket subscriptions.

After deployment: source hashes match the tested candidate; API/database health passes; feed, news, match, community, sports, and nearby endpoints respond; `/admin/` and its users route serve the admin bundle; anonymous admin access returns 401; missing storage objects return 404; the legacy APK URL redirects to the actual APK; both version endpoints return the same version and download URL. Verified the service identity, loopback binding, protected secrets file, and backup cron.

## Remaining limitations

- AI, FCM push, and M-Pesa remain unavailable until provider credentials and the intended payment provider/country are configured. Payment callbacks fail closed without the callback secret; no live payment or notification delivery was tested.
- No connected browser was available for visual UI verification.
- The existing Flutter web build and APK were not rebuilt. The local password-recovery modal change is not yet shipped; older clients can still display the DOB option, but the server rejects it and requires email verification. The native realtime client's endpoint configuration also needs a separate client review/build.
- Previously issued access JWTs remain valid until expiry; refresh-token revocation is now enforced. Older sessions with unrecorded refresh tokens must sign in again.
- The separate admin console now uses VPS auth/data. An account with role `admin` and a VPS password is required.
- The release installer is tailored to this initial migration and intentionally refuses to add duplicate admin Nginx routing; review it before reusing for another release.
