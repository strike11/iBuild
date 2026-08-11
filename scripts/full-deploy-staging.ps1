# Full codebase sync + API rebuild + B2B/B2C web deploy to staging VDS.
#
# Usage (from repo root):
#   .\scripts\full-deploy-staging.ps1 -ServerIp 46.8.176.254
#   .\scripts\full-deploy-staging.ps1 -ServerIp 46.8.176.254 -SkipBuild

param(
  [Parameter(Mandatory = $true)]
  [string] $ServerIp,

  [string] $SshUser = "ubuntu",
  [string] $SshKey = "",
  [switch] $UseIpStaging,
  [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

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

Write-Host "==> Target: $SshHost"
Write-Host "==> API:    http://${ServerIp}/v1"

if (-not $SkipBuild) {
  $buildArgs = @("-ServerIp", $ServerIp)
  if ($UseIpStaging) { $buildArgs += "-UseIpStaging" }
  & (Join-Path $RepoRoot "scripts/staging-build-frontends.ps1") @buildArgs
}

Write-Host "==> Pack project sources (~40 MB, no .tools/build junk)..."
$TarPath = Join-Path $env:TEMP "ibuild-src-$(Get-Date -Format 'yyyyMMddHHmmss').tgz"
Push-Location $RepoRoot
try {
  $include = @(
    "b2b", "b2c", "server", "packages", "scripts", ".github",
    "README.md", "DESIGN", "ibuild-wiki", "investment", "presentation"
  )
  $excludeArgs = @(
    "--exclude=build", "--exclude=.dart_tool", "--exclude=windows",
    "--exclude=android", "--exclude=ios", "--exclude=.idea", "--exclude=node_modules"
  )
  & tar -czf $TarPath @excludeArgs @include
  if ($LASTEXITCODE -ne 0) { throw "tar pack failed" }
  Write-Host "    Archive: $TarPath ($([math]::Round((Get-Item $TarPath).Length / 1MB, 1)) MB)"
} finally {
  Pop-Location
}

Write-Host "==> Upload codebase + web builds..."
Invoke-Scp @($TarPath, "${SshHost}:/tmp/ibuild-src.tgz")
Invoke-Ssh "rm -rf /tmp/ibuild-www-src && mkdir -p /tmp/ibuild-www-src"
Invoke-Scp @("-r", (Join-Path $RepoRoot "www/."), "${SshHost}:/tmp/ibuild-www-src/")
Invoke-Scp @("-r", (Join-Path $RepoRoot "b2c/build/web"), "${SshHost}:/tmp/ibuild-app-src")
Invoke-Scp @("-r", (Join-Path $RepoRoot "b2b/build/web"), "${SshHost}:/tmp/ibuild-admin-src")

Write-Host "==> Extract on server + deploy..."
$RemoteSh = Join-Path $env:TEMP "ibuild-remote-deploy.sh"
$remoteBody = @'
#!/usr/bin/env bash
set -eu

echo "==> Extract codebase to /opt/ibuild/source/ibuild"
mkdir -p /opt/ibuild/source/ibuild
rm -rf /opt/ibuild/source/ibuild/*
tar xzf /tmp/ibuild-src.tgz -C /opt/ibuild/source/ibuild

echo "==> Sync server source for Docker build"
docker run --rm -v /opt/ibuild/source:/src alpine:3.20 sh -c 'rm -rf /src/server && cp -a /src/ibuild/server /src/server && chown -R 1000:1000 /src/server'

echo "==> Sync deploy scripts"
mkdir -p /opt/ibuild/deploy
cp -f /opt/ibuild/source/ibuild/server/deploy/docker-compose.yml /opt/ibuild/deploy/
cp -f /opt/ibuild/source/ibuild/server/deploy/first-deploy.sh /opt/ibuild/deploy/
cp -f /opt/ibuild/source/ibuild/server/deploy/healthcheck-docker.sh /opt/ibuild/deploy/
cp -f /opt/ibuild/source/ibuild/server/deploy/sync-residences-images.sh /opt/ibuild/deploy/
cp -f /opt/ibuild/source/ibuild/server/scripts/full-deploy-remote.sh /opt/ibuild/deploy/
cp -f /opt/ibuild/source/ibuild/server/scripts/relaunch-api.sh /opt/ibuild/deploy/
chmod +x /opt/ibuild/deploy/*.sh
sed -i 's/\r$//' /opt/ibuild/deploy/*.sh 2>/dev/null || true

echo "==> Update CORS for production domains"
PROD_ORIGINS="https://app.ibuild.uz,https://admin.ibuild.uz,https://www.ibuild.uz,https://ibuild.uz,http://${ServerIp:-46.8.176.254},http://${ServerIp:-46.8.176.254}:8080,http://${ServerIp:-46.8.176.254}:8081"
if grep -q '^ALLOWED_ORIGINS=' /opt/ibuild/server/.env; then
  sed -i "s|^ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=${PROD_ORIGINS}|" /opt/ibuild/server/.env
else
  echo "ALLOWED_ORIGINS=${PROD_ORIGINS}" >> /opt/ibuild/server/.env
fi

echo "==> Sync residence images"
mkdir -p /opt/ibuild/server/residences-images
cp -a /opt/ibuild/source/ibuild/server/residences-images/. /opt/ibuild/server/residences-images/ 2>/dev/null || true

echo "==> Install relaunch helper in home"
cp -f /opt/ibuild/source/ibuild/server/scripts/relaunch-api.sh ~/ibuild-relaunch.sh
chmod +x ~/ibuild-relaunch.sh
sed -i 's/\r$//' ~/ibuild-relaunch.sh 2>/dev/null || true

echo "==> Run full deploy (API + web)"
sed -i 's/\r$//' /opt/ibuild/deploy/full-deploy-remote.sh
bash /opt/ibuild/deploy/full-deploy-remote.sh

rm -f /tmp/ibuild-src.tgz
echo "==> Done. Codebase at /opt/ibuild/source/ibuild"
'@
$remoteBody = $remoteBody -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($RemoteSh, $remoteBody, (New-Object System.Text.UTF8Encoding $false))
Invoke-Scp @($RemoteSh, "${SshHost}:/tmp/ibuild-remote-deploy.sh")
Invoke-Ssh "chmod +x /tmp/ibuild-remote-deploy.sh && bash /tmp/ibuild-remote-deploy.sh"
Remove-Item -Force $RemoteSh -ErrorAction SilentlyContinue

Remove-Item -Force $TarPath -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Deploy complete:"
Write-Host "  Landing  https://www.ibuild.uz/"
Write-Host "  B2C      https://app.ibuild.uz/"
Write-Host "  B2B      https://admin.ibuild.uz/"
Write-Host "  API      https://api.ibuild.uz/v1/health"
Write-Host "  Code /opt/ibuild/source/ibuild on server"
Write-Host "  Relaunch: ~/ibuild-relaunch.sh"
