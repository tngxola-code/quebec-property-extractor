"""Plan tier tests. Pure domain, no I/O beyond reading the YAML once."""
from __future__ import annotations

from pathlib import Path

import pytest

from propledger.core.plan import PlanTier, load_plans

PRICING = Path(__file__).resolve().parent.parent / "configurations" / "pricing.yaml"


@pytest.fixture(scope="module")
def plans():
    return load_plans(PRICING)


def test_all_tiers_load(plans):
    assert set(plans.keys()) == set(PlanTier)


def test_explorer_is_disabled(plans):
    lim = plans[PlanTier.EXPLORER].limits
    assert lim.exports_enabled is False
    assert lim.api_calls_per_month == 0
    assert lim.portfolio_properties == 0


def test_professional_has_exports(plans):
    lim = plans[PlanTier.PROFESSIONAL].limits
    assert lim.exports_enabled is True
    assert lim.history_years == 3


def test_business_has_api_and_portfolio(plans):
    lim = plans[PlanTier.BUSINESS].limits
    assert lim.api_calls_per_month == 10000
    assert lim.portfolio_properties == 500


def test_enterprise_is_unlimited(plans):
    lim = plans[PlanTier.ENTERPRISE].limits
    assert lim.municipalities is None
    assert lim.api_calls_per_month is None
    assert lim.sso_enabled is True


def test_pricing_monotonic(plans):
    prices = [plans[t].monthly_cad for t in (
        PlanTier.EXPLORER, PlanTier.PROFESSIONAL,
        PlanTier.BUSINESS, PlanTier.ENTERPRISE,
    )]
    assert prices == sorted(prices)
