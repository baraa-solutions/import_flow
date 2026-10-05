---
name: smart-extract-heuristics
description: Smart Extract (PO / invoice) field bugs are heuristic-parser bugs, not LLM; known traps in number/currency/HS handling
metadata:
  type: project
---

"Smart Extract (PI / PL)" in the PO dialog -> POST /smart-upload/parse/purchase-order -> PurchaseOrderExtractor
(pure regex, no LLM, whatever env keys are set). Only ai_document_parser.extract_draft_bl_with_ai (B/L) calls
GEMINI/ANTHROPIC/OPENAI. There is no real-invoice sample in the repo and upload_sessions in the local DBs is empty,
so reproduce with a synthetic text fixture shaped like the existing G.I. fixtures in
tests/unit/test_multi_country_invoice_extraction.py (those are real spatial-extraction text).

Traps fixed 2026-10-05 (V1/2539 field report), may still exist in other extractors that use BaseExtractor helpers:
- BaseExtractor.parse_numeric_str reads "820,600" / "25,000" as thousands; Italian invoices print kg with 3 decimals.
- BaseExtractor.normalize_currency takes the first "amount + code" in document order, so a EUR amount in the legal
  header (share capital, stamp duty) beats the USD total. "EXTRA UE" was never the cause.
- A wrong HS code may be the Flutter dialog, not the backend: it used to replace the printed code with the first
  tariff row sharing a prefix/heading.

**Why:** the reported symptom pointed at the backend, but one of the four causes was in the frontend.
**How to apply:** for extraction bugs, run the extractor on a fixture first, then compare with what the dialog
shows before blaming the backend.
