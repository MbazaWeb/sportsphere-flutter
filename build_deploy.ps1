# ── Playify Build & Deploy Script ──────────────────────────────────────────
# Version: 2.3
# Description: Automated build and deployment pipeline for Playify app

# ── Configuration ──────────────────────────────────────────────────────────
$CONFIG = @{
    SUPABASE_URL = "https://fffqjbrethogesgghjsn.supabase.co"
    SUPABASE_API_URL = "https://fffqjbrethogesgghjsn.supabase.co/rest/v1/"
    SUPABASE_DB_URL = "postgresql://postgres:0H0Ad64USEIykfwm@db.fffqjbrethogesgghjsn.supabase.co:5432/postgres"
    ANON_KEY = "eyJhbGciOiJIUzI1NiIsR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZnFqYnJldGhvZ2VzZ2doanNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNjkwNTUsImV4cCI6MjEwMjc0NTA1NX0.5_Z2Ij5G6qTv-jfnkoAkzPnntWfdPK8yh7urt3vYrao"
    JWT_KEYS = "7f612b55-2ec2-4022-901b-e64a8d5cd40d"
    LEGACY_JWT_SECRET = "j6uG7pbQsrIXciowsoD5m8BqiZ1esy9rWHqrdGFEtqanJVLO7HwQY7kWp4a+S8BO0zsQ5xaspqxTjouigdJStA=="
    SERVER_USER = "david"
    SERVER_IP = "95.217.20.12"
    SERVER = "david@95.217.20.12"
    WEB_PATH = "/var/www/playify/"
    APK_PATH = "/var/www/playify/download/Playify.apk"
    DOMAIN = "playifysport.fun"
    SSH_PORT = 22
}

# ── Logging Setup ──────────────────────────────────────────────────────────
$LOG_DIR = "logs"
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LOG_FILE = "$LOG_DIR/deploy_$timestamp.log"

function Write-Log {
    param($Message, $Color = "White")
    $timestamped = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $LOG_FILE -Value $timestamped
    Write-Host $timestamped -ForegroundColor $Color
}

function Write-Step {
    param($Message)
    Write-Log "`n╔═══════════════════════════════════════════════════════════════╗" -Color Cyan
    Write-Log "║  $Message" -Color Cyan
    Write-Log "╚═══════════════════════════════════════════════════════════════╝" -Color Cyan
}

function Write-Success {
    param($Message)
    Write-Log "✅ $Message" -Color Green
}

function Write-Error {
    param($Message)
    Write-Log "❌ $Message" -Color Red
}

function Write-Warning {
    param($Message)
    Write-Log "⚠️  $Message" -Color Yellow
}

function Write-Info {
    param($Message)
    Write-Log "ℹ️  $Message" -Color Gray
}

# ── Error Handling ─────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"

function Invoke-CommandWithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Description,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Info "Attempt $attempt/$MaxRetries: $Description"
            & $ScriptBlock
            Write-Success "$Description completed successfully"
            return $true
        }
        catch {
            Write-Warning "Attempt $attempt failed: $_"
            if ($attempt -eq $MaxRetries) {
                Write-Error "$Description FAILED after $MaxRetries attempts"
                throw
            }
            Start-Sleep -Seconds $RetryDelay
            $attempt++
        }
    }
}

# ── SSH Connection Test ────────────────────────────────────────────────────
function Test-SSHConnection {
    param($Config)
    Write-Step "Testing SSH Connection"
    
    try {
        $sshTest = ssh -o ConnectTimeout=5 -o BatchMode=yes $Config.SERVER "echo 'SSH connection successful'" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "SSH connection to $($Config.SERVER) established"
            return $true
        } else {
            throw "SSH connection failed: $sshTest"
        }
    }
    catch {
        throw "Cannot connect to server: $_"
    }
}

