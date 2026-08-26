param(
    [switch]$WebOnly,
    [switch]$ApkOnly,
    [switch]$SkipDb,
    [switch]$DryRun
)

# Load credentials from deploy.env
$ENV_FILE = Join-Path $PSScriptRoot "deploy.env"
if (-not (Test-Path $ENV_FILE)) {
    Write-Host "ERROR: deploy.env not found. Copy deploy.env.example to deploy.env and fill in values." -ForegroundColor Red
    exit 1
}
$CFG = @{}
Get-Content $ENV_FILE | Where-Object { $_ -match "=" -and $_ -notmatch "^\s*#" } | ForEach-Object {
    $parts = $_ -split "=", 2
    $CFG[$parts[0].Trim()] = $parts[1].Trim()
}
foreach ($k in @("SUPABASE_URL","SUPABASE_ANON_KEY","DEPLOY_SERVER","WEB_PATH","DOMAIN")) {
    if ([string]::IsNullOrWhiteSpace($CFG[$k])) { Write-Host "ERROR: $k missing in deploy.env" -ForegroundColor Red; exit 1 }
}
$APK_DEST = if ($CFG["APK_DEST"]) { $CFG["APK_DEST"] } else { "$($CFG['WEB_PATH'])download/Playify.apk" }

# Logging
$LOG_DIR = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
$LOG = Join-Path $LOG_DIR "deploy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

function Log  { param($M,$C="White"); $l="[$(Get-Date -Format 'HH:mm:ss')] $M"; Add-Content $LOG $l; Write-Host $l -ForegroundColor $C }
function Step { Log ""; Log "== $args ==" Cyan }
function OK   { Log "OK  $args" Green }
function WARN { Log "WRN $args" Yellow }
function FAIL { Log "ERR $args" Red }
function INFO { Log "    $args" Gray }

