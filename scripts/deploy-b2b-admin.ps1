# Upload a fresh B2B web build to production (admin.ibuild.uz).
#
# Usage:
#   .\scripts\deploy-b2b-admin.ps1
#   .\scripts\deploy-b2b-admin.ps1 -SkipBuild

param(
  [string] $ServerIp = "46.8.176.254",
  [string] $SshUser = "ubuntu",
  [string] $SshKey = "",
  [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$B2bDir = Join-Path $RepoRoot "b2b"

if (-not $SshKey) {
  $SshKey = Join-Path $RepoRoot ".tools/github-deploy-key/id_ed25519"
}
if (-not (Test-Path $SshKey)) {
  throw "SSH key not found: $SshKey"
}

$SshHost = "${SshUser}@${ServerIp}"
$SshBase = @("-i", $SshKey, "-o", "StrictHostKeyChecking=no")
$ScpBase = @("-i", $SshKey, "-o", "StrictHostKeyChecking=no")

function Invoke-Ssh([string]$Cmd) {
  & ssh @SshBase $SshHost $Cmd
  if ($LASTEXITCODE -ne 0) { throw "ssh failed: $Cmd" }
}

function Invoke-Scp([string[]]$ScpArgs) {
  & scp @ScpBase @ScpArgs
  if ($LASTEXITCODE -ne 0) { throw "scp failed" }
}

if (-not $SkipBuild) {
  $defines = Join-Path $B2bDir "dart_defines.staging.json"
  if (-not (Test-Path $defines)) {
    @{
      API_BASE_URL = "https://api.ibuild.uz/v1"
      WS_URL       = "wss://api.ibuild.uz/v1/ws"
    } | ConvertTo-Json | Set-Content -Encoding utf8 $defines
  }
  Push-Location $B2bDir
  try {
    flutter pub get
    flutter build web --release --pwa-strategy=none --dart-define-from-file=dart_defines.staging.json
  } finally {
    Pop-Location
  }
}

$webRoot = Join-Path $B2bDir "build/web"
if (-not (Test-Path (Join-Path $webRoot "main.dart.js"))) {
  throw "Missing $webRoot/main.dart.js - run build first"
}

Write-Host "==> Upload B2B admin to $SshHost"
Invoke-Ssh "rm -rf /tmp/ibuild-admin-src"
Invoke-Scp @("-r", $webRoot, "${SshHost}:/tmp/ibuild-admin-src")

$Killswitch = Join-Path $RepoRoot "server/deploy/flutter-service-worker-killswitch.js"
Invoke-Scp @($Killswitch, "${SshHost}:/tmp/flutter-service-worker-killswitch.js")

$remote = @'
set -eu
docker run --rm -v /tmp/ibuild-admin-src:/src:ro -v /var/www/ibuild/admin:/dest alpine:3.20 \
  sh -c 'rm -rf /dest/* && cp -a /src/. /dest/ && chown -R 33:33 /dest'
docker run --rm \
  -v /tmp/flutter-service-worker-killswitch.js:/src/sw.js:ro \
  -v /var/www/ibuild/admin:/dest alpine:3.20 \
  sh -c 'cp /src/sw.js /dest/flutter_service_worker.js && chown 33:33 /dest/flutter_service_worker.js && chmod 644 /dest/flutter_service_worker.js'
rm -rf /tmp/ibuild-admin-src /tmp/flutter-service-worker-killswitch.js
docker run --rm --privileged --pid=host -v /run:/run --user 0:0 alpine:3.20 \
  sh -c 'kill -HUP "$(cat /run/nginx.pid)"' 2>/dev/null || true
echo "==> Deployed $(sha256sum /var/www/ibuild/admin/main.dart.js | cut -d" " -f1)"
'@
$remote = $remote -replace "`r`n", "`n"
Invoke-Ssh $remote

Write-Host ""
Write-Host "B2B admin deployed: https://admin.ibuild.uz/"
