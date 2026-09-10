#!/usr/bin/env bash
set -euo pipefail

git switch main && git pull --ff-only

branches=(
  feature/canonical-model feature/error-taxonomy feature/config-loader
  feature/logging-structlog feature/run-context
  feature/source-registry feature/source-resolver feature/artifact-fetch
  feature/artifact-hashing feature/artifact-store feature/licence-check
  feature/safe-xml-parser feature/streaming-reader feature/record-counter
  feature/version-detect feature/version-quarantine feature/encoding-detection
  feature/mapping-spec-loader feature/mapping-engine feature/mapping-cardinality
  feature/mapping-2.6 feature/mapping-2.7 feature/mapping-2.8 feature/mapping-2.9
  feature/transform-dates feature/transform-decimals feature/transform-codes
  feature/transform-text feature/transform-registry
  feature/identity-engine feature/identity-collision feature/identity-uncertainty
  feature/identity-regression feature/identity-multi-municipality
  feature/validation-framework feature/validation-required feature/validation-range
  feature/reconciliation-core feature/reconciliation-gate feature/reconciliation-report
  feature/terminal-outcome-coverage
  feature/ledger-models feature/ledger-migrations feature/ledger-repository
  feature/ledger-artifact-link feature/ledger-run-summary feature/ledger-history-query
  feature/ledger-immutability-guard
  feature/change-classifier feature/change-materiality feature/change-field-diff
  feature/change-timeline feature/change-cross-year-identity
  feature/export-csv feature/export-excel feature/export-manifest
  feature/export-quality-report feature/export-exception-report
  feature/export-reconciliation-report feature/export-column-policy feature/export-anonymisation
  feature/api-app feature/api-runs feature/api-property-history
  feature/api-property-changes feature/api-search feature/api-artifact
  feature/api-auth feature/api-versioning feature/api-rate-limit
  feature/cli-extract feature/cli-dry-run feature/cli-verify
  feature/cli-reconcile feature/cli-export feature/cli-report
  feature/config-quebec-city feature/config-validation-schema
  feature/config-gatineau feature/config-template feature/config-migration
  docs/ip-schedule docs/licence-proprietary docs/architecture docs/data-model
  docs/third-party-licences docs/threat-model docs/onboarding-municipality docs/runbook
  test/fixture-anonymised-roll test/fixture-collision test/streaming-memory
  test/safe-parser test/reconciliation-blocks test/ledger-immutability
  test/end-to-end
  chore/docker-image chore/ci-matrix chore/observability chore/backup-restore
  feature/infra-iac feature/deploy-pipeline
)

for b in "${branches[@]}"; do
  if git show-ref --verify --quiet "refs/heads/$b"; then
    echo "skip: $b"
  else
    git switch -c "$b" main >/dev/null
    echo "created: $b"
  fi
done

git switch main
echo ""
echo "${#branches[@]} branches present."
