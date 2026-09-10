#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - << 'PY'
from pathlib import Path

path = Path("CHANGELOG.md")
if not path.exists():
    raise SystemExit("error: CHANGELOG.md not found at repo root")

text = path.read_text(encoding="utf-8")

bullets = [
    "- Subscription tier model: Explorer, Professional, Business, Enterprise, Data Partner.",
    "- Machine-readable pricing in `configurations/pricing.yaml`.",
    "- Plan enforcement dependency for FastAPI.",
    "- Plan loader and tests in `src/propledger/core/plan.py` and `tests/test_plan.py`.",
]

if any(b in text for b in bullets):
    print("skip: subscription entries already present")
    raise SystemExit(0)

needle = "## [Unreleased]\n\n### Added\n\n"
if needle not in text:
    print("error: cannot find '## [Unreleased]' with '### Added' section")
    print("       open CHANGELOG.md and confirm the structure before retrying")
    raise SystemExit(1)

replacement = needle + "\n".join(bullets) + "\n\n"
path.write_text(text.replace(needle, replacement, 1), encoding="utf-8")
print("updated: CHANGELOG.md")
PY

echo ""
echo "---first 30 lines of CHANGELOG.md---"
head -30 CHANGELOG.md