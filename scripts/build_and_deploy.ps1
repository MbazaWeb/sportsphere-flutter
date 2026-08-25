<#
.SYNOPSIS
    Build Playify web + APK and deploy to server.

.DESCRIPTION
    This script:
    1. Reads Supabase credentials from .env
    2. Builds Flutter web app (release) with --base-href /playify/
    3. Builds Flutter Android APK (release)
    4. Deploys web build to server via SSH (rsync)
    5. Copies APK to server for download

.PARAMETER SkipWeb
    Skip web build + deploy

.PARAMETER SkipApk
    Skip APK build + deploy

.PARAMETER SkipServer
    Build only, don't deploy to server (artifacts stay in build/)

.EXAMPLE
    .\scripts\build_and_deploy.ps1
    .\scripts\build_and_deploy.ps1 -SkipWeb
    .\scripts\build_and_deploy.ps1 -SkipApk -SkipServer
#>

param(
    [switch]$SkipWeb,
    [switch]$SkipApk,
    [switch]$SkipServer,
    [string]$ServerHost = "104.152.50.173",
    [string]$ServerUser = "deploy",
    [string]$WebPath = "/var/www/playify",
    [string]$ApkPath = "/var/www/playify/downloads"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Playify Build & Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ── 1. Load .env ────────────────────────────────────────────────────────────
$envFile = Join-Path $ProjectRoot ".env"
if (-not (Test-Path $envFile)) {
    throw "Missing .env file at $envFile. Copy .env.example to .env and fill in credentials."
}

$values = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*?)\s*$') {
        $values[$matches[1]] = $matches[2].Trim('''').Trim('"')
    }
}

$supabaseUrl = $values['SUPABASE_URL']
$supabaseAnonKey = $values['SUPABASE_ANON_KEY']

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
    throw 'SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env'
}

Write-Host "`n[1/5] Supabase URL: $supabaseUrl" -ForegroundColor Green
Write-Host "      Anon Key: $($supabaseAnonKey.Substring(0,20))..." -ForegroundColor Green

# ── 2. Flutter clean + pub get ──────────────────────────────────────────────
Write-Host "`n[2/5] Cleaning + fetching dependencies..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

# ── 3. Build Web ────────────────────────────────────────────────────────────
if (-not $SkipWeb) {
    Write-Host "`n[3/5] Building Web (release)..." -ForegroundColor Yellow

    flutter build web --release --base-href /playify/ `
        --dart-define=SUPABASE_URL="$supabaseUrl" `
        --dart-define=SUPABASE_ANON_KEY="$supabaseAnonKey"

    if ($LASTEXITCODE -ne 0) {
        throw "Web build failed"
    }

    $webBuildPath = Join-Path $ProjectRoot "build\web"
    $webSize = (Get-ChildItem -Path $webBuildPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "      Web build: $webBuildPath ($([math]::Round($webSize,1)) MB)" -ForegroundColor Green

    if (-not $SkipServer) {
        Write-Host "`n      Deploying web to $ServerUser@$ServerHost`:$WebPath ..." -ForegroundColor Yellow

        # Ensure remote directory exists
        ssh "${ServerUser}@${ServerHost}" "sudo mkdir -p $WebPath && sudo chown ${ServerUser}:${ServerUser} $WebPath"

        # Rsync web build to server
        rsync -avz --delete `
            -e ssh `
            "$webBuildPath/" `
            "${ServerUser}@${ServerHost}:$WebPath/"

        if ($LASTEXITCODE -ne 0) {
            Write-Host "      rsync failed — trying scp..." -ForegroundColor Red
            scp -r "$webBuildPath/*" "${ServerUser}@${ServerHost}:$WebPath/"
        }

        Write-Host "      Web deployed to https://$ServerHost/playify/" -ForegroundColor Green
    }
} else {
    Write-Host "`n[3/5] Skipping web build" -ForegroundColor DarkGray
}

# ── 4. Build APK ────────────────────────────────────────────────────────────
if (-not $SkipApk) {
    Write-Host "`n[4/5] Building APK (release)..." -ForegroundColor Yellow

    flutter build apk --release `
        --dart-define=SUPABASE_URL="$supabaseUrl" `
        --dart-define=SUPABASE_ANON_KEY="$supabaseAnonKey"

    if ($LASTEXITCODE -ne 0) {
        throw "APK build failed"
    }

    $apkPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    $apkSize = (Get-Item $apkPath).Length / 1MB
    Write-Host "      APK: $apkPath ($([math]::Round($apkSize,1)) MB)" -ForegroundColor Green

    if (-not $SkipServer) {
        Write-Host "`n      Uploading APK to $ServerUser@$ServerHost`:$ApkPath ..." -ForegroundColor Yellow

        # Ensure remote directory exists
        ssh "${ServerUser}@${ServerHost}" "sudo mkdir -p $ApkPath && sudo chown ${ServerUser}:${ServerUser} $ApkPath"

        # Copy APK with version in filename
        $version = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value
        $remoteApkName = "playify-$version.apk"
        scp "$apkPath" "${ServerUser}@${ServerHost}:$ApkPath/$remoteApkName"

        # Also copy as latest.apk for easy download link
        ssh "${ServerUser}@${ServerHost}" "cp $ApkPath/$remoteApkName $ApkPath/playify-latest.apk"

        Write-Host "      APK uploaded: https://$ServerHost/playify/downloads/$remoteApkName" -ForegroundColor Green
        Write-Host "      Latest APK:   https://$ServerHost/playify/downloads/playify-latest.apk" -ForegroundColor Green
    }
} else {
    Write-Host "`n[4/5] Skipping APK build" -ForegroundColor DarkGray
}

# ── 5. Summary ──────────────────────────────────────────────────────────────
Write-Host "`n[5/5] Build & Deploy Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
if (-not $SkipWeb) {
    Write-Host "  Web:  https://$ServerHost/playify/" -ForegroundColor White
}
if (-not $SkipApk) {
    $version = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value
    Write-Host "  APK:  https://$ServerHost/playify/downloads/playify-$version.apk" -ForegroundColor White
}
Write-Host "========================================`n" -ForegroundColor Cyan
