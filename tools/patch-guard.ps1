param(
    [Parameter(Mandatory = $true)]
    [string]$File
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

$configPath = Join-Path $PSScriptRoot "protected-files.json"

if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: protected-files.json not found." -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$normalized = $File.Replace("/", "\").TrimStart(".\")

$lockedFiles = @(
    $config.lockedFiles |
        ForEach-Object {
            $_.Replace("/", "\").TrimStart(".\")
        }
)

# ------------------------------------------------------------
# Password
# ------------------------------------------------------------

$PASSWORD = "sport123"

# ------------------------------------------------------------
# Protection check
# ------------------------------------------------------------

if ($lockedFiles -contains $normalized) {

    $authorization = Join-Path `
        (Get-Location) `
        "$normalized.unlocked"

    if (Test-Path $authorization) {
        Write-Host "TEMPORARILY UNLOCKED: $normalized" -ForegroundColor Yellow
        exit 0
    }

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "             FILE IS PROTECTED" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "BLOCKED: $normalized" -ForegroundColor Red
    Write-Host ""

    # --------------------------------------------------------
    # Ask for password
    # --------------------------------------------------------

    $securePassword = Read-Host "Enter unlock password" -AsSecureString

    $credential = New-Object System.Management.Automation.PSCredential(
        "unlock",
        $securePassword
    )

    $enteredPassword = $credential.GetNetworkCredential().Password

    if ($enteredPassword -ne $PASSWORD) {
        Write-Host ""
        Write-Host "ACCESS DENIED." -ForegroundColor Red
        Write-Host "Incorrect password." -ForegroundColor Red
        Write-Host ""
        exit 10
    }

    # --------------------------------------------------------
    # Create temporary authorization
    # --------------------------------------------------------

    $authorizationDirectory = Split-Path $authorization -Parent

    if (-not (Test-Path $authorizationDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $authorizationDirectory `
            -Force | Out-Null
    }

    Set-Content `
        -Path $authorization `
        -Value "AUTHORIZED $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" `
        -Encoding UTF8

    Write-Host ""
    Write-Host "PASSWORD ACCEPTED." -ForegroundColor Green
    Write-Host "TEMPORARILY UNLOCKED: $normalized" -ForegroundColor Yellow
    Write-Host ""

    exit 0
}

Write-Host "OK: File is not protected." -ForegroundColor Green
exit 0
