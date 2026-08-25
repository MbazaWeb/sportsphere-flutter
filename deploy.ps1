# ============================================================
# Playify Build & Deploy Pipeline  v3.0
# Usage: .\deploy.ps1 [-WebOnly] [-ApkOnly] [-SkipDb] [-DryRun]
# Credentials: stored in deploy.env (never committed to git)
# ============================================================

param(
    [switch]$WebOnly,
    [switch]$ApkOnly,
    [switch]$SkipDb,
    [switch]$DryRun
)

# ── Load credentials from deploy.env (git-ignored) ────────────────────────────
$ENV_FILE = "$PSScriptRoot\deploy.env"
if (-not (Test-Path $ENV_FILE)) {
    Write-Host @"
ERROR: deploy.env not found.
Create it from the template:  copy deploy.env.example deploy.env
Then fill in your credentials.
"@ -ForegroundColor Red
    exit 1
}

$ENV_VARS = @{}
Get-Content $ENV_FILE | Where-Object { $_ -match '^\s*[^#]' -and $_ -match '=' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    $ENV_VARS[$k.Trim()] = $v.Trim()
}

$CONFIG = @{
    SUPABASE_URL   = $ENV_VARS['SUPABASE_URL']
    ANON_KEY       = $ENV_VARS['SUPABASE_ANON_KEY']
    SERVER         = $ENV_VARS['DEPLOY_SERVER']          # deploy@104.152.50.173
    WEB_PATH       = $ENV_VARS['WEB_PATH']               # /var/www/playify/
    APK_DEST       = $ENV_VARS['APK_DEST']               # /var/www/playify/download/Playify.apk
    DOMAIN         = $ENV_VARS['DOMAIN']                 # playifysport.fun
}

# Validate required vars
foreach ($key in @('SUPABASE_URL','ANON_KEY','SERVER','WEB_PATH','DOMAIN')) {
    if ([string]::IsNullOrWhiteSpace($CONFIG[$key])) {
        Write-Host "ERROR: $key not set in deploy.env" -ForegroundColor Red
        exit 1
    }
}

# ── Logging ────────────────────────────────────────────────────────────────────
$LOG_DIR = "$PSScriptRoot\logs"
New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
$LOG = "$LOG_DIR\deploy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

function Log {
    param($Msg, $Col = 'White')
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $Msg"
    Add-Content $LOG $line
    Write-Host $line -ForegroundColor $Col
}
function Step { Log "`n── $args ──────────────────────────────────" Cyan }
function OK   { Log "✅ $args" Green }
function WARN { Log "⚠️  $args" Yellow }
function FAIL { Log "❌ $args" Red }
function INFO { Log "   $args" Gray }

# ── Helpers ────────────────────────────────────────────────────────────────────
function Run {
    param([string]$Desc, [scriptblock]$Block, [int]$Retries = 2)
    for ($i = 1; $i -le $Retries; $i++) {
        INFO "($i/$Retries) $Desc"
        try {
            & $Block
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
            OK $Desc; return
        } catch {
            WARN "Attempt $i failed: $_"
            if ($i -eq $Retries) { FAIL $Desc; throw }
            Start-Sleep 5
        }
    }
}

function SSH { param($Cmd) ssh $CONFIG.SERVER $Cmd }
function SCP-UP { param($Local, $Remote) scp -r $Local "$($CONFIG.SERVER):$Remote" }

# ── Prerequisite check ─────────────────────────────────────────────────────────
function Check-Prerequisites {
    Step "Prerequisites"
    if (-not (Test-Path "pubspec.yaml")) { FAIL "Not in Flutter project root"; exit 1 }
    foreach ($cmd in @('flutter','git','ssh','scp')) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            FAIL "$cmd not found in PATH"; exit 1
        }
        INFO "$cmd found"
    }
    # Test SSH
    $out = ssh -o ConnectTimeout=8 -o BatchMode=yes $CONFIG.SERVER "echo ok" 2>&1
    if ($LASTEXITCODE -ne 0) { FAIL "SSH to $($CONFIG.SERVER) failed: $out"; exit 1 }
    OK "SSH connection OK"
}

