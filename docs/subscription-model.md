# PropLedger Québec — Subscription Model

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
| Business | 349 | 3490 | 5 | full | 500 props | 10,000 | 10 |
| Enterprise | 1499 | 14990 | all | full | unlimited | unlimited | unlimited |
| Data Partner | custom | custom | all | full | N/A | bulk | N/A |

## Add-ons

| Add-on | Price |
|---|---|
| Additional municipality | 49 CAD/mo each |
| Additional portfolio properties (Business) | 0.10 CAD/property/mo above 500 |
| Additional API calls (Business) | 0.005 CAD/call above 10,000 |
| Historical backfill | 499 CAD/municipality/year, one-time |
| Custom reconciliation report | 249 CAD/report |

## Competitive anchors

JLR Expert 61 CAD/mo, Premium 111 CAD/mo, plus 0.20–0.30 CAD per property prospected.
fonciq 0.99 CAD per property credit.
MPAC annual data bundles 4,000–58,000 CAD.
Suburbtrends 695–2,995 USD/mo.

PropLedger Business at 349 CAD/mo replaces JLR base fees plus per-property costs for a 500-unit portfolio, adds historical depth and portfolio monitoring, and includes API access.

## Billing

Stripe Billing. One product per tier, one metered price for API calls and portfolio properties, Customer Portal for self-serve upgrade and downgrade. Webhooks: invoice.paid, customer.subscription.updated, invoice.payment_failed. Access revoked 7 days after lapse.
