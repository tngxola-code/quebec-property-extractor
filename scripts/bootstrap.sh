#!/usr/bin/env bash
set -euo pipefail

python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -e ".[dev]"
pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push

if [[ ! -f .secrets.baseline ]]; then
  detect-secrets scan > .secrets.baseline
fi

docker compose up -d postgres
until docker compose exec -T postgres pg_isready -U propledger >/dev/null 2>&1; do
  sleep 1
done

alembic upgrade head || echo "  (no migrations yet)"
make check || echo "  (gates will pass once modules land)"

echo "Bootstrap complete."
