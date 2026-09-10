#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN_EXT='\.(xml|csv|parquet|feather|zip|gz|xlsx|fgdb|geojson)$'
FORBIDDEN_SIZE_KB=512
ALLOWED='^(tests/fixtures/anonymised-.*\.(xml|csv)|configurations/.*\.yaml)$'

staged=$(git diff --cached --name-only --diff-filter=ACM)
fail=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if [[ "$file" =~ $ALLOWED ]]; then continue; fi
  if [[ "$file" =~ $FORBIDDEN_EXT ]]; then
    echo "Blocked: $file matches forbidden data extension."
    fail=1
  fi
  if [[ -f "$file" ]]; then
    size_kb=$(( $(wc -c < "$file") / 1024 ))
    if (( size_kb > FORBIDDEN_SIZE_KB )); then
      echo "Blocked: $file is ${size_kb}KB (over ${FORBIDDEN_SIZE_KB}KB)."
      fail=1
    fi
  fi
done <<< "$staged"

if (( fail )); then
  echo "Municipal source data and large artifacts must never enter the repository."
  exit 1
fi
