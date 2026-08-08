#!/usr/bin/env bash
# Purge private paths from git history on branch `main` only.
# The local branch `private/internal` keeps a full archive — never push it.
#
#   chmod +x scripts/purge-private-from-history.sh
#   ./scripts/purge-private-from-history.sh
#   git push origin main --force

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PATHS_FILE="$ROOT/scripts/purge-paths.txt"
PRIVATE_BRANCH="private/internal"

echo "==> Ensuring private/archive branch exists"
if ! git branch --list "$PRIVATE_BRANCH" | grep -q .; then
  git branch "$PRIVATE_BRANCH"
  echo "Created local branch $PRIVATE_BRANCH (do NOT push to public origin)."
else
  echo "Branch $PRIVATE_BRANCH already exists — left unchanged."
fi

echo "==> Installing git-filter-repo if missing"
if ! command -v git-filter-repo >/dev/null 2>&1; then
  pip3 install --user git-filter-repo
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Dropping paths from index"
while IFS= read -r p || [[ -n "$p" ]]; do
  p="${p%%#*}"
  p="$(echo "$p" | xargs)"
  [[ -z "$p" ]] && continue
  git rm -r --cached -f "$p" 2>/dev/null || true
done < "$PATHS_FILE"

echo "==> Rewriting main history only"
git filter-repo --force --refs refs/heads/main --paths-from-file "$PATHS_FILE" --invert-paths

echo ""
echo "Done. Force-push: git push origin main --force"
