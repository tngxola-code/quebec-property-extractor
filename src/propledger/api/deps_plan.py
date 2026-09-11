"""Plan enforcement dependency.

Consumes the tenant from the auth dependency and raises 403 when the
requested resource exceeds the tenant's plan limits.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, HTTPException, status

from propledger.core.plan import PlanLimits, PlanTier, default_plan_limits


@dataclass(frozen=True)
class Tenant:
    tenant_id: str
    plan: PlanTier


async def current_tenant() -> Tenant:
    """Replace with real auth. Placeholder returns Business for local dev."""
    return Tenant(tenant_id="local-dev", plan=PlanTier.BUSINESS)


TenantDep = Annotated[Tenant, Depends(current_tenant)]


def require(*, resource: str, amount: int = 1):
    """Factory that builds a FastAPI dependency for the named resource."""

    async def dependency(tenant: TenantDep) -> None:
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
