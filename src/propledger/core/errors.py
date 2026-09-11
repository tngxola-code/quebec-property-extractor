"""Error taxonomy for PropLedger Quebec.

Every error carries structured context. Errors are the boundary between
"something went wrong" and "here is exactly what went wrong, with the
data needed to fix it." No error should be raised without context.

The base class implements to_dict() so logging, API responses, and
ledger audit trails can serialise any error uniformly.
"""

from __future__ import annotations

from typing import Any


class PropLedgerError(Exception):
    """Base class for every PropLedger error.

    Carries a message and a context dictionary. Context is the
    structured data an operator needs to diagnose the error: which
    artifact, which run, which field, which value.

    Never raise a PropLedgerError with an empty context. If nothing
    useful can be attached, the error is a bug in the caller.
    """

    def __init__(
        self,
        message: str,
        *,
        context: dict[str, Any] | None = None,
        cause: BaseException | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.context: dict[str, Any] = context or {}
        if cause is not None:
            self.__cause__ = cause

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": type(self).__name__,
            "message": self.message,
            "context": self.context,
        }

    def __str__(self) -> str:
        if not self.context:
            return self.message
        pairs = ", ".join(f"{k}={v!r}" for k, v in sorted(self.context.items()))
        return f"{self.message} ({pairs})"


# --- Configuration ---


class ConfigurationError(PropLedgerError):
    """A configuration file is missing, malformed, or internally inconsistent.

    Context should include the configuration path and, when applicable,
    the specific key that failed validation.
    """


# --- Acquisition ---


class ArtifactError(PropLedgerError):
    """The source artifact could not be fetched, verified, or stored.

    Covers HTTP failures, hash mismatches, and storage write failures.
    Context should include the source_url and, when applicable, the
    expected and actual hash.
    """


# --- Ingestion ---


class UnsupportedVersionError(PropLedgerError):
    """The source declares a MEFQ version not in the supported set.

    Unsupported versions are quarantined, never guessed. Context
    should include the declared version and the set of supported
    versions.
    """


# --- Mapping and transform ---


class MappingError(PropLedgerError):
    """The mapping specification is invalid or incompatible with the source.

    Covers missing raw tags, cardinality mismatches, and unknown
    transform names. Context should include the mapping version, the
    field name, and the raw tag involved.
    """


class TransformError(PropLedgerError):
    """A value could not be transformed to its canonical form.

    Context should include the transform name, the raw value, and the
    raw tag it came from.
    """


# --- Identity ---


class IdentityCollisionError(PropLedgerError):
    """Two or more discovered units produced the same identity key.

    Context should include the colliding key, the number of collisions
    observed, and the components used to build the key.
    """


# --- Validation ---


class ValidationError(PropLedgerError):
    """A record failed a configured validation rule.

    Context should include the rule name, the field, the observed
    value, and the expected constraint.
    """


# --- Reconciliation ---


class ReconciliationError(PropLedgerError):
    """Discovered units do not equal terminal outcomes.

    This error blocks publication. Nothing is written to the ledger
    when it is raised. Context should include discovered, terminal,
    and the delta.
    """


# --- Ledger ---


class LedgerError(PropLedgerError):
    """A ledger operation failed: insert, query, or immutability violation.

    Context should include the operation, the run_id, and the specific
    constraint or SQL error if available.
    """


# --- API ---


class PlanLimitError(PropLedgerError):
    """A request exceeded the tenant's plan limits.

    Context should include the tenant_id, the plan, the resource, and
    the limit that was exceeded.
    """
