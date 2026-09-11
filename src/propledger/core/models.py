"""Canonical model for PropLedger Quebec.

Pure domain module. No I/O, no SQLAlchemy, no FastAPI, no file access.

Every published observation carries the source artifact it came from,
the mapping version used to interpret it, field-level lineage back to
the raw XML tags, and exactly one terminal processing outcome.
"""
from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class ProcessingOutcome(StrEnum):
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