# ── Read version from pubspec ──────────────────────────────────────────────────
function Get-AppVersion {
    $line = (Get-Content pubspec.yaml | Where-Object { $_ -match '^version:' } | Select-Object -First 1)
    return ($line -split ':')[1].Trim().Split('+')[0].Trim()
}

# ── Git sync ───────────────────────────────────────────────────────────────────
function Sync-Git {
    Step "Git sync"
    if ($DryRun) { INFO "DRY RUN — skipping git operations"; return }
    $dirty = git status --porcelain
    if ($dirty) {
        WARN "Uncommitted changes — stashing"
        git stash push -m "Auto-stash $(Get-Date -Format 'HH:mm:ss')"
    }
    git fetch origin main
    git reset --hard origin/main
    OK "At commit: $(git rev-parse --short HEAD)"
}

# ── Build web ──────────────────────────────────────────────────────────────────
function Build-Web {
    Step "Flutter web build"
    if ($DryRun) { INFO "DRY RUN — skipping build"; return }
    Remove-Item -Recurse -Force "build\web" -ErrorAction SilentlyContinue
    Run "flutter build web" {
        flutter build web --release `
            --dart-define="SUPABASE_URL=$($CONFIG.SUPABASE_URL)" `
            --dart-define="SUPABASE_ANON_KEY=$($CONFIG.ANON_KEY)" `
            --web-renderer=canvaskit `
            --base-href="/"
    }
    $mb = [math]::Round(((Get-ChildItem "build\web" -Recurse | Measure-Object Length -Sum).Sum) / 1MB, 1)
    OK "Web build: ${mb}MB"
}

# ── Deploy web ─────────────────────────────────────────────────────────────────
function Deploy-Web {
    Step "Deploy web → $($CONFIG.SERVER)"
    if ($DryRun) { INFO "DRY RUN — skipping deploy"; return }

    $tmp = "/tmp/playify_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    SSH "mkdir -p $tmp && chmod 777 $tmp"
    Run "Upload web files" { SCP-UP "build\web\*" $tmp }
    SSH @"
        sudo mkdir -p $($CONFIG.WEB_PATH)download
        sudo rsync -a --delete ${tmp}/ $($CONFIG.WEB_PATH)
        sudo chown -R www-data:www-data $($CONFIG.WEB_PATH)
        sudo chmod -R 755 $($CONFIG.WEB_PATH)
        sudo rm -rf $tmp
        sudo nginx -t && sudo systemctl reload nginx
"@
    OK "Web deployed to $($CONFIG.DOMAIN)"
}

