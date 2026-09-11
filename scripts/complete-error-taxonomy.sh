#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BRANCH="feature/error-taxonomy"

CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "$BRANCH" ]; then
  echo "error: on branch '$CURRENT', expected '$BRANCH'"
  exit 1
fi

echo "branch: $BRANCH"
echo ""

# --- Ensure working tree is clean ---
if [ -n "$(git status --porcelain)" ]; then
  echo "uncommitted changes present:"
  git status --short
  echo ""
  echo "staging and committing remaining files"
  git add -A
  git commit -m "chore: finalize error-taxonomy branch"
fi

echo "working tree clean"
echo ""

# --- Push ---
echo "pushing $BRANCH"
git push -u origin "$BRANCH" || true
echo ""

# --- Check for an existing PR ---
PR_JSON=$(gh pr list \
  --head "$BRANCH" \
  --base main \
  --state all \
  --json number,url,state \
  --jq '.[0] // empty' 2>/dev/null || true)

if [ -n "$PR_JSON" ]; then
  PR_NUMBER=$(echo "$PR_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['number'])")
  PR_URL=$(echo "$PR_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['url'])")
  PR_STATE=$(echo "$PR_JSON" | python3 -c "import sys,json;print(json.load(sys.stdin)['state'])")
  echo "existing PR #$PR_NUMBER ($PR_STATE)"
  echo "$PR_URL"
else
  echo "no PR yet - creating draft"
  PR_URL=$(gh pr create \
    --base main \
    --title "feat(core): canonical model and structured error taxonomy" \
    --body "Adds the canonical observation model (SourceArtifact, FieldLineage, PropertyIdentity, CanonicalObservation, RunSummary) and a structured error taxonomy with ten typed errors carrying context dictionaries. Pure domain, no I/O. Includes CI matrix update to test on Python 3.12 and 3.14." \
    --draft 2>&1 | tail -1)
  echo "created: $PR_URL"
  PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || echo "")
fi

echo ""

# --- Show the CI status ---
if [ -n "${PR_NUMBER:-}" ]; then
  echo "CI checks for PR #$PR_NUMBER:"
  gh pr checks "$PR_NUMBER" 2>/dev/null || echo "  (no checks reported yet)"
fi

echo ""
echo "next steps:"
echo "  1. wait for CI to pass: gh pr checks $PR_NUMBER"
echo "  2. mark ready:          gh pr ready $PR_NUMBER"
echo "  3. merge:               gh pr merge $PR_NUMBER --squash --delete-branch"
echo "  4. update main:         git switch main && git pull --ff-only"