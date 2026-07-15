<#
.SYNOPSIS
  Stops the full iBuild local stack: Flutter clients, API server, PostgreSQL.

.DESCRIPTION
  Companion to launch-stack.ps1. Kills processes bound to the dev ports
  (8099 B2C, 8100 B2B, 4000 API) and stops the portable Postgres instance
  via server/scripts/db-local.ps1 stop.

.PARAMETER SkipDb
  Leave PostgreSQL running.

.PARAMETER Force
  Skip confirmation prompt.

.EXAMPLE
  .\scripts\stop-stack.ps1
  .\scripts\stop-stack.ps1 -SkipDb -Force
#>
param(
  [switch]$SkipDb,
  [switch]$Force
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $Root 'server'

$Ports = @(
  @{ Port = 8099; Label = 'B2C client' }
  @{ Port = 8100; Label = 'B2B admin' }
  @{ Port = 4000; Label = 'API server' }
)

function Get-ListenerPids {
  param([int]$Port)

  $pids = @()
  try {
    $pids = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess -Unique
  } catch {
    # Get-NetTCPConnection unavailable on some setups; fall back to netstat.
    $lines = netstat -ano -p tcp | Select-String ":\s*$Port\s+.*LISTENING"
    foreach ($line in $lines) {
      $parts = ($line -replace '\s+', ' ').ToString().Trim().Split(' ')
      if ($parts.Length -ge 5) {
        $pids += [int]$parts[-1]
      }
    }
    $pids = $pids | Select-Object -Unique
  }
  return $pids | Where-Object { $_ -gt 0 }
}

function Stop-PortListeners {
  param(
    [int]$Port,
    [string]$Label
  )

  $pids = Get-ListenerPids -Port $Port
  if (-not $pids -or $pids.Count -eq 0) {
    Write-Host "  $Label (port $Port): not running" -ForegroundColor DarkGray
    return
  }

  foreach ($procId in $pids) {
    try {
      $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
      $name = if ($proc) { $proc.ProcessName } else { 'unknown' }
      Stop-Process -Id $procId -Force -ErrorAction Stop
      Write-Host "  Stopped $Label (port $Port, PID $procId, $name)" -ForegroundColor Yellow
    } catch {
      Write-Host "  Could not stop $Label (port $Port, PID $procId): $($_.Exception.Message)" -ForegroundColor Red
    }
  }
}

if (-not $Force) {
  Write-Host 'This will stop iBuild dev services (B2C, B2B, API'
  if (-not $SkipDb) { Write-Host 'and PostgreSQL' }
  Write-Host ').'
  $answer = Read-Host 'Continue? [y/N]'
  if ($answer -notmatch '^[yY]') {
    Write-Host 'Cancelled.'
    exit 0
  }
}

Write-Host ''
Write-Host 'Stopping iBuild stack...' -ForegroundColor Cyan

foreach ($entry in $Ports) {
  Stop-PortListeners -Port $entry.Port -Label $entry.Label
}

if (-not $SkipDb) {
  Write-Host '  Stopping PostgreSQL...' -ForegroundColor Yellow
  Push-Location $ServerDir
  try {
    & powershell -ExecutionPolicy Bypass -File .\scripts\db-local.ps1 stop 2>&1 | ForEach-Object {
      Write-Host "    $_" -ForegroundColor DarkGray
    }
    Write-Host '  PostgreSQL stop requested.' -ForegroundColor Yellow
  } catch {
    Write-Host "  PostgreSQL stop failed: $($_.Exception.Message)" -ForegroundColor Red
  } finally {
    Pop-Location
  }
}

# Close leftover PowerShell windows opened by launch-stack.ps1 (API/B2C/B2B only).
# PostgreSQL runs as a background daemon (pg_ctl), not in a titled window.
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $title = $_.MainWindowTitle
    if ($title -like 'iBuild - API*' -or $title -like 'iBuild - B2C*' -or $title -like 'iBuild - B2B*') {
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
      Write-Host "  Closed window: $title" -ForegroundColor DarkGray
    }
  } catch {
    # Window may already be gone.
  }
}

Write-Host ''
Write-Host 'Stack stopped.' -ForegroundColor Green
