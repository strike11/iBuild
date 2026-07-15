<#
.SYNOPSIS
  Runs the iBuild API against local PostgreSQL using server/.env only.

.DESCRIPTION
  Does not hardcode DB credentials. Ensure server/.env exists (copy from
  .env.example) and PostgreSQL is running (./db-local.ps1 start).

.EXAMPLE
  ./db-local.ps1 start
  ./run-with-db.ps1
#>

$ServerRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $ServerRoot '.env'
$Example = Join-Path $ServerRoot '.env.example'

if (-not (Test-Path $EnvFile)) {
  if (-not (Test-Path $Example)) {
    throw "Missing $Example"
  }
  Copy-Item $Example $EnvFile
  Write-Host "Created $EnvFile - set DB_PASSWORD to match your local Postgres." -ForegroundColor Yellow
}

Push-Location $ServerRoot
try {
  dart run bin/server.dart
}
finally {
  Pop-Location
}
