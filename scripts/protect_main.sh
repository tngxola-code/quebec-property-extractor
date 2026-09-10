#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-tngxola-code/prop-ledger-quebec}"

gh api -X PUT "repos/$REPO/branches/main/protection" \
  -f required_status_checks='{"strict":true,"contexts":["Lint and format","Security scan","Tests (py3.12)","Tests (py3.13)"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  -f restrictions=null \
  -f required_linear_history=true \
  -f allow_force_pushes=false \
  -f allow_deletions=false \
  -f required_signatures=true

echo "Branch protection applied to $REPO main."
