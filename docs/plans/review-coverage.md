# Code review coverage tracker (import cycle phases)

Baseline counts (2026-10-05, `wc -l`): backend `modules/**/*.py` = 97,642 lines; Flutter `frontend/lib/**/*.dart` = 336,563 lines.
Goal: >= 40% of the code reviewed (audit plan + BLOCKER/CRITICAL/MAJOR fixes + tests + independent review).

Method per phase: solution-architect audit -> `docs/plans/phase-NN-*-quality-plan.md` -> backend-developer + flutter-developer
fix packages (disjoint files, no schema changes this wave) -> diff-reviewer (+ customs-rules-reviewer for money math)
-> targeted tests per package; one full gate at the end.

| Phase | Backend modules | BE lines | Flutter features | FE lines | Plan | Status |
|---|---|---|---|---|---|---|
| 01 Planning | purchase_orders, cbm_calculator, shipping_scenarios, customs_consultation, import_requirements, freight_quotations(router) + common | 8,346 | 5 features | 43,747 | phase-01-quality-simplify-plan.md | done (full gate pending) |
| 02 Financial approval | financial_approval | 4,962 | financial_approval | 13,754 | phase-02-quality-plan.md | done: BE+FE fixes, design pass, diff/security/customs reviews fixed |
| 03 Documentation | import_documentation, original_documents_collection, docs_customs_approval, smart_document_upload | 18,443 | import_documentation | 47,203 | phase-03a/03b/03c | done: 03a/03b BE + 03c FE fixes, design pass, diff/security/customs reviews fixed |
| 04-05 Freight + shipping | freight_booking, cargo_insurance, cargo_shipping, shipment_updates, demurrage_detention | 5,911 | 5 features | 22,300 | phase-04-05-quality-plan.md | done: BE+FE fixes, design pass, diff/security/customs reviews fixed |
| 06-07 Customs | customs_clearance, customs_clearance_quotations | 4,490 | 2 features | 18,093 | phase-06-07-quality-plan.md | done: BE+FE fixes, design pass, diff/security/customs reviews fixed |
| 08 + 10 Warehouse + closure | warehouse_receiving, inland_transport, file_closure | 3,299 | 3 features | 10,008 | phase-08-10-quality-plan.md | done: BE (4d22473 + review fixes) + FE + design pass, reviews fixed |
| 09 Settlement | financial_settlement, recalculation | 4,921 | 2 features | 8,517 | phase-09-quality-plan.md | done: BE+FE fixes, design pass, diff + customs reviews fixed |

Audit results (2026-10-05): 02 = 5B/4C/23M; 03a = 3B/7C/10M; 03b = 5B/6C/13M; 03c = 4B/5C/11M; 06-07 = 6B/9C/21M;
08-10 = 5B/9C/21M; 09 = 7B/5C/14M (B = BLOCKER, C = CRITICAL, M = MAJOR).
Lead-registered shared codes so far: permissions `import_documentation.approve`, `financial_approval.manage` (seed_rbac).

Target if all rows complete: backend ~50,372 / 97,642 = ~52%; Flutter ~163,622 / 336,563 = ~49%.

Status 2026-10-05 (end of wave): all rows done -> backend ~50,372 / 97,642 (~52%), Flutter ~163,622 / 336,563 (~49%).
Shared registry done: 106 message codes, 19 enum sets, 24 system parameters (backend + Flutter). Full test gate: see history/2026-10-05.md.
Not covered by this wave: master data modules, settings, reports, cargox, customs_tariff, smart_email_listener, lifecycle_board, app_update.
