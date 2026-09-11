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
            municipality_code="QC", source_url="https://x",
            retrieved_at=datetime.now(UTC),
            http_status=200, content_length=1, sha256="not-a-hash",
        )


def test_artifact_rejects_bad_http_status():
    with pytest.raises(ValidationError):
        SourceArtifact(
            municipality_code="QC", source_url="https://x",
            retrieved_at=datetime.now(UTC),
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
    assert (
        ProcessingOutcome.QUARANTINED_UNSUPPORTED_VERSION.value
        == "quarantined_unsupported_version"
    )
    assert ProcessingOutcome.QUARANTINED_VALIDATION.value == "quarantined_validation"
    assert ProcessingOutcome.REJECTED_IDENTITY.value == "rejected_identity"
    assert ProcessingOutcome.EXCLUDED_BY_POLICY.value == "excluded_by_policy"


def test_processing_outcome_has_exactly_five_members():
    assert len(ProcessingOutcome) == 5
