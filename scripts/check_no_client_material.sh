#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN_PATHS='^(deliveries/|client-exports/|clients/|customer-data/)'
staged=$(git diff --cached --name-only --diff-filter=ACM)
fail=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if [[ "$file" =~ $FORBIDDEN_PATHS ]]; then
    echo "Blocked: $file is under a client-delivery path."
    fail=1
  fi
done <<< "$staged"

exit $fail
