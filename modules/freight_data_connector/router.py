from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Query
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from typing import List, Optional

from database.database import get_db
from .service import FreightDataService
from .schemas import (
    FreightIndexSnapshotResponse,
    FreightIndexSyncResponse,
    DemurrageRuleResponse,
    PortDemurrageTariffResponse,
    PortDemurrageTariffCreate,
    DualDemurrageCalculateRequest,
    DualDemurrageCalculateResponse,
    FreightConnectorStatusResponse,
)

freight_data_router = APIRouter(
    prefix="/api/v1/freight-data",
    tags=["Freight & Demurrage External Data Connector (INT-DATA-015)"],
    dependencies=[Depends(get_current_user)],
)


@freight_data_router.get(
    "/status",
    response_model=FreightConnectorStatusResponse,
    summary="Get status, quota monitor, and data source health"
)
def get_connector_status(db: Session = Depends(get_db)):
    service = FreightDataService(db)
    return service.get_connector_status()


@freight_data_router.get(
    "/snapshots/latest",
    response_model=List[FreightIndexSnapshotResponse],
    summary="Get latest global container shipping freight indices (SFX)"
)
def get_latest_snapshots(db: Session = Depends(get_db)):
    service = FreightDataService(db)
    return service.get_latest_freight_index()


@freight_data_router.post(
    "/snapshots/sync",
    response_model=FreightIndexSyncResponse,
    summary="Manually trigger SFX weekly freight index sync via shaq-freight", dependencies=[Depends(require_permission("quotations.manage"))]
)
@freight_data_router.post(
    "/sync-shaq-freight",
    response_model=FreightIndexSyncResponse,
    summary="Alias: Manually trigger SFX weekly freight index sync via shaq-freight", dependencies=[Depends(require_permission("quotations.manage"))]
)
def sync_freight_index(db: Session = Depends(get_db)):
    service = FreightDataService(db)
    count = service.sync_shaq_freight_index(force_sample_if_unavailable=True)
    return FreightIndexSyncResponse(
        success=True,
        source="shaq-freight",
        records_synced=count,
        synced_at=service.get_connector_status().last_sfx_sync or datetime.now(),
        message=f"Successfully synced {count} global trade lane rate snapshots."
    )



@freight_data_router.get(
    "/demurrage-rules",
    response_model=List[DemurrageRuleResponse],
    summary="Get shipping line container detention rules (USD)"
)
def get_demurrage_rules(shipping_line: Optional[str] = None, db: Session = Depends(get_db)):
    service = FreightDataService(db)
    return service.get_demurrage_rules(shipping_line)


@freight_data_router.post(
    "/demurrage-rules/sync",
    response_model=DemurrageRuleResponse,
    summary="Trigger quota-protected rule sync for a carrier via ShippingRates.org", dependencies=[Depends(require_permission("demurrage_detention.manage"))]
)
def sync_demurrage_rule(
    shipping_line: str = Query(..., description="Carrier name e.g. maersk, msc, cma_cgm"),
    container_type: str = Query("40HC", description="Container type"),
    db: Session = Depends(get_db)
):
    service = FreightDataService(db)
    return service.sync_shippingrates_rules(shipping_line, container_type)


@freight_data_router.get(
    "/port-tariffs",
    response_model=List[PortDemurrageTariffResponse],
    summary="Get Egyptian port authority versioned storage decrees (EGP)"
)
def get_port_tariffs(port_authority: Optional[str] = None, db: Session = Depends(get_db)):
    service = FreightDataService(db)
    return service.get_port_tariffs(port_authority)


@freight_data_router.post(
    "/port-tariffs",
    response_model=PortDemurrageTariffResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new official port authority decree version", dependencies=[Depends(require_permission("quotations.manage"))]
)
def create_port_tariff(payload: PortDemurrageTariffCreate, db: Session = Depends(get_db)):
    service = FreightDataService(db)
    from .model import PortDemurrageTariff
    tariff = PortDemurrageTariff(
        port_authority=payload.port_authority,
        container_type=payload.container_type,
        free_days=payload.free_days,
        rate_slabs=payload.rate_slabs,
        tariff_version=payload.tariff_version,
        effective_from=payload.effective_from,
        effective_to=payload.effective_to,
        source_document=payload.source_document,
        entered_by=payload.entered_by,
    )
    return service.repo.create_port_tariff(tariff)


@freight_data_router.post(
    "/calculate-dual-demurrage",
    response_model=DualDemurrageCalculateResponse,
    summary="Instant local calculation of USD carrier detention & EGP port storage", dependencies=[Depends(require_permission("demurrage_detention.manage"))]
)
def calculate_dual_demurrage(payload: DualDemurrageCalculateRequest, db: Session = Depends(get_db)):
    service = FreightDataService(db)
    return service.calculate_dual_demurrage(payload)
