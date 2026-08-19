param(
    [Parameter(Mandatory=$true)]
    [string]$File
)

$config = Get-Content ".\tools\protected-files.json" -Raw | ConvertFrom-Json
$normalized = $File.Replace("\","/")

if ($config.lockedFiles -contains $normalized) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "             FILE IS PROTECTED" -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "FILE: $normalized" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "MODIFICATION BLOCKED." -ForegroundColor Red
    Write-Host ""
    Write-Host "To modify this file, obtain explicit approval first." -ForegroundColor Cyan
    Write-Host ""
    exit 10
}

exit 0
