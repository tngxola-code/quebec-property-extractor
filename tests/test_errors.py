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
