"""
Business Validators for Shipment Update Engine Module
"""

import re
from typing import Optional

from fastapi import HTTPException, status
from modules.shipment_updates.schemas import ShipmentUpdateLogCreate

# The update engine shows the 10 business phases (Phase 1..10); the lifecycle board tracks GP-002 steps and
# 6 board phases (ImportFile.current_step_code / current_phase_id). Steps are mapped in order so the
# business phase never goes backwards along the board.
BUSINESS_PHASE_BY_STEP = {
    "STEP_01": 1, "STEP_02": 1, "STEP_03": 1,
    "STEP_04": 2,
    "STEP_05": 3,
    "STEP_06": 4,
    "STEP_07": 5, "STEP_08": 5, "STEP_08_PO": 5, "STEP_08_BL": 5, "STEP_08_MATCH": 5, "STEP_08_COO": 5,
    "STEP_08_COC": 5, "STEP_09": 5, "STEP_10": 5, "STEP_11": 5, "STEP_12": 5,
    "STEP_13": 6,
    "STEP_14": 7, "STEP_15": 7, "STEP_16": 7, "STEP_17": 7, "STEP_18": 7,
    "STEP_19": 8,
    "STEP_20": 9,
    "STEP_21": 10,
}
# Board phase (1..6) of each business phase = the board phase of its first step.
BOARD_PHASE_BY_BUSINESS = {1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 5, 7: 5, 8: 6, 9: 6, 10: 6}
# First business phase of each board phase (fallback when a file has a board phase but no step code).
BUSINESS_PHASE_BY_BOARD = {1: 1, 2: 2, 3: 4, 4: 5, 5: 6, 6: 8}

PHASE_NUMBER_RE = re.compile(r"\bPhase (\d+)\b")


def phase_number(value: Optional[str]) -> Optional[int]:
    """1..10 from "Phase 3" / "Phase 10 - Closure" ("Phase 1" never matches "Phase 10")."""
    match = PHASE_NUMBER_RE.search(value or "")
    return int(match.group(1)) if match else None


def business_phase_of_file(step_code: Optional[str], board_phase_id: Optional[int], legacy_module: Optional[str]) -> int:
    """Business phase (1..10) of an import file: step code first, then the board phase id, then the legacy
    "Phase n" text of ``current_module`` (old rows; real values look like "STEP_13 Customs Declaration 46")."""
    if step_code and step_code in BUSINESS_PHASE_BY_STEP:
        return BUSINESS_PHASE_BY_STEP[step_code]
    if board_phase_id in BUSINESS_PHASE_BY_BOARD:
        return BUSINESS_PHASE_BY_BOARD[board_phase_id]
    legacy = phase_number(legacy_module)
    return legacy if legacy and 1 <= legacy <= 10 else 1


def validate_update_log_create(schema: ShipmentUpdateLogCreate):
    if not schema.note or not schema.note.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ملاحظة وتفاصيل التحديث مطلوبة ولا يمكن تركها فارغة.",
        )

    if not schema.log_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="تاريخ التحديث مطلوب.",
        )
