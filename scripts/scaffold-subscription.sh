#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p src/propledger/core
mkdir -p src/propledger/api
mkdir -p configurations
mkdir -p docs
mkdir -p tests

echo "writing docs/subscription-model.md"
cat > docs/subscription-model.md << 'FILE_EOF'
# PropLedger Quebec - Subscription Model

Source of truth for pricing, tiers, and customer-segment mapping.
Machine-readable limits live in `configurations/pricing.yaml`.
Domain types live in `src/propledger/core/plan.py`.

## Customer base

| Segment | Decision supported | Primary tier |
|---|---|---|
| Property managers | Which assets breach monitoring rules | Business |
| Investors and developers | What changed and where review is needed | Professional |
| Tax practitioners | Historical comparison before assessment review | Professional |
| Municipal analysts | Defensible views of assessment-base change | Enterprise |
| Lenders and insurers | Governed property-reference signals | Enterprise |
| Software providers | Municipal ingestion as an input to their product | Data Partner |

## Tiers

| Tier | Monthly CAD | Annual CAD | Municipalities | History | Portfolio | API calls/mo | Seats |
|---|---|---|---|---|---|---|---|
| Explorer | 0 | 0 | 1 | 1 year | none | 0 | 1 |
| Professional | 99 | 990 | 2 | 3 years | none | 0 | 1 |
| Business | 349 | 3490 | 5 | full | 500 props | 10000 | 10 |
| Enterprise | 1499 | 14990 | all | full | unlimited | unlimited | unlimited |
| Data Partner | custom | custom | all | full | N/A | bulk | N/A |

## Add-ons

| Add-on | Price |
|---|---|
| Additional municipality | 49 CAD/mo each |
| Additional portfolio properties (Business) | 0.10 CAD/property/mo above 500 |
| Additional API calls (Business) | 0.005 CAD/call above 10000 |
| Historical backfill | 499 CAD/municipality/year, one-time |
| Custom reconciliation report | 249 CAD/report |

## Competitive anchors

JLR Expert 61 CAD/mo, Premium 111 CAD/mo, plus 0.20-0.30 CAD per property prospected.
fonciq 0.99 CAD per property credit.
MPAC annual data bundles 4000-58000 CAD.
Suburbtrends 695-2995 USD/mo.

PropLedger Business at 349 CAD/mo replaces JLR base fees plus per-property costs for a 500-unit portfolio, adds historical depth and portfolio monitoring, and includes API access.

## Billing

Stripe Billing. One product per tier, one metered price for API calls and portfolio properties, Customer Portal for self-serve upgrade and downgrade. Webhooks: invoice.paid, customer.subscription.updated, invoice.payment_failed. Access revoked 7 days after lapse.
FILE_EOF

echo "writing configurations/pricing.yaml"
cat > configurations/pricing.yaml << 'FILE_EOF'
version: "1"
currency: CAD
billing_provider: stripe

tiers:
  explorer:
    display_name: Explorer
    monthly_cad: 0
    annual_cad: 0
    limits:
      municipalities: 1
      history_years: 1
      portfolio_properties: 0
      api_calls_per_month: 0
      seats: 1
      exports_enabled: false
      alerts_enabled: false
      sso_enabled: false

  professional:
    display_name: Professional
    monthly_cad: 99
    annual_cad: 990
    limits:
      municipalities: 2
      history_years: 3
      portfolio_properties: 0
      api_calls_per_month: 0
      seats: 1
      exports_enabled: true
      alerts_enabled: true
      sso_enabled: false

  business:
    display_name: Business
    monthly_cad: 349
    annual_cad: 3490
    limits:
      municipalities: 5
      history_years: null
      portfolio_properties: 500
      api_calls_per_month: 10000
      seats: 10
      exports_enabled: true
      alerts_enabled: true
      sso_enabled: false

  enterprise:
    display_name: Enterprise
    monthly_cad: 1499
    annual_cad: 14990
    limits:
      municipalities: null
      history_years: null
      portfolio_properties: null
      api_calls_per_month: null
      seats: null
      exports_enabled: true
      alerts_enabled: true
      sso_enabled: true

  data_partner:
    display_name: Data Partner
    monthly_cad: null
    annual_cad: null
    limits:
      municipalities: null
      history_years: null
      portfolio_properties: null
      api_calls_per_month: null
      seats: null
      exports_enabled: true
      alerts_enabled: true
      sso_enabled: true

addons:
  additional_municipality:
    price_cad: 49
    unit: per_month
  additional_portfolio_properties:
    price_cad: 0.10
    unit: per_property_per_month
    above: 500
  additional_api_calls:
    price_cad: 0.005
    unit: per_call
    above: 10000
  historical_backfill:
    price_cad: 499
    unit: one_time
    per: municipality_year
  custom_reconciliation_report:
    price_cad: 249
    unit: one_time