# ── Check Prerequisites ────────────────────────────────────────────────────
function Test-Prerequisites {
    Write-Step "Checking Prerequisites"
    
    $prerequisites = @(
        @{Name="Flutter"; Command="flutter --version"},
        @{Name="Git"; Command="git --version"},
        @{Name="SCP"; Command="scp -V"},
        @{Name="SSH"; Command="ssh -V"},
        @{Name="Supabase CLI"; Command="supabase --version"}
    )
    
    $allGood = $true
    foreach ($prereq in $prerequisites) {
        try {
            $null = & $prereq.Command 2>&1
            Write-Info "✅ $($prereq.Name) found"
        }
        catch {
            Write-Error "$($prereq.Name) not found"
            $allGood = $false
        }
    }
    
    if (-not $allGood) {
        throw "Prerequisites check failed. Please install missing dependencies."
    }
    
    # Check if we're in the right directory
    if (-not (Test-Path "pubspec.yaml")) {
        throw "pubspec.yaml not found. Please run script from Flutter project root."
    }
}

# ── Read Version ───────────────────────────────────────────────────────────
function Get-Version {
    Write-Step "Reading Version"
    
    try {
        $pubspec = Get-Content pubspec.yaml | Where-Object { $_ -match "^version:" }
        if (-not $pubspec) {
            throw "Version not found in pubspec.yaml"
        }
        $version = ($pubspec -split ":")[1].Trim().Split("+")[0].Trim()
        Write-Success "Version: v$version"
        return $version
    }
    catch {
        throw "Failed to read version: $_"
    }
}

# ── Git Operations ────────────────────────────────────────────────────────
function Update-GitRepository {
    param($Version)
    Write-Step "Updating Git Repository"
    
    try {
        # Check for uncommitted changes
        $status = git status --porcelain
        if ($status) {
            Write-Warning "Uncommitted changes detected"
            $response = Read-Host "Do you want to stash changes? (y/N)"
            if ($response -eq "y" -or $response -eq "Y") {
                git stash push -m "Auto-stash before deployment v$Version"
                Write-Success "Changes stashed"
            } else {
                Write-Warning "Continuing with uncommitted changes"
            }
        }
        
        # Fetch and reset
        Invoke-CommandWithRetry -Description "Git fetch and reset" -ScriptBlock {
            git fetch origin main
            git reset --hard origin/main
            $currentCommit = git rev-parse --short HEAD
            Write-Info "Current commit: $currentCommit"
        }
        
        # Get latest tag if available
        $latestTag = git describe --tags --abbrev=0 2>$null
        if ($latestTag) {
            Write-Info "Latest tag: $latestTag"
        }
    }
    catch {
        throw "Git update failed: $_"
    }
}

# ── Pull Latest on Server ─────────────────────────────────────────────────
function Pull-ServerLatest {
    param($Config)
    Write-Step "Pulling Latest Code on Server"
    
    try {
        # Check if server has git repository
        $repoCheck = ssh $Config.SERVER "cd $($Config.WEB_PATH) && test -d .git && echo 'exists'" 2>&1
        
        if ($repoCheck -match "exists") {
            Write-Info "Git repository found on server"
            
            # Pull latest changes on server
            Invoke-CommandWithRetry -Description "Git pull on server" -ScriptBlock {
                ssh $Config.SERVER @"
                    cd $($Config.WEB_PATH)
                    sudo git fetch origin main
                    sudo git reset --hard origin/main
                    sudo git log -1 --oneline
"@
                if ($LASTEXITCODE -ne 0) {
                    throw "Server git pull failed"
                }
            }
            Write-Success "Server repository updated"
        } else {
            Write-Warning "No git repository found on server at $($Config.WEB_PATH)"
            Write-Info "Cloning repository to server..."
            
            # Clone repository to server
            $repoUrl = "https://github.com/yourusername/playify.git"  # Replace with actual repo URL
            Invoke-CommandWithRetry -Description "Clone repository on server" -ScriptBlock {
                ssh $Config.SERVER @"
                    sudo mkdir -p $($Config.WEB_PATH)
                    sudo git clone $repoUrl $($Config.WEB_PATH)
                    sudo chown -R www-data:www-data $($Config.WEB_PATH)
"@
                if ($LASTEXITCODE -ne 0) {
                    throw "Server clone failed"
                }
            }
            Write-Success "Repository cloned to server"
        }
    }
    catch {
        Write-Warning "Server pull failed: $_"
        # Continue deployment anyway
    }
}

