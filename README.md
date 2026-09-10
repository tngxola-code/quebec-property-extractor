# PropLedger Québec

**Proprietary property-data intelligence platform for Québec municipal assessment rolls.**

> **Copyright © 2026 Themba Ngxola. All rights reserved.**
>
> PropLedger Québec and its source code, architecture, configurations,
> documentation, data models and associated materials are proprietary.
> No permission is granted to copy, modify, distribute, sublicense,
> commercialize or create derivative works except under a separate
> written licence agreement.
>
> This repository is private. Access is restricted to authorised
> contributors under a signed confidentiality and IP assignment.
> Public disclosure does not grant any licence.

---

## What this is

PropLedger Québec converts fragmented Québec municipal assessment files
into clean, historically comparable, source-verifiable property
intelligence.

It retrieves an approved government source, verifies the artifact by
content hash, activates the correct versioned MEFQ mapping, streams and
validates every discovered property unit, reconciles the total
independently, and publishes canonical observations to an append-only
ledger. From that ledger it derives historical timelines, change
detection and portfolio monitoring.

It is not a one-time XML-to-Excel converter. It is a reusable,
configuration-driven platform.

---

## Core principles

1. **Configuration first.** Municipality, schema, mapping, validation
   and export differences live in `configurations/`, never in code.
   A new municipality adds a folder, not a module.
2. **Evidence first.** Every published value links to the source
   artifact, raw tag, transformation, mapping version and run.
3. **History preserving.** Observations are appended. Earlier facts are
   never overwritten. A re-run cannot silently rewrite history.
4. **Reconciliation by default.** Independently discovered units must
   equal terminal processing outcomes. Any imbalance blocks publication.
5. **API first.** Business capabilities are exposed through versioned
   interfaces before channel-specific logic.
6. **Secure by default.** Safe XML parsing (no DTD, no network, no
   entity expansion), least privilege, tenant isolation, controlled
   exports.
7. **Provider independent.** Local provenance is authoritative.
   External citation or verification services are optional adapters.

---

## Architecture at a glance

    discover ─► acquire ─► verify ─► detect version ─► map ─► transform
        ─► validate ─► assign terminal outcome ─► reconcile ─► publish
        ─► change detection ─► reports / API / portfolio alerts

The pipeline assigns **exactly one terminal outcome** to every
discovered unit. No unit is ever dropped silently.

---

## Repository layout

    propledger-platform/
    ├── src/propledger/
    │   ├── core/            Canonical model, configuration, errors
    │   ├── acquisition/     Registry, resolver, fetch, evidence
    │   ├── ingestion/       Version detection, safe streaming reader
    │   ├── mapping/         Spec loader and mapping engine
    │   ├── transform/       Dates, decimals, codes, text rules
    │   ├── identity/        Key construction and collision detection
    │   ├── validation/      Rule framework and rules
    │   ├── reconciliation/  Independent unit accounting
    │   ├── ledger/          Append-only ORM models and repository
    │   ├── change/          Cross-period diff engine
    │   ├── export/          Excel, CSV, manifest, quality report
    │   ├── api/             FastAPI application
    │   └── cli.py
    ├── configurations/      YAML only — never code
    │   └── quebec-city/
    │       ├── source.yaml
    │       ├── identity.yaml
    │       ├── validation.yaml
    │       ├── export.yaml
    │       └── mapping/
    │           ├── mefq-2.8.yaml
    │           └── mefq-2.9.yaml
    ├── tests/
    │   ├── fixtures/        Anonymised only
    │   └── test_*.py
    ├── docs/
    │   ├── architecture.md
    │   ├── data-model.md
    │   ├── ip-schedule.md
    │   └── third-party-licences.md
    └── scripts/             Bootstrap and pre-commit guards

`src/` is code. `configurations/` is data. The boundary is enforced.

---

## Quickstart

    git clone git@github.com:<org>/propledger-platform.git
    cd propledger-platform
    ./scripts/bootstrap.sh

`bootstrap.sh` creates the virtual environment, installs dependencies,
installs git hooks, starts PostgreSQL, applies migrations and runs the
full quality gate.

Manual equivalent:

    python3.12 -m venv .venv && source .venv/bin/activate
    pip install -e ".[dev]"
    pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push
    make up
    make migrate
    make check

Run an extraction:

    propledger extract ./data/quebec-city-roll.xml --municipality QC-QUEBEC-CITY

---

## Quality gates

Every commit and every pull request must pass:

| Gate        | Tool                        | Enforced by      |
|-------------|-----------------------------|------------------|
| Lint        | `ruff check`                | pre-commit, CI   |
| Format      | `ruff format --check`       | pre-commit, CI   |
| Types       | `mypy --strict`             | pre-commit, CI   |
| Tests       | `pytest`                    | CI               |
| Coverage    | `--cov-fail-under=85`       | CI               |
| Security    | `bandit`, `pip-audit`       | pre-commit, CI   |
| Secrets     | `detect-secrets`            | pre-commit, CI   |
| Commits     | `commitizen` (conventional) | pre-commit, CI   |
| Datasets    | `check_no_datasets.sh`      | pre-commit       |
| Client data | `check_no_client_material.sh` | pre-commit     |

Run everything locally before pushing:

    make check

---

## IP and confidentiality rules

These are non-negotiable and enforced at the git layer.

1. **No raw municipal datasets.** Only anonymised fixtures under
   `tests/fixtures/anonymised-*`. Pre-commit blocks everything else.
2. **No client material.** Client deliverables never enter this
   repository. They belong in `propledger-client-deliveries`.
3. **No secrets.** Use environment variables and a gitignored `.env`.
   The baseline lives in `.secrets.baseline`.
4. **No new dependency** without updating
   `docs/third-party-licences.md` and confirming licence compatibility
   with proprietary distribution.
5. **No open-source licence** may be added to this repository.
6. **Signed commits required** on `main`.
7. **No third-party AI review tool** may be granted repository
   indexing access. AI reviewers operate on pull-request diffs only.

---

## Branching and commits

- Branch from `main`. Use `feature/`, `fix/`, `chore/`, `docs/`.
- Conventional commits only. Use `cz commit`.
- One logical change per pull request.
- Squash-merge into `main`. Linear history. No force-push.

    git switch main && git pull --ff-only
    git switch -c feature/<name>
    cz commit
    git push -u origin feature/<name>

---

## Changelog

Behaviour changes require a bullet under `## [Unreleased]` in
`CHANGELOG.md`. Versions are cut with `cz bump`, which promotes the
unreleased section automatically.

---

## Documentation

- `docs/architecture.md` — system design and boundaries
- `docs/data-model.md` — canonical model and ledger schema
- `docs/ip-schedule.md` — Background IP, deliverables, licences
- `docs/third-party-licences.md` — dependency licence register

---

## Status

Pre-revenue. Phase 1 target: verified Québec City extraction with
complete reconciliation, source provenance and reproducible reports.

Assessment values are administrative information. They are not current
sale prices, formal appraisals, rental income, mortgage valuations,
insurance replacement costs or tax calculations. All analytics must
expose source, method and limitations.

---

*PropLedger Québec is independently conceived, funded and developed by
Themba Ngxola. No customer, partner or external service provider has
funded its development or received ownership, licensing, exclusivity or
commercial rights unless explicitly recorded in a signed agreement.*
