# Purge private / junk paths from git history on branch `main` only.
#
# WARNING: Rewrites history on main. Force-push required afterward.
# The local branch `private/internal` is NOT rewritten — it keeps a full archive.
#
# Usage (PowerShell, from repo root):
#   .\scripts\purge-private-from-history.ps1
#   git push origin main --force
#
# Requires: git 2.x, Python 3

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

$PathsFile = Join-Path $RepoRoot 'scripts/purge-paths.txt'
if (-not (Test-Path $PathsFile)) {
  throw "Missing $PathsFile"
}

Write-Host '==> Ensuring private/archive branch exists (from current HEAD snapshot)'
$PrivateBranch = 'private/internal'
$hasPrivate = git -c safe.directory=$RepoRoot branch --list $PrivateBranch
if (-not $hasPrivate) {
  git -c safe.directory=$RepoRoot branch $PrivateBranch
  Write-Host "Created local branch $PrivateBranch (do NOT push to public origin)."
} else {
  Write-Host "Branch $PrivateBranch already exists — left unchanged."
}

Write-Host '==> Downloading git-filter-repo (if needed)'
$FilterRepo = Join-Path $RepoRoot '.tools/git-filter-repo'
New-Item -ItemType Directory -Force -Path (Split-Path $FilterRepo) | Out-Null
if (-not (Test-Path $FilterRepo)) {
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo' -OutFile $FilterRepo
}

Write-Host '==> Dropping paths from index (files stay on disk)'
Get-Content $PathsFile | ForEach-Object {
  $p = $_.Trim()
  if ($p -and -not $p.StartsWith('#')) {
    git -c safe.directory=$RepoRoot rm -r --cached -f $p 2>$null
  }
}

Write-Host '==> Rewriting main history only (private/internal is preserved)'
python $FilterRepo --force --refs refs/heads/main --paths-from-file $PathsFile --invert-paths

Write-Host ''
Write-Host 'Done.'
Write-Host "  private/internal — local archive with full history (never push)"
Write-Host '  Verify main:  git ls-files graphify-out investment presentation  (empty)'
Write-Host '  Force push:   git push origin main --force'
Write-Host '  Teammates must re-clone after force-push.'
