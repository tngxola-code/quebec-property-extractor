#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BRANCH="feature/error-taxonomy"

git switch main
git pull --ff-only

if [ ! -f "src/propledger/core/models.py" ]; then
  echo "error: main is missing the canonical model"
  echo "merge feature/canonical-model first, then re-run"
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

echo "writing src/propledger/core/errors.py"
cat > src/propledger/core/errors.py << 'FILE_EOF'
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
FILE_EOF

echo "writing tests/test_errors.py"
cat > tests/test_errors.py << 'FILE_EOF'
"""Error taxonomy tests. Pure domain, no I/O."""
from __future__ import annotations

import pytest

from propledger.core.errors import (
    ArtifactError,
    ConfigurationError,
    IdentityCollisionError,
    LedgerError,
    MappingError,
    PlanLimitError,
    PropLedgerError,
    ReconciliationError,
    TransformError,
    UnsupportedVersionError,
    ValidationError,
)


ALL_ERRORS = [
    ConfigurationError,
    ArtifactError,
    UnsupportedVersionError,
    MappingError,
    TransformError,
    IdentityCollisionError,
    ValidationError,
    ReconciliationError,
    LedgerError,
    PlanLimitError,
]


def test_all_errors_inherit_from_base():
    for cls in ALL_ERRORS:
        assert issubclass(cls, PropLedgerError)


def test_base_error_requires_message():
    with pytest.raises(TypeError):
        PropLedgerError()  # type: ignore[call-arg]


def test_error_accepts_context():
    err = ReconciliationError(
        "publication blocked",
        context={"discovered": 175_478, "terminal": 175_400, "delta": 78},
    )
    assert err.context["delta"] == 78


def test_error_default_context_is_empty_dict():
    err = ReconciliationError("blocked")
    assert err.context == {}


def test_to_dict_is_stable():
    err = MappingError(
        "missing raw tag",
        context={"mapping_version": "2.9", "field": "roll_year", "raw_tag": "RL0101A"},
    )
    d = err.to_dict()
    assert d["type"] == "MappingError"
    assert d["message"] == "missing raw tag"
    assert d["context"]["raw_tag"] == "RL0101A"


def test_str_with_context_is_sorted_and_readable():
    err = TransformError(
        "cannot parse decimal",
        context={"raw_value": "abc", "transform": "decimal_cad"},
    )
    s = str(err)
    assert "cannot parse decimal" in s
    assert "raw_value='abc'" in s
    assert "transform='decimal_cad'" in s


def test_str_without_context_is_just_message():
    err = ConfigurationError("bad config")
    assert str(err) == "bad config"


def test_cause_is_attached():
    inner = ValueError("original")
    err = ArtifactError("fetch failed", context={"source_url": "https://x"}, cause=inner)
    assert err.__cause__ is inner


def test_cause_is_optional():
    err = ArtifactError("fetch failed")
    assert err.__cause__ is None


def test_subclasses_distinguishable_by_type():
    errs: list[PropLedgerError] = [
        ConfigurationError("a"),
        ArtifactError("b"),
        ReconciliationError("c"),
    ]
    types = {type(e).__name__ for e in errs}
    assert types == {"ConfigurationError", "ArtifactError", "ReconciliationError"}
FILE_EOF

echo "updating CHANGELOG.md"
python3 - << 'PY'
from pathlib import Path

path = Path("CHANGELOG.md")
text = path.read_text(encoding="utf-8")

bullets = [
    "- Error taxonomy: PropLedgerError base with structured context, plus",
    "  ConfigurationError, ArtifactError, UnsupportedVersionError, MappingError,",
    "  TransformError, IdentityCollisionError, ValidationError, ReconciliationError,",
    "  LedgerError, and PlanLimitError.",
    "- Every error carries a context dictionary and serialises via to_dict()",
    "  for uniform logging, API problem responses, and ledger audit trails.",
]

marker = "Error taxonomy:"
if marker in text:
    print("skip: error-taxonomy entries already present")
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
echo "error taxonomy branch populated"
echo ""
git status --short
echo ""
ls -la src/propledger/core/errors.py tests/test_errors.py