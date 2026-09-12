"""Subscription plan tiers and limits.

Pure domain module. No I/O, no SQLAlchemy, no FastAPI.
Loading is explicit and cached; nothing runs at import time.
"""
from __future__ import annotations

from enum import StrEnum
from functools import lru_cache
from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict


class PlanTier(StrEnum):
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
