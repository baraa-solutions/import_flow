"""
Unified Coordinator and Facade for Shipment Stage Activity & 6-Phase Lifecycle Board

This module delegates domain-specific logic to focused sub-services while maintaining
100% backward compatibility for all existing public functions, signatures, and constants:
- `lifecycle_kanban_service.py`: Shipment board queries, Kanban phase grouping, KPI aggregations.
- `lifecycle_tracking_service.py`: Live tracking radar, container event synchronizer, milestone history logging.
- `lifecycle_step_service.py`: Step configuration management, station SLAs, step validation rules, prerequisite gates.
"""

import logging

import modules.lifecycle_board.repository as repo
import modules.lifecycle_board.validators as validators

# ─── Sub-Service Exports: Kanban & Phase Definitions ──────────────────────────
from modules.lifecycle_board.lifecycle_kanban_service import (
    PHASES_DEFINITION,
    ORDERED_STEP_CODES,
    STEP_TO_PHASE_MAP,
    STEP_NAME_MAP,
    get_step_neighbors,
    _parse_datetime_safe,
    get_board_summary_service,
    get_lifecycle_board_summary,
)

# ─── Sub-Service Exports: Live Tracking Radar & Timelines ─────────────────────
from modules.lifecycle_board.lifecycle_tracking_service import (
    get_live_logistics_tracking_service,
    get_shipment_timeline_service,
    sync_timeline_snapshots_service,
    get_timeline_snapshots_service,
)

# ─── Sub-Service Exports: Step Management, Transitions & Configuration ─────────
from modules.lifecycle_board.lifecycle_step_service import (
    DEFAULT_REASON_CATEGORIES,
    _ensure_step_configs,
    get_all_step_configs_service,
    get_step_config_service,
    update_step_config_service,
    get_step_config_audit_logs_service,
    register_pending_reference_service,
    skip_step_service,
    _resolve_and_validate_file,
    _apply_file_tracking,
    _close_step_tasks,
    _create_next_step_task,
    _sync_import_file_and_tasks_on_advance,
    _append_system_note,
    resolve_hold_stage,
    hold_shipment_activities_service,
    resume_shipment_activities_service,
    get_all_activities_service,
    initialize_file_lifecycle_service,
    advance_lifecycle_step_service,
    transition_stage_activity_service,
    http_advance_step_service,
    advance_step_service,
    set_multi_active_stages_service,
    sync_consultation_lifecycle_stage,
    sync_requirements_lifecycle_stage,
    sync_budget_lifecycle_stage,
    sync_booking_lifecycle_stage,
    sync_cargo_shipping_lifecycle_stage,
)

logger = logging.getLogger(__name__)

__all__ = [
    # Kanban & Constants
    "PHASES_DEFINITION",
    "ORDERED_STEP_CODES",
    "STEP_TO_PHASE_MAP",
    "STEP_NAME_MAP",
    "get_step_neighbors",
    "_parse_datetime_safe",
    "get_board_summary_service",
    "get_lifecycle_board_summary",
    # Live Tracking Radar & Timelines
    "get_live_logistics_tracking_service",
    "get_shipment_timeline_service",
    "sync_timeline_snapshots_service",
    "get_timeline_snapshots_service",
    # Step Management & Config
    "DEFAULT_REASON_CATEGORIES",
    "_ensure_step_configs",
    "get_all_step_configs_service",
    "get_step_config_service",
    "update_step_config_service",
    "get_step_config_audit_logs_service",
    "register_pending_reference_service",
    "skip_step_service",
    "_resolve_and_validate_file",
    "_apply_file_tracking",
    "_close_step_tasks",
    "_create_next_step_task",
    "_sync_import_file_and_tasks_on_advance",
    "_append_system_note",
    "resolve_hold_stage",
    "hold_shipment_activities_service",
    "resume_shipment_activities_service",
    "get_all_activities_service",
    "initialize_file_lifecycle_service",
    "advance_lifecycle_step_service",
    "transition_stage_activity_service",
    "http_advance_step_service",
    "advance_step_service",
    "set_multi_active_stages_service",
    "sync_consultation_lifecycle_stage",
    "sync_requirements_lifecycle_stage",
    "sync_budget_lifecycle_stage",
    "sync_booking_lifecycle_stage",
    "sync_cargo_shipping_lifecycle_stage",
]
