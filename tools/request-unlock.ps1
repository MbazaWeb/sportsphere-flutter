param(
    [Parameter(Mandatory=$true)]
    [string]$File,

    [Parameter(Mandatory=$true)]
    [string]$Reason
)

$configPath = ".\tools\protected-files.json"

if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Protection configuration not found." -ForegroundColor Red
    exit 2
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$normalized = $File.Replace("\","/")

if (-not ($config.lockedFiles -contains $normalized)) {
    Write-Host "FILE IS NOT PROTECTED: $normalized" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Red
Write-Host "          PROTECTED FILE UNLOCK REQUEST" -ForegroundColor Red
Write-Host "==================================================" -ForegroundColor Red
Write-Host ""
Write-Host "File:   $normalized" -ForegroundColor Yellow
Write-Host "Reason: $Reason" -ForegroundColor Yellow
Write-Host ""

$securePassword = Read-Host "Enter unlock password" -AsSecureString

$credential = New-Object System.Management.Automation.PSCredential(
    "SportSphere",
    $securePassword
)

$password = $credential.GetNetworkCredential().Password

if ($password -ne "sport123") {
    Write-Host ""
    Write-Host "ACCESS DENIED." -ForegroundColor Red
    Write-Host "File remains LOCKED." -ForegroundColor Red
    Write-Host ""
    exit 30
}

Write-Host ""
Write-Host "PASSWORD ACCEPTED." -ForegroundColor Green
Write-Host ""

$unlockPath = "$normalized.unlocked"

Set-Content `
    -Path $unlockPath `
    -Value "UNLOCKED" `
    -Encoding UTF8

Write-Host "UNLOCK AUTHORIZATION CREATED." -ForegroundColor Green
Write-Host "Target: $normalized" -ForegroundColor Yellow
Write-Host ""

exit 0