FILE_EOF

echo "writing src/propledger/core/plan.py"
cat > src/propledger/core/plan.py << 'FILE_EOF'
"""Subscription plan tiers and limits.

Pure domain module. No I/O, no SQLAlchemy, no FastAPI.
Loading is explicit and cached; nothing runs at import time.
"""
from __future__ import annotations

from enum import Enum
from functools import lru_cache
from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict


class PlanTier(str, Enum):
    EXPLORER = "explorer"
    PROFESSIONAL = "professional"
    BUSINESS = "business"
    ENTERPRISE = "enterprise"
    DATA_PARTNER = "data_partner"


class PlanLimits(BaseModel):
    """None means unlimited. Zero means disabled."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    municipalities: int | None
    history_years: int | None
    portfolio_properties: int | None
    api_calls_per_month: int | None
    seats: int | None
    exports_enabled: bool
    alerts_enabled: bool
    sso_enabled: bool


class Plan(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")

    tier: PlanTier
    display_name: str
    monthly_cad: float | None
    annual_cad: float | None
    limits: PlanLimits


def default_pricing_path() -> Path:
    """Canonical location of pricing.yaml relative to this module."""
    return Path(__file__).resolve().parents[3] / "configurations" / "pricing.yaml"


def load_plans(pricing_path: Path) -> dict[PlanTier, Plan]:
    raw = yaml.safe_load(pricing_path.read_text(encoding="utf-8"))
    plans: dict[PlanTier, Plan] = {}
    for tier_key, spec in raw["tiers"].items():
        tier = PlanTier(tier_key)
        plans[tier] = Plan(
            tier=tier,
            display_name=spec["display_name"],
            monthly_cad=spec["monthly_cad"],
            annual_cad=spec["annual_cad"],
            limits=PlanLimits(**spec["limits"]),
        )
    return plans


@lru_cache(maxsize=1)
def default_plan_limits() -> dict[PlanTier, PlanLimits]:
    """Cached limits loaded from the canonical pricing path."""
    return {tier: plan.limits for tier, plan in load_plans(default_pricing_path()).items()}
FILE_EOF

echo "writing src/propledger/api/deps_plan.py"
cat > src/propledger/api/deps_plan.py << 'FILE_EOF'
"""Plan enforcement dependency.

Consumes the tenant from the auth dependency and raises 403 when the
requested resource exceeds the tenant's plan limits.
"""
from __future__ import annotations

from dataclasses import dataclass

from fastapi import Depends, HTTPException, status

from propledger.core.plan import PlanLimits, PlanTier, default_plan_limits


@dataclass(frozen=True)
class Tenant:
    tenant_id: str
    plan: PlanTier


async def current_tenant() -> Tenant:
    """Replace with real auth. Placeholder returns Business for local dev."""
    return Tenant(tenant_id="local-dev", plan=PlanTier.BUSINESS)


def require(*, resource: str, amount: int = 1):
    """Factory that builds a FastAPI dependency for the named resource."""

    async def dependency(tenant: Tenant = Depends(current_tenant)) -> None:
        limits: PlanLimits = default_plan_limits()[tenant.plan]

        if resource == "api_call":
            cap = limits.api_calls_per_month
            if cap == 0:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN,
                    detail="API access requires Business or Enterprise plan",
                )
            if cap is not None and amount > cap:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN,
                    detail="API call quota exceeded for current plan",
                )

        elif resource == "export":
            if not limits.exports_enabled:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN,
                    detail="Export requires Professional or higher",
                )

        elif resource == "portfolio":
            cap = limits.portfolio_properties
            if cap == 0:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN,
                    detail="Portfolio monitoring requires Business or higher",
                )
            if cap is not None and amount > cap:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN,
                    detail=f"Portfolio cap {cap} exceeded",
                )

        elif resource == "sso":
            if not limits.sso_enabled:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN,
                    detail="SSO requires Enterprise plan",
                )

    return dependency
FILE_EOF

echo "writing tests/test_plan.py"
cat > tests/test_plan.py << 'FILE_EOF'
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
    prices = [
        plans[t].monthly_cad
        for t in (
            PlanTier.EXPLORER,
            PlanTier.PROFESSIONAL,
            PlanTier.BUSINESS,
            PlanTier.ENTERPRISE,
        )
    ]
    assert prices == sorted(prices)
FILE_EOF

chmod +x "$0" 2>/dev/null || true

echo ""
echo "subscription scaffold complete"
echo ""
ls -la docs/subscription-model.md \
       configurations/pricing.yaml \
       src/propledger/core/plan.py \
       src/propledger/api/deps_plan.py \
       tests/test_plan.py