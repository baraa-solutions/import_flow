---
name: form46-no-fallback
description: Form 46 and COO/inspection exports must never invent values; calculator, guards and test traps
metadata:
  type: project
---

- Form 46 math lives in `import_documentation/services/customs_declaration46_calculator.dart` (nullable figures,
  `missing` list: tariff / fx_rate / fob). Customs FX = `currenciesProvider` `latestCustomsRate`; tariff = HS match
  from linked PO lines only, never "first tariff". Freight/insurance are not recorded on the file: CIF = FOB, flagged.
- `CustomsDeclarationAssessment` fields are nullable; format with `fixedOrMissing` / `egpOrMissing`. The A-owned
  `search_and_clone_customs_declaration46_dialog.dart` reads them (one line adapted).
- COO exports: `CooExportService.missingExportField` + `CooExportBlockedException`; UI shows SnackBar first.
- Tracking links: `OriginalDocsExportService.safeHttpUri` + `explorer.exe` without shell (no url_launcher in pubspec).
- Widget tests of the Form 46 screen must override `purchaseOrdersProvider` (HS match) and `currenciesProvider`.
- Another agent's broken l10n insert (raw newline in a string) can fail every test compile: wait and rerun.
