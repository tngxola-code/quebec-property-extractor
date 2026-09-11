#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BRANCH="feature/canonical-model"

git switch main
git pull --ff-only

if [ ! -f "src/propledger/core/models.py" ]; then
  echo "error: src/propledger/core/models.py missing on main"
  echo "merge the feat/scaffold pull request first, then re-run this script"
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "branch exists: $BRANCH"
  git switch "$BRANCH"
  git pull --ff-only 2>/dev/null || true
else
  echo "creating branch: $BRANCH"
  git switch -c "$BRANCH"
fi

echo "writing src/propledger/core/models.py"
cat > src/propledger/core/models.py << 'FILE_EOF'
"""Canonical model for PropLedger Quebec.

Pure domain module. No I/O, no SQLAlchemy, no FastAPI, no file access.

Every published observation carries the source artifact it came from,
the mapping version used to interpret it, field-level lineage back to
the raw XML tags, and exactly one terminal processing outcome.
"""
from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class ProcessingOutcome(str, Enum):
    """Exactly one terminal outcome per discovered unit."""

    PUBLISHED = "published"
    QUARANTINED_UNSUPPORTED_VERSION = "quarantined_unsupported_version"
    QUARANTINED_VALIDATION = "quarantined_validation"
    REJECTED_IDENTITY = "rejected_identity"
    EXCLUDED_BY_POLICY = "excluded_by_policy"


class SourceArtifact(BaseModel):
    """Immutable evidence that a specific byte stream was retrieved."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    artifact_id: UUID = Field(default_factory=uuid4)
    municipality_code: str = Field(min_length=1, max_length=64)
    source_url: str = Field(min_length=1)
    retrieved_at: datetime
    http_status: int = Field(ge=100, le=599)
    content_length: int = Field(ge=0)
    sha256: str = Field(pattern=r"^[a-f0-9]{64}$")
    etag: str | None = None
    last_modified: str | None = None
    declared_version: str | None = None


class FieldLineage(BaseModel):
    """Links one published value back to its raw tag and transformation."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    raw_tag: str = Field(min_length=1)
    raw_value: str | None = None
    transformation: str = Field(min_length=1)
    mapping_version: str = Field(min_length=1)
    run_id: UUID


class PropertyIdentity(BaseModel):
    """Composite identity of a property unit."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    identity_key: str
    municipality_code: str = Field(min_length=1, max_length=64)
    components: dict[str, str]
    confidence: str = Field(pattern=r"^(stable|uncertain)$")
    uncertainty_reason: str | None = None

    @property
    def is_stable(self) -> bool:
        return self.confidence == "stable"


class CanonicalObservation(BaseModel):
    """One published observation about one property unit."""

    model_config = ConfigDict(extra="forbid")

    observation_id: UUID = Field(default_factory=uuid4)
    run_id: UUID
    artifact_id: UUID
    identity: PropertyIdentity
    roll_year: int = Field(ge=1800, le=2200)
    release_year: int = Field(ge=1800, le=2200)
    assessment_effective_date: date | None = None
    values: dict[str, Any] = Field(default_factory=dict)
    lineage: dict[str, FieldLineage] = Field(default_factory=dict)
    outcome: ProcessingOutcome
    outcome_detail: str | None = None


class RunSummary(BaseModel):
    """Accounting for a single extraction run."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    run_id: UUID
    municipality_code: str = Field(min_length=1, max_length=64)
    mapping_version: str = Field(min_length=1)
    discovered_units: int = Field(ge=0)
    terminal_outcomes: int = Field(ge=0)
    published: int = Field(ge=0)
    quarantined: int = Field(ge=0)
    rejected: int = Field(ge=0)
    started_at: datetime
    finished_at: datetime

    @property
    def reconciled(self) -> bool:
        return self.discovered_units == self.terminal_outcomes

    @property
    def delta(self) -> int:
        return self.discovered_units - self.terminal_outcomes
FILE_EOF

echo "writing tests/test_models.py"
cat > tests/test_models.py << 'FILE_EOF'
"""Canonical model tests. Pure domain, no I/O."""
from __future__ import annotations

from datetime import UTC, date, datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from propledger.core.models import (
    CanonicalObservation,
    FieldLineage,
    ProcessingOutcome,
    PropertyIdentity,
    RunSummary,
    SourceArtifact,
)

SHA256_OK = "a" * 64


def _artifact() -> SourceArtifact:
    return SourceArtifact(
        municipality_code="QC-QUEBEC-CITY",
        source_url="https://example.qc.ca/roll-2025.xml",
        retrieved_at=datetime(2026, 9, 10, tzinfo=UTC),
        http_status=200,
        content_length=286_331_648,
        sha256=SHA256_OK,
        declared_version="2.9",
    )


def _identity() -> PropertyIdentity:
    return PropertyIdentity(
        identity_key="A|B|C|D|F",
        municipality_code="QC-QUEBEC-CITY",
        components={"RL0104A": "A", "RL0104B": "B", "RL0104C": "C",
                    "RL0104D": "D", "RL0104F": "F"},
        confidence="stable",
    )


def _lineage(run_id):
    return FieldLineage(
        raw_tag="RL0301A",
        raw_value="250000",
        transformation="decimal_cad",
        mapping_version="2.9",
        run_id=run_id,
    )


def test_artifact_accepts_valid_data():
    a = _artifact()
    assert a.sha256 == SHA256_OK
    assert a.municipality_code == "QC-QUEBEC-CITY"


