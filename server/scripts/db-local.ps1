<#
.SYNOPSIS
  Start/stop/inspect the machine-local PostgreSQL instance used for iBuild
  server development on Windows (no Docker required).

.DESCRIPTION
  Wraps pg_ctl/psql from the portable PostgreSQL install already extracted
  under .tools/pg/pgsql (repo root), operating on the data directory at
  .tools/pgdata. Both live outside version control (see the root
  .gitignore) - this script is what makes that machine-local setup
  reproducible without re-reading these notes every time.

  If .tools/pg or .tools/pgdata don't exist yet, see "First-time setup" in
  ../README.md#local-dev-database-windows-no-docker - this script only
  manages an *already initialized* install; it doesn't download or initdb
  one from scratch.

.PARAMETER Action
  One of: start, stop, restart, status, psql. Defaults to "start".

.EXAMPLE
  ./db-local.ps1 start
  ./db-local.ps1 psql        # opens an interactive psql session on ibuild
  ./db-local.ps1 stop
#>
param(
    [ValidateSet('start', 'stop', 'restart', 'status', 'psql')]
    [string]$Action = 'start'
)

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$PgBin = Join-Path $RepoRoot '.tools\pg\pgsql\bin'
$PgData = Join-Path $RepoRoot '.tools\pgdata'
$PgLog = Join-Path $PgData 'server.log'

# Prefer server/.env; fallback password is for local portable Postgres only.
$EnvFile = Join-Path $PSScriptRoot '..\.env'
$DevDbUser = 'ibuild'
$DevDbPassword = 'changeme'
$DevDbName = 'ibuild'
if (Test-Path $EnvFile) {
  Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*DB_USER=(.*)$') { $DevDbUser = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($_ -match '^\s*DB_PASSWORD=(.*)$') { $DevDbPassword = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($_ -match '^\s*DB_NAME=(.*)$') { $DevDbName = $Matches[1].Trim().Trim('"').Trim("'") }
  }
}

function Assert-Install {
    if (-not (Test-Path $PgBin)) {
        Write-Error "PostgreSQL binaries not found at $PgBin. See ../README.md#local-dev-database-windows-no-docker for first-time setup."
        exit 1
    }
    if (-not (Test-Path $PgData) -and $Action -ne 'start') {
        Write-Error "No data directory at $PgData yet - run first-time setup first (see README)."
        exit 1
    }
}

Assert-Install

switch ($Action) {
    'start' {
        & "$PgBin\pg_ctl.exe" start -D $PgData -l $PgLog -w -t 180
        Write-Host ""
        Write-Host "PostgreSQL is up on localhost:5432. Run the server against it with:" -ForegroundColor Green
        Write-Host "  .\scripts\run-with-db.ps1"
    }
    'stop' {
        & "$PgBin\pg_ctl.exe" stop -D $PgData -m fast -w -t 60
    }
    'restart' {
        & "$PgBin\pg_ctl.exe" restart -D $PgData -l $PgLog -w -t 180
    }
    'status' {
        & "$PgBin\pg_ctl.exe" status -D $PgData
    }
    'psql' {
        $env:PGPASSWORD = $DevDbPassword
        & "$PgBin\psql.exe" -h localhost -p 5432 -U $DevDbUser -d $DevDbName
    }
}
