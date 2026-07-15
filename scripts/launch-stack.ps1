<#
.SYNOPSIS
  Starts the full iBuild local stack: PostgreSQL, API server, B2C client, B2B admin.

.DESCRIPTION
  Opens separate PowerShell windows so each process keeps running independently.
  DB credentials come from server/.env (auto-loaded by the API) - not hardcoded here.
  Flutter apps use dart_defines.dev.json when present.

.PARAMETER SkipDb
  Skip starting PostgreSQL (use when Postgres is already running).

.PARAMETER SkipB2c
  Skip launching the B2C Flutter web client (port 8099).

.PARAMETER SkipB2b
  Skip launching the B2B Flutter web client (port 8100).

.EXAMPLE
  .\scripts\launch-stack.ps1
  .\scripts\launch-stack.ps1 -SkipDb
#>
param(
  [switch]$SkipDb,
  [switch]$SkipB2c,
  [switch]$SkipB2b
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $Root 'server'
$B2cDir = Join-Path $Root 'b2c'
$B2bDir = Join-Path $Root 'b2b'

function Ensure-DartDefines {
  param([string]$AppDir, [string]$ExampleName)
  $target = Join-Path $AppDir 'dart_defines.dev.json'
  $example = Join-Path $AppDir $ExampleName
  if (-not (Test-Path $target)) {
    if (-not (Test-Path $example)) {
      throw "Missing $example - cannot create $target"
    }
    Copy-Item $example $target
    Write-Host "Created $target from example" -ForegroundColor Yellow
  }
  return $target
}

function Start-StackWindow {
  param(
    [string]$Title,
    [string]$Command
  )
  Write-Host "Starting $Title..."
  Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "`$host.UI.RawUI.WindowTitle = '$Title'; $Command"
  ) | Out-Null
}

function Read-EnvValue {
  param(
    [string]$FilePath,
    [string]$Key,
    [string]$Default
  )
  if (-not (Test-Path $FilePath)) { return $Default }
  foreach ($line in Get-Content $FilePath) {
    if ($line -match "^\s*$([regex]::Escape($Key))=(.*)$") {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return $Default
}

function Wait-PostgreSQLReady {
  param(
    [string]$HostName = 'localhost',
    [int]$Port = 5432,
    [string]$User = 'ibuild',
    [string]$Database = 'ibuild',
    [int]$TimeoutSeconds = 180
  )

  $PgIsReady = Join-Path $Root '.tools\pg\pgsql\bin\pg_isready.exe'
  if (-not (Test-Path $PgIsReady)) {
    Write-Host 'pg_isready not found - falling back to 30s sleep' -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    return
  }

  Write-Host 'PostgreSQL may reject connections for up to 60s while recovering' -ForegroundColor DarkGray
  Write-Host 'after an unclean shutdown (fsync/REDO). This is normal on Windows.' -ForegroundColor DarkGray

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $attempt = 0
  while ((Get-Date) -lt $deadline) {
    $attempt++
    $status = & $PgIsReady -h $HostName -p $Port -U $User -d $Database -t 3 2>&1 |
      ForEach-Object { $_.ToString() } |
      Select-Object -First 1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "PostgreSQL ready (attempt $attempt)." -ForegroundColor Green
      return
    }
    Write-Host "Waiting for PostgreSQL... (attempt $attempt) $status"
    Start-Sleep -Seconds 3
  }

  $logHint = Join-Path $Root '.tools\pgdata\server.log'
  throw "PostgreSQL did not become ready within ${TimeoutSeconds}s. Check $logHint (look for 'ready to accept connections' or startup errors)."
}

$envFile = Join-Path $ServerDir '.env'
if (-not (Test-Path $envFile)) {
  $example = Join-Path $ServerDir '.env.example'
  Copy-Item $example $envFile
  Write-Host "Created server/.env from .env.example - set DB_PASSWORD for local DB" -ForegroundColor Yellow
}

if (-not $SkipDb) {
  Write-Host 'Starting PostgreSQL...' -ForegroundColor Cyan
  Push-Location $ServerDir
  try {
    & powershell -ExecutionPolicy Bypass -File .\scripts\db-local.ps1 start
    if ($LASTEXITCODE -ne 0) {
      throw "db-local.ps1 start failed (exit $LASTEXITCODE). See .tools/pgdata/server.log"
    }
  } finally {
    Pop-Location
  }
}

$dbHost = Read-EnvValue -FilePath $envFile -Key 'DB_HOST' -Default 'localhost'
$dbPort = [int](Read-EnvValue -FilePath $envFile -Key 'DB_PORT' -Default '5432')
$dbUser = Read-EnvValue -FilePath $envFile -Key 'DB_USER' -Default 'ibuild'
$dbName = Read-EnvValue -FilePath $envFile -Key 'DB_NAME' -Default 'ibuild'
if ($dbHost) {
  Write-Host 'Waiting for PostgreSQL to accept connections...'
  Wait-PostgreSQLReady -HostName $dbHost -Port $dbPort -User $dbUser -Database $dbName
}

# API loads DB_* from server/.env via env_loader - do not hardcode passwords here.
Start-StackWindow -Title 'iBuild - API Server' -Command @"
Set-Location '$ServerDir'
dart run bin/server.dart
"@

Start-Sleep -Seconds 3

if (-not $SkipB2c) {
  $b2cDefines = Ensure-DartDefines -AppDir $B2cDir -ExampleName 'dart_defines.dev.json.example'
  $b2cCmd = "Set-Location '$B2cDir'; flutter run -d edge --web-port=8099 --dart-define-from-file=`"$b2cDefines`""
  Start-StackWindow -Title 'iBuild - B2C (8099)' -Command $b2cCmd
}

if (-not $SkipB2b) {
  $b2bDefines = Ensure-DartDefines -AppDir $B2bDir -ExampleName 'dart_defines.dev.json.example'
  $b2bCmd = "Set-Location '$B2bDir'; flutter run -d edge --web-port=8100 --dart-define-from-file=`"$b2bDefines`""
  Start-StackWindow -Title 'iBuild - B2B (8100)' -Command $b2bCmd
}

Write-Host ''
Write-Host 'Stack launch requested.' -ForegroundColor Green
Write-Host '  API:  http://localhost:4000/v1'
if (-not $SkipB2c) { Write-Host '  B2C:  http://localhost:8099' }
if (-not $SkipB2b) { Write-Host '  B2B:  http://localhost:8100' }
Write-Host '  Config: server/.env + */dart_defines.dev.json'
Write-Host ''
Write-Host 'Close each window to stop that service, or run .\scripts\stop-stack.ps1'