function Run-Cmd {
    param([string]$Desc, [scriptblock]$Block, [int]$Retries=2)
    for ($i=1; $i -le $Retries; $i++) {
        INFO "($i/$Retries) $Desc"
        try { & $Block; if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" }; OK $Desc; return }
        catch { WARN "attempt $i failed: $_"; if ($i -eq $Retries) { FAIL $Desc; throw }; Start-Sleep 5 }
    }
}

function SSH-Cmd {
    param([string]$Cmd)
    ssh $CFG["DEPLOY_SERVER"] $Cmd
}

function SSH-Script {
    param([string[]]$Lines)
    # Write lines to a temp sh file, upload, execute, delete
    $tmp = [IO.Path]::GetTempFileName() -replace "\.tmp$",".sh"
    $Lines | Set-Content $tmp -Encoding UTF8
    $remote = "/tmp/deploy_$(Get-Date -Format 'yyyyMMddHHmmss').sh"
    scp $tmp "$($CFG['DEPLOY_SERVER']):$remote" | Out-Null
    Remove-Item $tmp -Force
    ssh $CFG["DEPLOY_SERVER"] "bash $remote ; rm -f $remote"
}

# Prerequisites
function Check-Prereqs {
    Step "Prerequisites"
    if (-not (Test-Path "pubspec.yaml")) { FAIL "Not in Flutter project root"; exit 1 }
    foreach ($cmd in @("flutter","git","ssh","scp")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { FAIL "$cmd not in PATH"; exit 1 }
        INFO "$cmd OK"
    }
    $out = ssh -o ConnectTimeout=8 -o BatchMode=yes $CFG["DEPLOY_SERVER"] "echo ok" 2>&1
    if ($LASTEXITCODE -ne 0) { FAIL "SSH failed: $out"; exit 1 }
    OK "SSH to $($CFG['DEPLOY_SERVER'])"
}

function Get-AppVersion {
    $line = Get-Content pubspec.yaml | Where-Object { $_ -match "^version:" } | Select-Object -First 1
    return ($line -split ":")[1].Trim().Split("+")[0].Trim()
}

function Sync-Git {
    Step "Git sync"
    if ($DryRun) { INFO "DRY RUN - skip"; return }
    if (git status --porcelain) { WARN "Stashing uncommitted changes"; git stash push -m "auto-stash" }
    git fetch origin main
    git reset --hard origin/main
    OK "At $(git rev-parse --short HEAD)"
}

function Build-Web {
    Step "Build web"
    if ($DryRun) { INFO "DRY RUN - skip"; return }
    Remove-Item -Recurse -Force "build\web" -ErrorAction SilentlyContinue
    Run-Cmd "flutter build web" {
        flutter build web --release `
            "--dart-define=SUPABASE_URL=$($CFG['SUPABASE_URL'])" `
            "--dart-define=SUPABASE_ANON_KEY=$($CFG['SUPABASE_ANON_KEY'])" `
            `
            "--base-href=/"
    }
    $mb = [math]::Round(((Get-ChildItem "build\web" -Recurse | Measure-Object Length -Sum).Sum)/1MB,1)
    OK "Web build: ${mb}MB"
}

function Deploy-Web {
    Step "Deploy web"
    if ($DryRun) { INFO "DRY RUN - skip"; return }
    $tmp = "/tmp/playify_$(Get-Date -Format 'yyyyMMddHHmmss')"
    SSH-Cmd "mkdir -p $tmp"
    SSH-Cmd "chmod 777 $tmp"
    Run-Cmd "Upload web files" { scp -r "build\web\*" "$($CFG['DEPLOY_SERVER']):$tmp" }
    SSH-Script @(
        "sudo mkdir -p $($CFG['WEB_PATH'])download",
        "sudo rsync -a --delete ${tmp}/ $($CFG['WEB_PATH'])",
        "sudo chown -R www-data:www-data $($CFG['WEB_PATH'])",
        "sudo chmod -R 755 $($CFG['WEB_PATH'])",
        "sudo rm -rf $tmp",
        "sudo nginx -t",
        "sudo systemctl reload nginx"
    )
    OK "Web deployed to $($CFG['DOMAIN'])"
}

function Build-APK {
    Step "Build APK"
    if ($DryRun) { INFO "DRY RUN - skip"; return }
    Run-Cmd "flutter build apk" {
        flutter build apk --release `
            "--split-debug-info=.\debug-info" `
            "--dart-define=SUPABASE_URL=$($CFG['SUPABASE_URL'])" `
            "--dart-define=SUPABASE_ANON_KEY=$($CFG['SUPABASE_ANON_KEY'])"
    }
    $apk = "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apk)) { FAIL "APK not found"; throw "APK missing" }
    $mb = [math]::Round((Get-Item $apk).Length/1MB,1)
    OK "APK: ${mb}MB"
}

function Upload-APK {
    Step "Upload APK"
    if ($DryRun) { INFO "DRY RUN - skip"; return }
    $tmp = "/tmp/Playify_$(Get-Date -Format 'yyyyMMddHHmmss').apk"
    Run-Cmd "Upload APK" { scp "build\app\outputs\flutter-apk\app-release.apk" "$($CFG['DEPLOY_SERVER']):$tmp" }
    $apkDir = [System.IO.Path]::GetDirectoryName($APK_DEST)
    SSH-Script @(
        "sudo mkdir -p $apkDir",
        "sudo mv $tmp $APK_DEST",
        "sudo chown www-data:www-data $APK_DEST",
        "sudo chmod 644 $APK_DEST"
    )
    OK "APK at https://$($CFG['DOMAIN'])/download/Playify.apk"
}

function Publish-Version {
    param([string]$Version)
    Step "version.json"
    $notes = Read-Host "Release notes [Bug fixes and improvements]"
    if ([string]::IsNullOrWhiteSpace($notes)) { $notes = "Bug fixes and improvements" }
    $forceRaw = Read-Host "Force update? (y/N)"
    $force = ($forceRaw -eq "y" -or $forceRaw -eq "Y")
    $json = "{`"version`":`"$Version`",`"notes`":`"$notes`",`"mandatory`":$($force.ToString().ToLower()),`"apk_url`":`"https://$($CFG['DOMAIN'])/download/Playify.apk`",`"updated_at`":`"$(Get-Date -Format 'yyyy-MM-dd')`",`"commit`":`"$(git rev-parse --short HEAD 2>$null)`"}"
    if ($DryRun) { INFO "DRY RUN - would publish: $json"; return }
    $tmp = [IO.Path]::GetTempFileName()
    $json | Set-Content $tmp -Encoding UTF8
    $remote = "/tmp/version_$(Get-Date -Format 'yyyyMMddHHmmss').json"
    scp $tmp "$($CFG['DEPLOY_SERVER']):$remote" | Out-Null
    Remove-Item $tmp -Force
    SSH-Script @(
        "sudo mv $remote $($CFG['WEB_PATH'])version.json",
        "sudo chown www-data:www-data $($CFG['WEB_PATH'])version.json",
        "sudo chmod 644 $($CFG['WEB_PATH'])version.json"
    )
    OK "version.json published (v$Version, force=$force)"
}

function Push-DB {
    Step "Supabase db push"
    if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) { WARN "supabase CLI not found - skip"; return }
    $count = (Get-ChildItem "supabase\migrations" -Filter "*.sql" -ErrorAction SilentlyContinue).Count
    if ($count -eq 0) { INFO "No migrations"; return }
    INFO "$count migration(s)"
    $yn = Read-Host "Push to production? (y/N)"
    if ($yn -ne "y" -and $yn -ne "Y") { INFO "Skipped"; return }
    if ($DryRun) { INFO "DRY RUN - skip"; return }
    Run-Cmd "supabase db push" { supabase db push }
    OK "Migrations applied"
}

function Health-Check {
    Step "Health checks"
    $pass = $true
    foreach ($url in @("https://$($CFG['DOMAIN'])","https://$($CFG['DOMAIN'])/download/Playify.apk","https://$($CFG['DOMAIN'])/version.json")) {
        try {
            $r = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 12 -ErrorAction Stop
            OK "$($r.StatusCode) $url"
        } catch { WARN "FAIL $url"; $pass = $false }
    }
    return $pass
}

# Main
$t0 = Get-Date
try {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Magenta
    Write-Host "  Playify Deploy v3.0$(if($DryRun){' [DRY RUN]'})" -ForegroundColor Magenta
    Write-Host "  Server : $($CFG['DEPLOY_SERVER'])" -ForegroundColor Cyan
    Write-Host "  Domain : $($CFG['DOMAIN'])" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Magenta

    Check-Prereqs
    Sync-Git
    $ver = Get-AppVersion
    INFO "Version: v$ver"

    if (-not $ApkOnly) { Build-Web; Deploy-Web }
    if (-not $WebOnly) { Build-APK; Upload-APK }
    Publish-Version -Version $ver
    if (-not $SkipDb) { Push-DB }
    SSH-Script @("ls -dt $($CFG['WEB_PATH'])../backup_* 2>/dev/null | tail -n +6 | xargs -r sudo rm -rf")
    $ok = Health-Check
    $mins = [math]::Round(((Get-Date)-$t0).TotalMinutes,1)

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "  Playify v$ver deployed in ${mins}m" -ForegroundColor Green
    Write-Host "  https://$($CFG['DOMAIN'])" -ForegroundColor Green
    Write-Host "  https://$($CFG['DOMAIN'])/download/Playify.apk" -ForegroundColor Green
    Write-Host "  Health: $(if($ok){'All OK'}else{'Some checks failed'})" -ForegroundColor $(if($ok){'Green'}else{'Yellow'})
    Write-Host "  Log: $LOG" -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Green
} catch {
    FAIL "Deploy failed: $_"
    exit 1
}
