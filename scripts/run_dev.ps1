param(
  [string]$Device = 'chrome'
)

$envFile = Join-Path $PSScriptRoot '..\.env'
if (-not (Test-Path $envFile)) {
  throw "Missing .env file at $envFile"
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

flutter run -d $Device --dart-define="SUPABASE_URL=$supabaseUrl" --dart-define="SUPABASE_ANON_KEY=$supabaseAnonKey"
