# Changelog

All notable changes to PropLedger Québec are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Error taxonomy: PropLedgerError base with structured context, plus
  ConfigurationError, ArtifactError, UnsupportedVersionError, MappingError,
  TransformError, IdentityCollisionError, ValidationError, ReconciliationError,
  LedgerError, and PlanLimitError.
- Every error carries a context dictionary and serialises via to_dict()
  for uniform logging, API problem responses, and ledger audit trails.
- Canonical observation model: ProcessingOutcome, SourceArtifact, FieldLineage, PropertyIdentity, CanonicalObservation, RunSummary.
- Field-level lineage on every observation, linking each published value back to its raw XML tag, transformation, mapping version, and run.
- RunSummary.reconciled encodes the block-on-imbalance guarantee.
- Subscription tier model: Explorer, Professional, Business, Enterprise, Data Partner.
- Machine-readable pricing in `configurations/pricing.yaml`.
- Plan enforcement dependency for FastAPI.
- Plan loader and tests in `src/propledger/core/plan.py` and `tests/test_plan.py`.

- Initial repository scaffold: source tree, configuration boundaries,
  tooling, CI, and quality gates.
- Proprietary licence and copyright notice.
- Pre-commit hooks enforcing lint, types, secrets, dataset and
  client-material guards.
- Custom guards blocking raw municipal datasets and client-delivery
  paths from entering git.

### Changed

- _Nothing yet._

### Fixed

- _Nothing yet._

### Security

- No open-source licence granted. No third-party AI review tool may
  index this repository.

## [0.1.0] - 2026-09-10

### Added

- Project inception. Canonical observation model, evidence-first
  ingestion, reconciliation, and append-only ledger defined in
  documentation pending implementation.
