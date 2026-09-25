"""
FastAPI Router for Logistics What-If Simulation & FX Exposure Radar (SIM-WHATIF-013 & FIN-HEDGE-011)
"""

from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.simulation.schemas import (
    WhatIfSimulationRequest,
    WhatIfSimulationResponse,
    FXExposureSummaryResponse,
    SavedScenarioCreate,
    SavedScenarioResponse,
)
from modules.simulation import service

router = APIRouter(
    prefix="/api/v1/simulation",
    tags=["Logistics What-If Simulation & FX Hedging (محاكي الأزمات وتحوط العملة)"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "/what-if",
    response_model=WhatIfSimulationResponse,
    status_code=status.HTTP_200_OK,
    summary="Run Logistics & Currency What-If Simulation",
)
def run_what_if_simulation_endpoint(
    request: WhatIfSimulationRequest,
    db: Session = Depends(get_db),
):
    """
    Executes What-If simulation with multi-factor impact analysis:
    - FX Rate shocks (-50% to +200%)
    - Maritime rerouting (Red Sea vs Cape of Good Hope +18 days)
    - Demurrage & port storage accumulation
    - ACID 180-day regulatory window tracking
    """
    return service.run_what_if_simulation_service(db=db, request=request)


@router.get(
    "/fx-exposure",
    response_model=FXExposureSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Calculate Open Foreign Currency Exposure and Value-at-Risk",
)
def get_fx_exposure_endpoint(
    db: Session = Depends(get_db),
):
    """
    Evaluates unhedged foreign currency obligations across active import files,
    projecting devaluation impact under +10% and +25% exchange rate shifts.
    """
    return service.calculate_open_fx_exposure_service(db=db)


@router.post(
    "/saved-scenarios",
    response_model=SavedScenarioResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Save a Simulation Scenario for Executive Decision & Audit",
)
def save_scenario_endpoint(
    payload: SavedScenarioCreate,
    db: Session = Depends(get_db),
):
    """Persists a simulated what-if scenario to the database."""
    return service.save_scenario_service(db=db, payload=payload)


@router.get(
    "/saved-scenarios",
    response_model=List[SavedScenarioResponse],
    status_code=status.HTTP_200_OK,
    summary="List Saved Simulation Scenarios",
)
def list_saved_scenarios_endpoint(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """Retrieves list of saved simulation scenarios."""
    return service.list_saved_scenarios_service(db=db, limit=limit, offset=offset)
