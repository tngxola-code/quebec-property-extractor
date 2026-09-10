# Contributing

## Setup

    git clone git@github.com:tngxola-code/prop-ledger-quebec.git
    cd prop-ledger-quebec
    ./scripts/bootstrap.sh

## Branching

Branch from main. Use feature/, fix/, chore/, docs/, test/.

## Commits

Conventional commits only. cz commit guides you.

## Quality gate

Before every push:

    make check

## IP rules (non-negotiable)

1. No raw municipal datasets. Anonymised fixtures only.
2. No client material. Client deliverables never enter this repo.
3. No secrets. Environment variables and .env (gitignored).
4. No new dependency without updating docs/third-party-licences.md.
5. No open-source licence may be added to this repository.
6. No third-party AI review tool may index this repository.
7. Signed commits required on main.

## Pull requests

One logical change per PR. Fill the PR template completely.
Squash-merge into main.
