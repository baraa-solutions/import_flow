/// 📦 Feature-Level Barrel Export — Customs Consultation & Duties Calculator
///
/// Centralized exports for all customs consultation widgets, dialogs, cards,
/// and calculation tools.
library;

// ── Tabs & Screen Modules ───────────────────────────────────────────────────
export 'customs_duties_calculator_tab.dart';
export 'saved_consultations_tab.dart';
export 'broker_price_lists_tab.dart';

// ── Quotations & Broker Evaluation ──────────────────────────────────────────
export 'broker_quotation_comparison_table.dart';
export 'broker_quote_details_card.dart';
export 'broker_cost_row.dart';

// ── Duties Calculation & Nafeza Breakdown ───────────────────────────────────
export 'nafeza_fee_breakdown_card.dart';
export 'recalculation_variance_comparison_card.dart';
export 'tariff_missing_widgets.dart';

// ── Badges, Metrics & Indicators ────────────────────────────────────────────
export 'consultation_metric_badge.dart';
export 'consultation_status_badges.dart';
export 'extraction_confidence_indicator.dart';

// ── Modals & Dialogs ────────────────────────────────────────────────────────
export 'add_checklist_item_dialog.dart';
export 'add_custom_broker_expense_row_dialog.dart';
export 'add_custom_expense_dialog.dart';
export 'blocking_issues_dialog.dart';
export 'consultation_details_dialog.dart';
export 'extraction_summary_dialog.dart';
export 'post_save_status_dialog.dart';
export 'price_list_form_dialog.dart';
export 'quick_expense_coding_dialog.dart';
export 'search_and_clone_consultation_dialog.dart';
