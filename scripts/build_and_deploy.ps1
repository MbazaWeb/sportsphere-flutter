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
    [string]$ServerHost = "95.217.20.12",
    [string]$ServerUser = "david",
    [string]$WebPath = "/var/www/playify",
    [string]$ApkPath = "/var/www/playify/downloads"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Playify Build and Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- 1. Load .env ---
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

Write-Host ""
Write-Host "[1/5] Supabase URL: $supabaseUrl" -ForegroundColor Green
$keyPreview = $supabaseAnonKey.Substring(0, [Math]::Min(20, $supabaseAnonKey.Length))
Write-Host "      Anon Key: $keyPreview..." -ForegroundColor Green

# --- 2. Flutter clean + pub get ---
Write-Host ""
Write-Host "[2/5] Cleaning and fetching dependencies..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

# --- 3. Build Web ---
if (-not $SkipWeb) {
    Write-Host ""
    Write-Host "[3/5] Building Web (release)..." -ForegroundColor Yellow

    flutter build web --release --base-href /playify/ --dart-define=SUPABASE_URL=$supabaseUrl --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey
    if ($LASTEXITCODE -ne 0) {
        throw "Web build failed"
    }

    $webBuildPath = Join-Path $ProjectRoot "build\web"
    $webSizeBytes = (Get-ChildItem -Path $webBuildPath -Recurse | Measure-Object -Property Length -Sum).Sum
    $webSizeMB = [math]::Round($webSizeBytes / 1MB, 1)
    Write-Host "      Web build: $webBuildPath ($webSizeMB MB)" -ForegroundColor Green

    if (-not $SkipServer) {
        Write-Host ""
        Write-Host "      Deploying web to $ServerUser@$ServerHost`:$WebPath ..." -ForegroundColor Yellow

        # Ensure remote directory exists (use ; instead of &&)
        $remoteCmd = "sudo mkdir -p $WebPath; sudo chown ${ServerUser}:${ServerUser} $WebPath"
        ssh "${ServerUser}@${ServerHost}" $remoteCmd

        # Rsync web build to server
        rsync -avz --delete -e ssh "$webBuildPath/" "${ServerUser}@${ServerHost}:$WebPath/"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "      rsync failed - trying scp..." -ForegroundColor Red
            Get-ChildItem -Path $webBuildPath -Recurse | ForEach-Object {
                $rel = $_.FullName.Substring($webBuildPath.Length).Replace('\','/')
                $dest = "${ServerUser}@${ServerHost}:$WebPath/$rel"
                scp $_.FullName $dest
            }
        }

        Write-Host "      Web deployed to https://$ServerHost/playify/" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "[3/5] Skipping web build" -ForegroundColor DarkGray
}

# --- 4. Build APK ---
if (-not $SkipApk) {
    Write-Host ""
    Write-Host "[4/5] Building APK (release)..." -ForegroundColor Yellow

    flutter build apk --release --dart-define=SUPABASE_URL=$supabaseUrl --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey
    if ($LASTEXITCODE -ne 0) {
        throw "APK build failed"
    }

    $apkPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    $apkSizeBytes = (Get-Item $apkPath).Length
    $apkSizeMB = [math]::Round($apkSizeBytes / 1MB, 1)
    Write-Host "      APK: $apkPath ($apkSizeMB MB)" -ForegroundColor Green

    if (-not $SkipServer) {
        Write-Host ""
        Write-Host "      Uploading APK to $ServerUser@$ServerHost`:$ApkPath ..." -ForegroundColor Yellow

        # Ensure remote directory exists (use ; instead of &&)
        $remoteCmd = "sudo mkdir -p $ApkPath; sudo chown ${ServerUser}:${ServerUser} $ApkPath"
        ssh "${ServerUser}@${ServerHost}" $remoteCmd

        # Get version from pubspec.yaml
        $pubspecContent = Get-Content (Join-Path $ProjectRoot "pubspec.yaml")
        $versionLine = $pubspecContent | Where-Object { $_ -match '^version:' } | Select-Object -First 1
        $version = ($versionLine -replace '^version:\s*', '').Trim()
        $remoteApkName = "playify-$version.apk"

        scp $apkPath "${ServerUser}@${ServerHost}:$ApkPath/$remoteApkName"
        # Also copy as latest.apk for easy download link
        $copyCmd = "cp $ApkPath/$remoteApkName $ApkPath/playify-latest.apk"
        ssh "${ServerUser}@${ServerHost}" $copyCmd

        Write-Host "      APK uploaded: https://$ServerHost/playify/downloads/$remoteApkName" -ForegroundColor Green
        Write-Host "      Latest APK:   https://$ServerHost/playify/downloads/playify-latest.apk" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "[4/5] Skipping APK build" -ForegroundColor DarkGray
}

# --- 5. Summary ---
Write-Host ""
Write-Host "[5/5] Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
if (-not $SkipWeb) {
    Write-Host "  Web:  https://$ServerHost/playify/" -ForegroundColor White
}
if (-not $SkipApk) {
    $pubspecContent = Get-Content (Join-Path $ProjectRoot "pubspec.yaml")
    $versionLine = $pubspecContent | Where-Object { $_ -match '^version:' } | Select-Object -First 1
    $version = ($versionLine -replace '^version:\s*', '').Trim()
    Write-Host "  APK:  https://$ServerHost/playify/downloads/playify-$version.apk" -ForegroundColor White
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