# ── Build Web ──────────────────────────────────────────────────────────────
function Build-Web {
    param($Config, $Version)
    Write-Step "Building Web Application"
    
    try {
        # Clean previous build
        Write-Info "Cleaning previous web build"
        if (Test-Path "build/web") {
            Remove-Item -Path "build/web" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Invoke-CommandWithRetry -Description "Flutter web build" -ScriptBlock {
            flutter build web --release `
                --dart-define=SUPABASE_URL=$($Config.SUPABASE_URL) `
                --dart-define=SUPABASE_ANON_KEY=$($Config.ANON_KEY) `
                --web-renderer=canvaskit `
                --base-href="/"
            
            if ($LASTEXITCODE -ne 0) {
                throw "Flutter build failed with exit code $LASTEXITCODE"
            }
        }
        
        # Verify build output
        if (-not (Test-Path "build/web/index.html")) {
            throw "Web build output not found"
        }
        
        # Get build size
        $buildSize = (Get-ChildItem -Path "build/web" -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($buildSize / 1MB, 2)
        Write-Success "Web build size: ${sizeMB}MB"
        
        # Count files
        $fileCount = (Get-ChildItem -Path "build/web" -Recurse -File).Count
        Write-Info "Generated $fileCount files"
    }
    catch {
        throw "Web build failed: $_"
    }
}

# ── Deploy Web with Sudo ──────────────────────────────────────────────────
function Deploy-Web {
    param($Config)
    Write-Step "Deploying Web to Server"
    
    try {
        # First, ensure the web directory exists with correct permissions
        Write-Info "Preparing server directories..."
        ssh $Config.SERVER @"
            sudo mkdir -p $($Config.WEB_PATH)
            sudo mkdir -p $($Config.WEB_PATH)assets
            sudo mkdir -p $($Config.WEB_PATH)canvaskit
            sudo mkdir -p $($Config.WEB_PATH)icons
            sudo mkdir -p $($Config.WEB_PATH)download
            sudo chown -R www-data:www-data $($Config.WEB_PATH)
            sudo chmod -R 755 $($Config.WEB_PATH)
"@
        
        # Create backup of current deployment
        $backupName = "backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        Write-Info "Creating backup: $backupName"
        
        Invoke-CommandWithRetry -Description "Creating remote backup" -ScriptBlock {
            ssh $Config.SERVER @"
                cd $($Config.WEB_PATH)
                if [ -d "assets" ] || [ -d "canvaskit" ] || [ -f "index.html" ]; then
                    sudo cp -r . "../${backupName}"
                    echo "Backup created: ../${backupName}"
                else
                    echo "No existing files to backup"
                fi
"@
        }
        
        # Upload to temp directory
        Write-Info "Uploading files to temporary location..."
        $tempDir = "/tmp/playify_deploy_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        ssh $Config.SERVER "sudo mkdir -p $tempDir && sudo chmod 777 $tempDir"
        
        Invoke-CommandWithRetry -Description "Upload web files to temp" -ScriptBlock {
            scp -r build\web\* "${Config.SERVER}:${tempDir}/"
            if ($LASTEXITCODE -ne 0) {
                throw "SCP upload to temp failed"
            }
        }
        
        # Move files from temp to web path with sudo
        Write-Info "Moving files to web directory with sudo..."
        ssh $Config.SERVER @"
            sudo rm -rf $($Config.WEB_PATH)assets
            sudo rm -rf $($Config.WEB_PATH)canvaskit
            sudo rm -rf $($Config.WEB_PATH)icons
            sudo rm -f $($Config.WEB_PATH)*.html
            sudo rm -f $($Config.WEB_PATH)*.js
            sudo rm -f $($Config.WEB_PATH)*.json
            sudo rm -f $($Config.WEB_PATH)*.png
            sudo rm -f $($Config.WEB_PATH)*.wasm
            
            sudo cp -r ${tempDir}/* $($Config.WEB_PATH)
            sudo chown -R www-data:www-data $($Config.WEB_PATH)
            sudo chmod -R 755 $($Config.WEB_PATH)
            sudo rm -rf ${tempDir}
            
            echo "Files moved successfully"
"@
        
        # Test nginx configuration
        Write-Info "Testing nginx configuration..."
        ssh $Config.SERVER @"
            sudo nginx -t
            if [ $? -eq 0 ]; then
                sudo systemctl reload nginx
                echo "Nginx reloaded successfully"
            else
                echo "Nginx configuration test failed"
                exit 1
            fi
"@
        
        Write-Success "Web deployment completed successfully"
    }
    catch {
        Write-Error "Web deployment failed: $_"
        throw
    }
}

# ── Build APK ──────────────────────────────────────────────────────────────
function Build-APK {
    param($Config)
    Write-Step "Building Android APK"
    
    try {
        # Clean previous build
        Write-Info "Cleaning previous APK build"
        if (Test-Path "build/app/outputs/flutter-apk") {
            Remove-Item -Path "build/app/outputs/flutter-apk" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Invoke-CommandWithRetry -Description "Flutter APK build" -ScriptBlock {
            flutter build apk --release `
                --dart-define=SUPABASE_URL=$($Config.SUPABASE_URL) `
                --dart-define=SUPABASE_ANON_KEY=$($Config.ANON_KEY)
            
            if ($LASTEXITCODE -ne 0) {
                throw "APK build failed with exit code $LASTEXITCODE"
            }
        }
        
        # Verify APK exists and get size
        $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
        if (-not (Test-Path $apkPath)) {
            throw "APK file not found at $apkPath"
        }
        
        $apkSize = (Get-Item $apkPath).Length
        $sizeMB = [math]::Round($apkSize / 1MB, 2)
        Write-Success "APK size: ${sizeMB}MB"
    }
    catch {
        throw "APK build failed: $_"
    }
}

# ── Upload APK with Sudo ──────────────────────────────────────────────────
function Upload-APK {
    param($Config)
    Write-Step "Uploading APK to Server"
    
    try {
        # Ensure download directory exists
        ssh $Config.SERVER "sudo mkdir -p $($Config.WEB_PATH)download && sudo chown -R www-data:www-data $($Config.WEB_PATH)download"
        
        # Upload to temp location first
        $tempFile = "/tmp/Playify_$(Get-Date -Format 'yyyyMMdd_HHmmss').apk"
        
        Invoke-CommandWithRetry -Description "Upload APK to server" -ScriptBlock {
            scp build\app\outputs\flutter-apk\app-release.apk "${Config.SERVER}:${tempFile}"
            if ($LASTEXITCODE -ne 0) {
                throw "APK upload failed"
            }
        }
        
        # Move with sudo
        ssh $Config.SERVER @"
            sudo mv ${tempFile} $($Config.APK_PATH)
            sudo chown www-data:www-data $($Config.APK_PATH)
            sudo chmod 644 $($Config.APK_PATH)
            echo "APK moved to final location"
"@
        
        Write-Success "APK uploaded successfully"
    }
    catch {
        throw "APK upload failed: $_"
    }
}

# ── Generate Version Metadata ─────────────────────────────────────────────
function Generate-VersionMetadata {
    param($Version, $Config)
    Write-Step "Generating Version Metadata"
    
    try {
        $notes = Read-Host "Release notes (press Enter for default)"
        if ([string]::IsNullOrWhiteSpace($notes)) {
            $notes = "Bug fixes and improvements"
        }
        
        $mandatoryInput = Read-Host "Force update? (y/N)"
        $isMandatory = "false"
        if ($mandatoryInput -eq "y" -or $mandatoryInput -eq "Y") {
            $isMandatory = "true"
        }
        
        $today = Get-Date -Format "yyyy-MM-dd"
        $buildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Get git info
        $gitCommit = git rev-parse --short HEAD 2>$null
        $gitBranch = git branch --show-current 2>$null
        
        # Build version data as hashtable
        $versionData = @{
            version = $Version
            notes = $notes
            mandatory = $isMandatory
            apk_url = "https://${Config.DOMAIN}/download/Playify.apk"
            updated_at = $today
            build_info = @{
                build_time = $buildTime
                environment = "production"
                git_commit = $gitCommit
                git_branch = $gitBranch
            }
        }
        
        # Convert to JSON
        $versionJson = $versionData | ConvertTo-Json -Depth 4 -Compress
        
        Write-Success "Version metadata generated"
        return @{
            versionJson = $versionJson
            notes = $notes
            isMandatory = $isMandatory
            versionData = $versionData
        }
    }
    catch {
        throw "Version metadata generation failed: $_"
    }
}

# ── Deploy Version Metadata with Sudo ────────────────────────────────────
function Deploy-VersionMetadata {
    param($VersionJson, $Config)
    Write-Step "Deploying Version Metadata"
    
    try {
        # Create temporary file
        $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
        $VersionJson | Set-Content $tempFile -Encoding UTF8
        
        # Upload to temp location
        $remoteTemp = "/tmp/version_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        
        Invoke-CommandWithRetry -Description "Upload version.json" -ScriptBlock {
            scp $tempFile "${Config.SERVER}:${remoteTemp}"
            if ($LASTEXITCODE -ne 0) {
                throw "Version.json upload failed"
            }
        }
        
        # Move with sudo
        ssh $Config.SERVER @"
            sudo mv ${remoteTemp} $($Config.WEB_PATH)version.json
            sudo chown www-data:www-data $($Config.WEB_PATH)version.json
            sudo chmod 644 $($Config.WEB_PATH)version.json
            echo "Version.json deployed"
"@
        
        # Clean up temp file
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        Write-Success "Version metadata deployed"
    }
    catch {
        throw "Version metadata deployment failed: $_"
    }
}

# ── Supabase Login ─────────────────────────────────────────────────────────
function Supabase-Login {
    param($Config)
    Write-Step "Supabase Login"
    
    try {
        # Check if already logged in
        $loginCheck = supabase status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Already logged in to Supabase"
            return $true
        }
        
        Write-Info "Logging into Supabase..."
        
        # Login with access token (using JWT keys)
        $loginResult = supabase login --access-token $Config.JWT_KEYS 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Login with access token failed. Trying with legacy JWT..."
            
            # Try with legacy JWT
            $loginResult = supabase login --access-token $Config.LEGACY_JWT_SECRET 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Supabase login failed. Please login manually with 'supabase login'"
            }
        }
        
        Write-Success "Supabase login successful"
        return $true
    }
    catch {
        Write-Warning "Supabase login failed: $_"
        Write-Info "Please login manually using: supabase login"
        Write-Info "Or set environment variable: SUPABASE_ACCESS_TOKEN"
        return $false
    }
}

# ── Supabase Database Operations ──────────────────────────────────────────
function Supabase-DbPush {
    param($Config)
    Write-Step "Supabase Database Push"
    
    try {
        # First, login to Supabase
        $loginSuccess = Supabase-Login -Config $Config
        if (-not $loginSuccess) {
            Write-Warning "Skipping database push due to login failure"
            return
        }
        
        # Check for migrations
        if (Test-Path "supabase/migrations") {
            $migrationCount = (Get-ChildItem 'supabase/migrations' -Filter '*.sql').Count
            Write-Info "Found $migrationCount migration files"
            
            if ($migrationCount -eq 0) {
                Write-Info "No migration files found. Skipping database push."
                return
            }
            
            # List migrations
            Write-Info "Migration files:"
            Get-ChildItem 'supabase/migrations' -Filter '*.sql' | ForEach-Object {
                Write-Info "  - $($_.Name)"
            }
            
            # Confirm before pushing
            $confirm = Read-Host "Push $migrationCount migrations to production? (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Info "Database push cancelled by user"
                return
            }
            
            # Push migrations
            Invoke-CommandWithRetry -Description "Supabase database push" -ScriptBlock {
                # Link the project if not already linked
                $linkCheck = supabase projects list 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Info "Linking to Supabase project..."
                    supabase link --project-ref fffqjbrethogesgghjsn
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to link Supabase project"
                    }
                }
                
                # Push database changes
                supabase db push --linked
                if ($LASTEXITCODE -ne 0) {
                    throw "Supabase db push failed"
                }
            }
            Write-Success "Database migrations applied successfully"
            
            # Verify migrations
            Write-Info "Verifying database migrations..."
            $verifyResult = supabase db diff 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Database is up to date"
            } else {
                Write-Warning "Database may have pending changes"
            }
        } else {
            Write-Warning "No migration directory found at supabase/migrations"
            Write-Info "Create migrations using: supabase migration new <name>"
        }
    }
    catch {
        Write-Error "Database push failed: $_"
        Write-Info "Try running manually: supabase db push --linked"
        # Don't throw to allow deployment to continue
    }
}

# ── Supabase Status Check ─────────────────────────────────────────────────
function Supabase-CheckStatus {
    param($Config)
    Write-Step "Checking Supabase Status"
    
    try {
        # Get project status
        $status = supabase projects list 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Supabase project status:"
            Write-Info $status
        } else {
            Write-Warning "Could not get Supabase project status"
        }
        
        # Check database connection
        Write-Info "Testing database connection..."
        $dbTest = supabase db diff --db-url $Config.SUPABASE_DB_URL 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Database connection successful"
        } else {
            Write-Warning "Database connection test failed: $dbTest"
        }
    }
    catch {
        Write-Warning "Supabase status check failed: $_"
    }
}

# ── Supabase Migrations Rollback ──────────────────────────────────────────
function Supabase-Rollback {
    param($Config)
    Write-Step "Supabase Rollback (if needed)"
    
    try {
        # Check if there's a need to rollback
        $hasMigrations = Test-Path "supabase/migrations"
        if (-not $hasMigrations) {
            Write-Info "No migrations to rollback"
            return
        }
        
        # Get last migration
        $migrations = Get-ChildItem 'supabase/migrations' -Filter '*.sql' | Sort-Object Name
        if ($migrations.Count -eq 0) {
            Write-Info "No migrations to rollback"
            return
        }
        
        Write-Info "Last migration: $($migrations[-1].Name)"
        $confirm = Read-Host "Do you want to rollback the last migration? (y/N)"
        if ($confirm -eq "y" -or $confirm -eq "Y") {
            # Perform rollback
            Invoke-CommandWithRetry -Description "Supabase rollback" -ScriptBlock {
                supabase db reset --linked
                if ($LASTEXITCODE -ne 0) {
                    throw "Rollback failed"
                }
            }
            Write-Success "Database rolled back successfully"
        }
    }
    catch {
        Write-Warning "Rollback failed: $_"
    }
}

# ── Cleanup Old Backups ───────────────────────────────────────────────────
function Cleanup-OldBackups {
    param($Config)
    Write-Step "Cleaning up old backups"
    
    try {
        $backupsToKeep = 5
        ssh $Config.SERVER @"
            cd $($Config.WEB_PATH)/..
            ls -dt backup_* 2>/dev/null | tail -n +$($backupsToKeep + 1) | xargs -r sudo rm -rf
            echo "Cleaned up old backups (keeping last $backupsToKeep)"
"@
        Write-Success "Old backups cleaned"
    }
    catch {
        Write-Warning "Backup cleanup failed: $_"
    }
}

# ── Run Health Checks ─────────────────────────────────────────────────────
function Run-HealthChecks {
    param($Version, $Config)
    Write-Step "Running Health Checks"
    
    try {
        $allHealthy = $true
        
        # Check if web is accessible
        Write-Info "Checking web accessibility..."
        try {
            $webCheck = Invoke-WebRequest -Uri "https://${Config.DOMAIN}" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            if ($webCheck.StatusCode -eq 200) {
                Write-Success "Web is accessible (Status: $($webCheck.StatusCode))"
            } else {
                Write-Warning "Web returned status code: $($webCheck.StatusCode)"
                $allHealthy = $false
            }
        } catch {
            Write-Warning "Web health check failed: $_"
            $allHealthy = $false
        }
        
        # Check if APK is accessible
        Write-Info "Checking APK accessibility..."
        try {
            $apkCheck = Invoke-WebRequest -Uri "https://${Config.DOMAIN}/download/Playify.apk" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            if ($apkCheck.StatusCode -eq 200) {
                $apkSize = [math]::Round($apkCheck.Content.Length / 1MB, 2)
                Write-Success "APK is accessible (Size: ${apkSize}MB)"
            } else {
                Write-Warning "APK returned status code: $($apkCheck.StatusCode)"
                $allHealthy = $false
            }
        } catch {
            Write-Warning "APK health check failed: $_"
            $allHealthy = $false
        }
        
        # Check version.json
        Write-Info "Checking version.json..."
        try {
            $versionCheck = Invoke-WebRequest -Uri "https://${Config.DOMAIN}/version.json" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            if ($versionCheck.StatusCode -eq 200) {
                $versionJson = $versionCheck.Content | ConvertFrom-Json
                Write-Success "Version.json is accessible"
                Write-Info "  Deployed version: v$($versionJson.version)"
                Write-Info "  Updated: $($versionJson.updated_at)"
                Write-Info "  Notes: $($versionJson.notes)"
                
                if ($versionJson.mandatory -eq "true") {
                    Write-Warning "  Force update is ON"
                } else {
                    Write-Info "  Force update is OFF"
                }
            } else {
                Write-Warning "Version.json returned status code: $($versionCheck.StatusCode)"
                $allHealthy = $false
            }
        } catch {
            Write-Warning "Version.json health check failed: $_"
            $allHealthy = $false
        }
        
        return $allHealthy
    }
    catch {
        Write-Warning "Health checks failed: $_"
        return $false
    }
}

# ── Send Notification ─────────────────────────────────────────────────────
function Send-Notification {
    param($Version, $Success, $Config, $Duration)
    
    Write-Step "Sending Deployment Notification"
    
    try {
        $status = if ($Success) { "✅ SUCCESS" } else { "❌ FAILED" }
        $durationMinutes = [math]::Round($Duration.TotalMinutes, 2)
        
        # Create notification message
        $message = @"
PLAYIFY DEPLOYMENT $status
Version: v$Version
Duration: ${durationMinutes} minutes
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Environment: Production
Server: $($Config.SERVER_IP)
Domain: $($Config.DOMAIN)

Web: https://$($Config.DOMAIN)
APK: https://$($Config.DOMAIN)/download/Playify.apk
"@
        
        # Log notification
        Write-Info "Notification prepared:"
        Write-Info $message
        
        Write-Success "Notification sent successfully"
    }
    catch {
        Write-Warning "Notification failed: $_"
    }
}

# ── Main Execution ──────────────────────────────────────────────────────
function Main {
    $startTime = Get-Date
    
    try {
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║          🚀  PLAYIFY BUILD & DEPLOY PIPELINE  v2.3                  ║
║                                                                       ║
║          Deploying to: $($CONFIG.SERVER_IP)                           ║
║          Environment: Production                                      ║
║          Supabase: $($CONFIG.SUPABASE_URL)                           ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta
        
        # Test SSH connection first
        Test-SSHConnection -Config $CONFIG
        
        # Test prerequisites
        Test-Prerequisites
        
        # Get version
        $version = Get-Version
        
        # Update git locally
        Update-GitRepository -Version $version
        
        # Pull latest on server
        Pull-ServerLatest -Config $CONFIG
        
        # Build and deploy web
        Build-Web -Config $CONFIG -Version $version
        Deploy-Web -Config $CONFIG
        
        # Build and deploy APK
        Build-APK -Config $CONFIG
        Upload-APK -Config $CONFIG
        
        # Generate and deploy version metadata
        $metadata = Generate-VersionMetadata -Version $version -Config $CONFIG
        Deploy-VersionMetadata -VersionJson $metadata.versionJson -Config $CONFIG
        
        # Supabase Database Operations
        Write-Step "Supabase Database Operations"
        $dbChoice = Read-Host "Do you want to run Supabase database operations? (y/N)"
        if ($dbChoice -eq "y" -or $dbChoice -eq "Y") {
            # Check Supabase status
            Supabase-CheckStatus -Config $CONFIG
            
            # Push database migrations
            Supabase-DbPush -Config $CONFIG
            
            # Optional rollback
            $rollbackChoice = Read-Host "Do you want to check rollback options? (y/N)"
            if ($rollbackChoice -eq "y" -or $rollbackChoice -eq "Y") {
                Supabase-Rollback -Config $CONFIG
            }
        } else {
            Write-Info "Skipping Supabase database operations"
        }
        
        # Cleanup and health checks
        Cleanup-OldBackups -Config $CONFIG
        $healthStatus = Run-HealthChecks -Version $version -Config $CONFIG
        
        # Calculate duration
        $duration = (Get-Date) - $startTime
        $durationMinutes = [math]::Round($duration.TotalMinutes, 2)
        
        # Send notification
        Send-Notification -Version $version -Success $true -Config $CONFIG -Duration $duration
        
        # ── Deployment Complete ────────────────────────────────────────────────
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║  ✅  PLAYIFY v$version DEPLOYED SUCCESSFULLY!                         ║
║                                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  🌐 Web:   https://$($CONFIG.DOMAIN)                                 ║
║  📱 APK:   https://$($CONFIG.DOMAIN)/download/Playify.apk           ║
║  📋 Notes: $($metadata.notes)                                        ║
║  ⚠️  Force: $(if ($metadata.isMandatory -eq "true") { "ON" } else { "OFF" }) ║
║                                                                       ║
║  ⏱️  Duration: $durationMinutes minutes                               ║
║  📄 Log:   $LOG_FILE                                                 ║
║                                                                       ║
║  🏥 Health: $(if ($healthStatus) { "✅ All systems healthy" } else { "⚠️  Some checks failed" }) ║
║  🖥️  Server: $($CONFIG.SERVER_IP)                                    ║
║  🗄️  Supabase: $($CONFIG.SUPABASE_URL)                              ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green
        
        Write-Success "Deployment completed in $durationMinutes minutes"
        return 0
    }
    catch {
        $duration = (Get-Date) - $startTime
        $durationMinutes = [math]::Round($duration.TotalMinutes, 2)
        
        Write-Error "Deployment failed after $durationMinutes minutes"
        Write-Error "Error: $_"
        
        # Send failure notification
        Send-Notification -Version $version -Success $false -Config $CONFIG -Duration $duration
        
        exit 1
    }
}

# ── Execute ──────────────────────────────────────────────────────────────
Main