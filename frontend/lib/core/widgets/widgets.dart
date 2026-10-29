/// 📦 Centralised Core Widgets Barrel Export — ImportFlow ERP
///
/// Single source of truth for all reusable enterprise UI components.
/// Instead of importing 10+ individual widget files, screens can import:
/// ```dart
/// import 'package:frontend/core/widgets/widgets.dart';
/// ```
library;

// ── Buttons & Action Controls ────────────────────────────────────────────────
export 'buttons/app_button.dart';
export 'buttons/buttons.dart';
export 'buttons/icon_action_button.dart';
export 'list_load_more_footer.dart';
export 'action_toolbar.dart';
export 'master_data_toolbar.dart';
export 'row_actions_pill.dart';
export 'row_context_menu.dart';
export 'back_to_dashboard_button.dart';
export 'recalculate_button.dart';
export 'stop_shipment_button.dart';
export 'smart_upload_button.dart';
export 'ai_assistant_top_bar_button.dart';

// ── Headers, Navigation & Scaffolding ────────────────────────────────────────
export 'page_header.dart';
export 'unified_top_bar.dart';
export 'vertical_stage_scaffold.dart';
export 'dedicated_stage_scaffold.dart';
export 'adaptive_tab_scaffold.dart';
export 'enterprise_multi_pane_layout.dart';
export 'responsive_layout_builder.dart';
export 'shipment_lifecycle_navigator.dart';
export 'shipment_stage_lifecycle_control.dart';

// ── Data Grids & Metrics ─────────────────────────────────────────────────────
export 'enterprise_data_table/enterprise_data_table.dart';
export 'compact_table_pagination_footer.dart';
export 'metric_card.dart';
export 'copyable_data_helper.dart';
export 'table_row_clone_helper.dart';
export 'container_load_plan_painter.dart';
export 'cargo_load_planner_dialog.dart';

// ── Form Inputs & Pickers ───────────────────────────────────────────────────
export 'custom_text_field.dart';
export 'searchable_dropdown_field.dart';
export 'app_date_picker_field.dart';
export 'app_search_field.dart';
export 'standard_form_action_bar.dart';

// ── Status, Badges & Feedback ───────────────────────────────────────────────
export 'app_status_badge.dart';
export 'live_pulse_badge.dart';
export 'critical_alert_banner.dart';
export 'existing_record_snackbar.dart';

// ── States (Loading / Empty / Error) ────────────────────────────────────────
export 'states/states.dart';
export 'app_shimmer_skeleton.dart';

// ── Operational Notes & Attachments ─────────────────────────────────────────
export 'stage_notes_card.dart';

// ── Dialogs & Modals ────────────────────────────────────────────────────────
export 'app_confirm_dialog.dart';
export 'reopen_shipment_dialog.dart';
export 'stop_shipment_dialog.dart';
export 'universal_entity_extractor_dialog.dart';
export 'extraction_progress_dialog.dart';
export 'unsaved_changes_dialog.dart';
export 'unsaved_changes_guard.dart';
export 'error_details_dialog.dart';
export 'change_diff_dialog.dart';
export 'clone_entity_review_dialog.dart';
export 'concurrency_conflict_dialog.dart';
export 'command_palette_dialog.dart';
export 'system_settings_dialog.dart';
export 'keyboard_shortcuts_dialog.dart';

// ── Typography & Directionality Utilities ───────────────────────────────────
export 'ltr_text.dart';
export 'directional_icon.dart';
export 'display_density_selector.dart';
