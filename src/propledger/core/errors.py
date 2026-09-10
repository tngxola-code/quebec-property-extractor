"""Shared error taxonomy. Populated by feature/error-taxonomy."""
from __future__ import annotations


class PropLedgerError(Exception):
    """Base class for all PropLedger errors."""


class UnsupportedVersionError(PropLedgerError):
    pass


class ReconciliationError(PropLedgerError):
    pass


class IdentityCollisionError(PropLedgerError):
    pass


class MappingError(PropLedgerError):
    pass


class ValidationError(PropLedgerError):
    pass


class ConfigurationError(PropLedgerError):
    pass
