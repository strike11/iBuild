# Build B2B + B2C Flutter web bundles for IP staging and upload hints.
#
# Usage (from repo root, PowerShell):
#   .\scripts\staging-build-frontends.ps1 -ServerIp 203.0.113.10
#   .\scripts\staging-build-frontends.ps1 -ServerIp 203.0.113.10 -Upload -SshHost deploy@203.0.113.10

param(
  [Parameter(Mandatory = $true)]
  [string] $ServerIp,

  [switch] $Upload,
  [string] $SshHost = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$apiBase = "http://${ServerIp}/v1"
$wsUrl = "ws://${ServerIp}/v1/ws"
$adminUrl = "http://${ServerIp}:8080"

Write-Host "API:    $apiBase"
Write-Host "WS:     $wsUrl"
Write-Host "Admin:  $adminUrl"

# --- B2B ---------------------------------------------------------------------
$B2bDefines = Join-Path $RepoRoot "b2b/dart_defines.staging.json"
@{
  API_BASE_URL = $apiBase
  WS_URL       = $wsUrl
} | ConvertTo-Json | Set-Content -Encoding utf8 $B2bDefines

Push-Location (Join-Path $RepoRoot "b2b")
flutter pub get
flutter build web --release --pwa-strategy=none --dart-define-from-file=dart_defines.staging.json
Pop-Location

# --- B2C ---------------------------------------------------------------------
$B2cDefines = Join-Path $RepoRoot "b2c/dart_defines.staging.json"
@{
  USE_MOCK_DATA = "false"
  API_BASE_URL  = $apiBase
  WS_URL        = $wsUrl
  BUSINESS_URL  = $adminUrl
} | ConvertTo-Json | Set-Content -Encoding utf8 $B2cDefines

Push-Location (Join-Path $RepoRoot "b2c")
flutter pub get
flutter build web --release --pwa-strategy=none --dart-define-from-file=dart_defines.staging.json
Pop-Location

Write-Host ""
Write-Host "Built:"
Write-Host "  b2b/build/web  -> /var/www/ibuild/admin"
Write-Host "  b2c/build/web  -> /var/www/ibuild/app"

if ($Upload) {
  if (-not $SshHost) { $SshHost = "deploy@${ServerIp}" }
  Write-Host "Uploading to ${SshHost} ..."
  scp -r (Join-Path $RepoRoot "b2c/build/web") "${SshHost}:/tmp/ibuild-app-src"
  scp -r (Join-Path $RepoRoot "b2b/build/web") "${SshHost}:/tmp/ibuild-admin-src"
  ssh $SshHost "sudo rsync -a --delete /tmp/ibuild-app-src/ /var/www/ibuild/app/ && sudo rsync -a --delete /tmp/ibuild-admin-src/ /var/www/ibuild/admin/ && sudo chown -R www-data:www-data /var/www/ibuild && rm -rf /tmp/ibuild-app-src /tmp/ibuild-admin-src"
  Write-Host "Upload complete."
}
