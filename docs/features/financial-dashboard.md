# Financial Dashboard (Dormant)

## Status

The financial dashboard is intentionally hidden across the app until a future
version completes product, security and accounting review.

Current requirements:

- no bottom tab, drawer item, dashboard panel or Studio link;
- `financialDashboardEnabled` normalizes to false even if old Firestore data is
  true;
- financial Cloud Function implementations may remain in source for future
  work but are not exported or deployed;
- no production feature should write financial transactions through the
  dormant UI.

## Technical map

- Dormant client files: `financial_dashboard_*` and repository.
- Dormant backend: `functions/src/financial.ts`.
- Hardening coverage: `production_hardening_test.dart`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| FIN-01 | Member/admin/super-admin navigation | No financial surface appears. |
| FIN-02 | Remote flag set true from legacy data | App still normalizes it to false. |
| FIN-03 | Functions deployment discovery | No financial callable is exported/deployed. |
| FIN-04 | Repository release search | No active route/provider imports dormant UI. |

Before reactivation, create a separate approved specification for roles,
double-entry/accounting semantics, audit log, deletion policy, export, currency,
privacy, security rules, migration and end-to-end tests.