# ── Build APK ──────────────────────────────────────────────────────────────────
function Build-APK {
    Step "Flutter APK build (release)"
    if ($DryRun) { INFO "DRY RUN — skipping build"; return }
    Run "flutter build apk" {
        flutter build apk --release `
            --split-debug-info=".\debug-info" `
            --dart-define="SUPABASE_URL=$($CONFIG.SUPABASE_URL)" `
            --dart-define="SUPABASE_ANON_KEY=$($CONFIG.ANON_KEY)"
    }
    $apk = "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apk)) { FAIL "APK not found"; throw }
    $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
    OK "APK: ${mb}MB"
}

# ── Upload APK ─────────────────────────────────────────────────────────────────
function Upload-APK {
    Step "Upload APK → server"
    if ($DryRun) { INFO "DRY RUN — skipping upload"; return }
    $tmp = "/tmp/Playify_$(Get-Date -Format 'yyyyMMdd_HHmmss').apk"
    Run "Upload APK" { SCP-UP "build\app\outputs\flutter-apk\app-release.apk" $tmp }
    SSH @"
        sudo mkdir -p $(Split-Path $CONFIG.APK_DEST)
        sudo mv $tmp $($CONFIG.APK_DEST)
        sudo chown www-data:www-data $($CONFIG.APK_DEST)
        sudo chmod 644 $($CONFIG.APK_DEST)
"@
    OK "APK live: https://$($CONFIG.DOMAIN)/download/Playify.apk"
}

# ── Write version.json ─────────────────────────────────────────────────────────
function Publish-VersionJson {
    param($Version)
    Step "version.json"
    $notes = Read-Host "Release notes [Bug fixes and improvements]"
    if ([string]::IsNullOrWhiteSpace($notes)) { $notes = "Bug fixes and improvements" }
    $force = (Read-Host "Force update? (y/N)") -in @('y','Y')

    $json = [ordered]@{
        version    = $Version
        notes      = $notes
        mandatory  = $force
        apk_url    = "https://$($CONFIG.DOMAIN)/download/Playify.apk"
        updated_at = (Get-Date -Format 'yyyy-MM-dd')
        build      = @{
            time   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            commit = (git rev-parse --short HEAD 2>$null)
            branch = (git branch --show-current 2>$null)
        }
    } | ConvertTo-Json -Depth 4

    $tmp = [IO.Path]::GetTempFileName()
    $json | Set-Content $tmp -Encoding UTF8
    if ($DryRun) { INFO "DRY RUN — version.json content:"; INFO $json; return }
    $remTmp = "/tmp/version_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    SCP-UP $tmp $remTmp
    Remove-Item $tmp -Force
    SSH "sudo mv $remTmp $($CONFIG.WEB_PATH)version.json && sudo chown www-data:www-data $($CONFIG.WEB_PATH)version.json"
    OK "version.json published (v$Version, force=$force)"
}

# ── Supabase DB push ───────────────────────────────────────────────────────────
function Push-Database {
    Step "Supabase db push"
    if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) { WARN "supabase CLI not found — skip"; return }
    $count = (Get-ChildItem supabase\migrations -Filter *.sql -ErrorAction SilentlyContinue).Count
    if ($count -eq 0) { INFO "No migrations"; return }
    INFO "$count migration(s) pending"
    if ((Read-Host "Push to production? (y/N)") -notin @('y','Y')) { INFO "Skipped"; return }
    if ($DryRun) { INFO "DRY RUN — skipping db push"; return }
    Run "supabase db push" { supabase db push }
    OK "Migrations applied"
}

# ── Health check ───────────────────────────────────────────────────────────────
function Health-Check {
    Step "Health checks"
    $urls = @(
        "https://$($CONFIG.DOMAIN)"
        "https://$($CONFIG.DOMAIN)/download/Playify.apk"
        "https://$($CONFIG.DOMAIN)/version.json"
    )
    $ok = $true
    foreach ($url in $urls) {
        try {
            $r = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 12 -ErrorAction Stop
            OK "$($r.StatusCode) $url"
        } catch {
            WARN "FAIL $url — $_"
            $ok = $false
        }
    }
    return $ok
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
$t0 = Get-Date
try {
    Write-Host ""
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  Playify Deploy Pipeline v3.0$(if ($DryRun){' [DRY RUN]'})" -ForegroundColor Magenta
    Write-Host "  Server : $($CONFIG.SERVER)"  -ForegroundColor Cyan
    Write-Host "  Domain : $($CONFIG.DOMAIN)"  -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Magenta

    Check-Prerequisites
    Sync-Git
    $ver = Get-AppVersion
    INFO "Version: v$ver"

    if (-not $ApkOnly) { Build-Web;  Deploy-Web }
    if (-not $WebOnly) { Build-APK;  Upload-APK }

    Publish-VersionJson -Version $ver

    if (-not $SkipDb) { Push-Database }

    # Clean old server backups
    SSH "ls -dt $($CONFIG.WEB_PATH)../backup_* 2>/dev/null | tail -n +6 | xargs -r sudo rm -rf"

    $healthy = Health-Check
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)

    Write-Host ""
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ Playify v$ver deployed in ${mins}m" -ForegroundColor Green
    Write-Host "  🌐 https://$($CONFIG.DOMAIN)" -ForegroundColor Green
    Write-Host "  📱 https://$($CONFIG.DOMAIN)/download/Playify.apk" -ForegroundColor Green
    Write-Host "  Health: $(if ($healthy) {'All OK'} else {'Some checks failed'})" -ForegroundColor $(if ($healthy) {'Green'} else {'Yellow'})
    Write-Host "  Log: $LOG" -ForegroundColor Gray
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
}
catch {
    FAIL "Deploy failed: $_"
    exit 1
}