def test_artifact_rejects_bad_hash():
    with pytest.raises(ValidationError):
        SourceArtifact(
            municipality_code="QC", source_url="https://x", retrieved_at=datetime.now(UTC),
            http_status=200, content_length=1, sha256="not-a-hash",
        )


def test_artifact_rejects_bad_http_status():
    with pytest.raises(ValidationError):
        SourceArtifact(
            municipality_code="QC", source_url="https://x", retrieved_at=datetime.now(UTC),
            http_status=999, content_length=1, sha256=SHA256_OK,
        )


def test_artifact_is_frozen():
    a = _artifact()
    with pytest.raises(ValidationError):
        a.sha256 = "b" * 64


def test_identity_stable_flag():
    assert _identity().is_stable is True


def test_identity_rejects_unknown_confidence():
    with pytest.raises(ValidationError):
        PropertyIdentity(
            identity_key="X", municipality_code="QC",
            components={}, confidence="maybe",
        )


def test_identity_accepts_uncertain():
    ident = PropertyIdentity(
        identity_key="X", municipality_code="QC",
        components={"RL0104A": "A"},
        confidence="uncertain", uncertainty_reason="missing component RL0104B",
    )
    assert ident.is_stable is False


def test_lineage_round_trip():
    run_id = uuid4()
    lineage = _lineage(run_id)
    assert lineage.run_id == run_id
    assert lineage.raw_tag == "RL0301A"


def test_observation_accepts_valid_data():
    run_id = uuid4()
    artifact = _artifact()
    obs = CanonicalObservation(
        run_id=run_id,
        artifact_id=artifact.artifact_id,
        identity=_identity(),
        roll_year=2025,
        release_year=2026,
        assessment_effective_date=date(2025, 1, 1),
        values={"assessed_land_value": "250000.00"},
        lineage={"assessed_land_value": _lineage(run_id)},
        outcome=ProcessingOutcome.PUBLISHED,
    )
    assert obs.outcome is ProcessingOutcome.PUBLISHED
    assert obs.identity.identity_key == "A|B|C|D|F"


def test_observation_rejects_bad_roll_year():
    with pytest.raises(ValidationError):
        CanonicalObservation(
            run_id=uuid4(), artifact_id=uuid4(), identity=_identity(),
            roll_year=1500, release_year=2026,
            outcome=ProcessingOutcome.PUBLISHED,
        )


def test_observation_rejects_unknown_outcome():
    with pytest.raises(ValidationError):
        CanonicalObservation(
            run_id=uuid4(), artifact_id=uuid4(), identity=_identity(),
            roll_year=2025, release_year=2026,
            outcome="not-an-outcome",
        )


def test_run_summary_reconciled_true():
    now = datetime.now(UTC)
    summary = RunSummary(
        run_id=uuid4(), municipality_code="QC-QUEBEC-CITY",
        mapping_version="2.9",
        discovered_units=175_478, terminal_outcomes=175_478,
        published=175_478, quarantined=0, rejected=0,
        started_at=now, finished_at=now,
    )
    assert summary.reconciled is True
    assert summary.delta == 0


def test_run_summary_reconciled_false_when_unbalanced():
    now = datetime.now(UTC)
    summary = RunSummary(
        run_id=uuid4(), municipality_code="QC-QUEBEC-CITY",
        mapping_version="2.9",
        discovered_units=175_478, terminal_outcomes=175_400,
        published=175_400, quarantined=0, rejected=0,
        started_at=now, finished_at=now,
    )
    assert summary.reconciled is False
    assert summary.delta == 78


def test_processing_outcome_values_are_stable():
    assert ProcessingOutcome.PUBLISHED.value == "published"
    assert ProcessingOutcome.QUARANTINED_UNSUPPORTED_VERSION.value == "quarantined_unsupported_version"
    assert ProcessingOutcome.QUARANTINED_VALIDATION.value == "quarantined_validation"
    assert ProcessingOutcome.REJECTED_IDENTITY.value == "rejected_identity"
    assert ProcessingOutcome.EXCLUDED_BY_POLICY.value == "excluded_by_policy"


def test_processing_outcome_has_exactly_five_members():
    assert len(ProcessingOutcome) == 5
FILE_EOF

echo "updating CHANGELOG.md"
python3 - << 'PY'
from pathlib import Path

path = Path("CHANGELOG.md")
text = path.read_text(encoding="utf-8")

bullets = [
    "- Canonical observation model: ProcessingOutcome, SourceArtifact, FieldLineage, PropertyIdentity, CanonicalObservation, RunSummary.",
    "- Field-level lineage on every observation, linking each published value back to its raw XML tag, transformation, mapping version, and run.",
    "- RunSummary.reconciled encodes the block-on-imbalance guarantee.",
]

if any(b.split(":")[0] in text for b in bullets):
    print("skip: canonical-model entries already present")
    raise SystemExit(0)

needle = "### Added\n\n"
if needle not in text:
    print("error: cannot find '### Added' in CHANGELOG.md")
    raise SystemExit(1)

insert = needle + "\n".join(bullets) + "\n"
path.write_text(text.replace(needle, insert, 1), encoding="utf-8")
print("updated: CHANGELOG.md")
PY

chmod +x "$0" 2>/dev/null || true

echo ""
echo "canonical model branch populated"
echo ""
git status --short
echo ""
ls -la src/propledger/core/models.py tests/test_models.py