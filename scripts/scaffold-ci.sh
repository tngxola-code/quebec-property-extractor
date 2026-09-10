#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p .github/workflows

echo "writing .pre-commit-config.yaml"
cat > .pre-commit-config.yaml << 'FILE_EOF'
default_install_hook_types: [pre-commit, commit-msg, pre-push]
default_stages: [pre-commit]
fail_fast: false
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: mixed-line-ending
        args: [--fix=lf]
      - id: check-yaml
      - id: check-toml
      - id: check-json
      - id: check-merge-conflict
      - id: check-added-large-files
        args: [--maxkb=512]
      - id: detect-private-key
      - id: no-commit-to-branch
        args: [--branch, main]

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: [--baseline, .secrets.baseline]

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.5.6
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.11.0
    hooks:
      - id: mypy
        additional_dependencies: [pydantic>=2.7, sqlalchemy>=2.0, types-PyYAML]
        args: [--config-file=pyproject.toml]
        files: ^src/

  - repo: https://github.com/commitizen-tools/commitizen
    rev: v3.27.0
    hooks:
      - id: commitizen
        stages: [commit-msg]

  - repo: local
    hooks:
      - id: no-source-datasets
        name: Block raw municipal datasets
        entry: scripts/check_no_datasets.sh
        language: script
        pass_filenames: false
        always_run: true
      - id: no-client-confidential
        name: Block client-confidential paths
        entry: scripts/check_no_client_material.sh
        language: script
        pass_filenames: false
        always_run: true
FILE_EOF

echo "writing .github/workflows/ci.yml"
cat > .github/workflows/ci.yml << 'FILE_EOF'
name: CI

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

concurrency:
  group: ci-main
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    name: Lint and format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -e ".[dev]"
      - run: ruff check --output-format=github .
      - run: ruff format --check .
      - run: mypy src

  security:
    name: Security scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -e ".[dev]"
      - run: bandit -c pyproject.toml -r src
      - run: pip-audit --strict --desc on

  test:
    name: Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: propledger_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      DATABASE_URL: postgresql+psycopg://postgres:postgres@localhost:5432/propledger_test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -e ".[dev]"
      - run: pytest -n auto --cov --cov-report=xml
      - run: coverage report --fail-under=85

  commit-lint:
    name: Conventional commit check
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install commitizen
      - run: cz check --rev-range origin/main..HEAD
FILE_EOF

echo "writing .github/workflows/release.yml"
cat > .github/workflows/release.yml << 'FILE_EOF'
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write
  id-token: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -e ".[dev]" build
      - name: Verify tag matches package version
        run: |
          pkg=$(python -c "import tomllib,pathlib;print(tomllib.loads(pathlib.Path('pyproject.toml').read_text())['project']['version'])")
          tag=${GITHUB_REF_NAME#v}
          if [ "$pkg" != "$tag" ]; then
            echo "version mismatch: $pkg vs $tag"
            exit 1
          fi
      - run: pytest
      - run: python -m build
      - name: Extract changelog entry
        run: awk '/^## /{c++} c==1' CHANGELOG.md > release_notes.md
      - uses: softprops/action-gh-release@v2
        with:
          body_path: release_notes.md
          draft: false
          files: dist/*
FILE_EOF

echo "writing .github/workflows/ai-review.yml"
cat > .github/workflows/ai-review.yml << 'FILE_EOF'
name: AI Code Review

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened
      - ready_for_review

concurrency:
  group: ai-review
  cancel-in-progress: true

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    if: github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: PR Agent (diff-only)
        uses: pragent/pr-agent@main
        env:
          OPENAI_KEY: ${{ secrets.OPENAI_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          pr_actions: '["opened", "synchronize", "reopened", "ready_for_review"]'
          config.model: "gpt-4o"
          pr_reviewer.require_score_review: "true"
          pr_reviewer.num_code_suggestions: "3"
FILE_EOF

echo ""
echo "CI scaffold complete"
echo ""
ls -la .pre-commit-config.yaml \
       .github/workflows/ci.yml \
       .github/workflows/release.yml \
       .github/workflows/ai-review.yml