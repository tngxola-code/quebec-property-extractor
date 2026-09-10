"""Canonical model. Populated by feature/canonical-model."""
from __future__ import annotations

from enum import Enum


class ProcessingOutcome(str, Enum):
    """Exactly one terminal outcome per discovered unit."""

    PUBLISHED = "published"
    QUARANTINED_UNSUPPORTED_VERSION = "quarantined_unsupported_version"
    QUARANTINED_VALIDATION = "quarantined_validation"
    REJECTED_IDENTITY = "rejected_identity"
    EXCLUDED_BY_POLICY = "excluded_by_policy"
