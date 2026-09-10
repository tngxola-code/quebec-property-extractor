"""Smoke tests - package imports and stable contract."""
from __future__ import annotations


def test_package_imports() -> None:
    import propledger

    assert propledger.__version__ == "0.1.0"


def test_processing_outcome_values() -> None:
    from propledger.core.models import ProcessingOutcome

    assert ProcessingOutcome.PUBLISHED.value == "published"
    assert ProcessingOutcome.QUARANTINED_VALIDATION.value == "quarantined_validation"


def test_error_taxonomy() -> None:
    from propledger.core.errors import PropLedgerError, ReconciliationError

    assert issubclass(ReconciliationError, PropLedgerError)


def test_safe_parser_present() -> None:
    from propledger.ingestion.streaming import SAFE_PARSER

    assert SAFE_PARSER is not None


def test_api_health() -> None:
    from fastapi.testclient import TestClient

    from propledger.api.main import app

    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
