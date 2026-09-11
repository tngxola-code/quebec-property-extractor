"""Smoke tests - package imports and stable contract."""

from __future__ import annotations

from fastapi.testclient import TestClient

import propledger
from propledger.api.main import app
from propledger.core.errors import PropLedgerError, ReconciliationError
from propledger.core.models import ProcessingOutcome
from propledger.ingestion.streaming import SAFE_PARSER


def test_package_imports() -> None:
    assert propledger.__version__ == "0.1.0"


def test_processing_outcome_values() -> None:
    assert ProcessingOutcome.PUBLISHED.value == "published"
    assert ProcessingOutcome.QUARANTINED_VALIDATION.value == "quarantined_validation"


def test_error_taxonomy() -> None:
    assert issubclass(ReconciliationError, PropLedgerError)


def test_safe_parser_present() -> None:
    assert SAFE_PARSER is not None


def test_api_health() -> None:
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
