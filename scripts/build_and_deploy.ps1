param(
    [switch]$SkipWeb,
    [switch]$SkipApk,
    [switch]$SkipServer,
    [switch]$SkipDb,
    [switch]$DryRun,
    [string]$ServerUser = "deploy",
    [string]$ServerHost = "104.152.50.173",
    [string]$WebPath    = "/var/www/playify",
    [string]$ApkPath    = "/var/www/playify/download/Playify.apk",
    [string]$Domain     = "playifysport.fun"
)

$ErrorActionPreference = "Stop"
$Server = "${ServerUser}@${ServerHost}"
$SupabaseUrl  = "https://fffqjbrethogesgghjsn.supabase.co"
$SupabaseAnon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZnFqYnJldGhvZ2VzZ2doanNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNjkwNTUsImV4cCI6MjEwMjc0NTA1NX0.5_Z2Ij5G6qTv-jfnkoAkzPnntWfdPK8yh7urt3vYrao"

# Try to load overrides from .env file
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match "=" -and $_ -notmatch "^#" } | ForEach-Object {
        $k,$v = $_ -split "=",2
        switch ($k.Trim()) {
            "SUPABASE_URL"       { $SupabaseUrl  = $v.Trim() }
            "SUPABASE_ANON_KEY"  { $SupabaseAnon = $v.Trim() }
            "DEPLOY_SERVER_USER" { $ServerUser   = $v.Trim() }
            "DEPLOY_SERVER_HOST" { $ServerHost   = $v.Trim() }
            "WEB_PATH"           { $WebPath      = $v.Trim() }
            "APK_PATH"           { $ApkPath      = $v.Trim() }
            "DOMAIN"             { $Domain       = $v.Trim() }
        }
    }
    $Server = "${ServerUser}@${ServerHost}"
}

function step { param([string]$n,[string]$msg) Write-Host "" ; Write-Host "[$n] $msg" -ForegroundColor Cyan }
function ok   { param([string]$msg) Write-Host "    OK: $msg" -ForegroundColor Green }
function info { param([string]$msg) Write-Host "    $msg" -ForegroundColor Gray }
function warn { param([string]$msg) Write-Host "    WARN: $msg" -ForegroundColor Yellow }

function remote-run {
    param([string[]]$cmds)
    $joined = $cmds -join " ; "
    ssh $Server $joined
}

Write-Host "============================================" -ForegroundColor Magenta
Write-Host "Playify Build and Deploy" -ForegroundColor Magenta
Write-Host "Server : $Server" -ForegroundColor Cyan
Write-Host "Domain : $Domain" -ForegroundColor Cyan
if ($DryRun) { Write-Host "DRY RUN mode - no changes will be made" -ForegroundColor Yellow }
Write-Host "============================================" -ForegroundColor Magenta

# Git sync
step "1/5" "Git sync"
if ($DryRun) {
    info "DRY RUN - skip"
} else {
    git fetch origin main
    git reset --hard origin/main
    $commit = git rev-parse --short HEAD
    ok "At $commit"
}

# Flutter pub get
step "2/5" "Flutter pub get"
if ($DryRun) {
    info "DRY RUN - skip"
} else {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { Write-Host "pub get failed" -ForegroundColor Red ; exit 1 }
    ok "Dependencies ready"
}

# Build web
if (-not $SkipWeb) {
    step "3/5" "Build web"
    if ($DryRun) {
        info "DRY RUN - skip"
    } else {
        Remove-Item -Recurse -Force "build\web" -ErrorAction SilentlyContinue
        flutter build web --release "--dart-define=SUPABASE_URL=$SupabaseUrl" "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnon" "--base-href=/"
        if ($LASTEXITCODE -ne 0) { Write-Host "Web build failed" -ForegroundColor Red ; exit 1 }
        $sizeBytes = (Get-ChildItem "build\web" -Recurse | Measure-Object Length -Sum).Sum
        $sizeMB = [math]::Round($sizeBytes / 1MB, 1)
        ok "Web build $sizeMB MB"

        if (-not $SkipServer) {
            info "Deploying web to server..."
            $tmp = "/tmp/web_$(Get-Date -Format 'yyyyMMddHHmmss')"
            ssh $Server "mkdir -p $tmp"
            scp -r "build\web\*" "${Server}:${tmp}"
            if ($LASTEXITCODE -ne 0) { Write-Host "Web upload failed" -ForegroundColor Red ; exit 1 }
            $apkDir = [System.IO.Path]::GetDirectoryName($ApkPath)
            remote-run @(
                "sudo mkdir -p $apkDir",
                "sudo rsync -a --delete ${tmp}/ ${WebPath}/",
                "sudo chown -R www-data:www-data $WebPath",
                "sudo chmod -R 755 $WebPath",
                "sudo rm -rf $tmp",
                "sudo nginx -t",
                "sudo systemctl reload nginx"
            )
            ok "Web live at https://$Domain"
        }
    }
} else {
    step "3/5" "Web - SKIPPED"
}

# Build APK
if (-not $SkipApk) {
    step "4/5" "Build APK"
    if ($DryRun) {
        info "DRY RUN - skip"
    } else {
        Remove-Item -Recurse -Force "buildpp\outputslutter-apk" -ErrorAction SilentlyContinue
        flutter build apk --release "--split-debug-info=.\debug-info" "--dart-define=SUPABASE_URL=$SupabaseUrl" "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnon"
        if ($LASTEXITCODE -ne 0) { Write-Host "APK build failed" -ForegroundColor Red ; exit 1 }
        $apkFile = "buildpp\outputslutter-apkpp-release.apk"
        if (-not (Test-Path $apkFile)) { Write-Host "APK file not found" -ForegroundColor Red ; exit 1 }
        $apkMB = [math]::Round((Get-Item $apkFile).Length / 1MB, 1)
        ok "APK $apkMB MB"

        if (-not $SkipServer) {
            info "Uploading APK to server..."
            $tmpApk = "/tmp/Playify_$(Get-Date -Format 'yyyyMMddHHmmss').apk"
            scp $apkFile "${Server}:${tmpApk}"
            if ($LASTEXITCODE -ne 0) { Write-Host "APK upload failed" -ForegroundColor Red ; exit 1 }
            $apkDir = [System.IO.Path]::GetDirectoryName($ApkPath)
            remote-run @(
                "sudo mkdir -p $apkDir",
                "sudo mv $tmpApk $ApkPath",
                "sudo chown www-data:www-data $ApkPath",
                "sudo chmod 644 $ApkPath"
            )
            ok "APK at https://$Domain/download/Playify.apk"
        }
    }
} else {
    step "4/5" "APK - SKIPPED"
}

# Database
step "5/5" "Database migrations"
if ($SkipDb) {
    info "SKIPPED"
} elseif (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
    warn "supabase CLI not found - skipping"
} else {
    $count = (Get-ChildItem "supabase\migrations" -Filter "*.sql" -ErrorAction SilentlyContinue).Count
    if ($count -gt 0) {
        info "$count migration files found"
        $answer = Read-Host "    Push to production? (y/N)"
        if ($answer -eq "y" -or $answer -eq "Y") {
            if ($DryRun) {
                info "DRY RUN - skip"
            } else {
                supabase db push
                if ($LASTEXITCODE -eq 0) { ok "Migrations applied" } else { warn "Migration errors - check output" }
            }
        } else {
            info "Skipped by user"
        }
    } else {
        info "No migrations pending"
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Deploy complete" -ForegroundColor Green
Write-Host "Web:  https://$Domain" -ForegroundColor Green
Write-Host "APK:  https://$Domain/download/Playify.apk" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
