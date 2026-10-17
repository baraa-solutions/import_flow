import json
import re
import sys
import asyncio

if sys.platform == "win32" and sys.version_info < (3, 8):
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from typing import Optional
from fastapi import FastAPI, Request, Response, Depends, Query, Header, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

# ==================================================
# Database
# ==================================================

from database.database import Base
from database.database import engine
from database.database import DB_PATH
from utils.db_safety import (
    MAINTENANCE_DETAIL,
    checkpoint_wal,
    enter_maintenance_mode,
    is_maintenance_mode,
    is_request_allowed_in_maintenance,
    read_installed_version,
    version_file_path,
)


# ==================================================
# Import Models
# ==================================================

from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider
from modules.users.model import User, Role, Permission, RolePermission, UserPermission
from modules.auth.revoked_token_model import RevokedToken
from modules.common.concurrency import ConcurrencyConflictLog
from modules.audit_logs.model import AuditLog
from modules.incoterms.model import Incoterm, CostItem, IncotermResponsibility
from modules.customs_tariff.model import CustomsTariff
from modules.transport_locations.model import TransportLocation
from modules.currencies.model import Currency, ExchangeRate
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, PurchaseOrder
from modules.cbm_calculator.model import CBMCalculation, CBMCalculationItem
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.customs_consultation.model import CustomsConsultationSession, CustomsChecklistItem
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.customs_clearance_quotations.model import CustomsClearanceRFQ, CustomsClearanceQuotationItem, ClearanceServicePriceListItem
from modules.financial_approval.model import (
    PaymentRequestSession,
    ImportBudgetApproval,
    SwiftExtractionBatch,
    SwiftExtractionField,
    OcrCorrectionsLog,
)
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
    POPackingReconciliationSession,
    InvoiceBLMatchSession,
)

from modules.import_files.model import ImportFile
from modules.freight_booking.model import ShipmentBooking
from modules.cargo_shipping.model import CargoShippingRecord
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.warehouse_receiving.model import WarehouseReceivingRecord
from modules.inland_transport.model import InlandTransportBooking
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.file_closure.model import ImportFileClosureRecord
from modules.notifications.model import SystemNotification
from modules.smart_tasks.model import SmartTask
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.demurrage_detention.model import DemurragePolicy, DemurrageTracking
from modules.smart_document_upload.model import UploadSession
from modules.docs_customs_approval.model import (
    CustomsDocumentApproval,
    DiscrepancyRectificationTicket,
    DocsCustomsApprovalSession,
)
from modules.cargox.model import CargoXEnvelope, CargoXEnvelopeDocument, CargoXStandardInvoiceReviewSession
from modules.original_documents_collection.model import OriginalDocumentsCollectionSession
from modules.cargo_insurance.model import CargoInsuranceCertificate
from modules.route_intelligence.model import RouteOperationalNote
from modules.simulation.model import SavedSimulationScenario
from modules.lifecycle_board.model import (
    ShipmentStageActivity,
    StepConfig,
    StepConfigAuditLog,
    PendingReferenceRecord,
)
from modules.smart_email_listener.model import InboundEmailLog, EmailSettings
from modules.formal_letters.model import FormalLetterRecord
from modules.freight_data_connector.model import (
    FreightIndexSnapshot,
    DemurrageRule,
    PortDemurrageTariff,
    ExternalApiQuotaLog,
)
from modules.expense_catalog.model import ExpenseCatalog
from modules.experience_guide.model import GuideEntry, GuideEntryScope
from modules.smart_checklists.model import ImportFileChecklistItem
from modules.recalculation.model import RecalculationDependencyMap, RecalculationLog
from modules.logistics_invoices.model import (
    LogisticsServiceInvoice,
    LogisticsInvoiceLine,
    LogisticsInvoiceContainer,
    InsurancePolicy,
    ClearanceAdvancePayment,
    ClearanceAdvanceSettlement,
    LogisticsPaymentVoucher,
    InvoiceKnockoff,
)
from modules.containers.model import ShipmentContainer



# ==================================================
# Import Routers
# ==================================================

from modules.import_companies.router import import_router
from modules.suppliers.router import supplier_router
from modules.external_service_providers.router import router as provider_router
from modules.audit_logs.router import router as audit_router
from modules.auth.router import router as auth_router, require_admin
from modules.incoterms.router import incoterms_router
from modules.customs_tariff.router import customs_tariff_router
from modules.transport_locations.router import router as transport_locations_router
from modules.currencies.router import router as currencies_router
from modules.projects.router import router as projects_router
from modules.purchase_orders.router import router as purchase_orders_router
from modules.cbm_calculator.router import router as cbm_calculator_router
from modules.shipping_scenarios.router import router as shipping_scenarios_router
from modules.customs_consultation.router import router as customs_consultation_router
from modules.freight_quotations.router import router as freight_quotations_router
from modules.customs_clearance_quotations.router import router as customs_clearance_quotations_router
from modules.financial_approval.router import router as financial_approval_router
from modules.import_documentation.router import router as import_documentation_router
from modules.import_files.router import router as import_files_router
from modules.freight_booking.router import router as freight_booking_router
from modules.cargo_shipping.router import router as cargo_shipping_router
from modules.cargo_insurance.router import router as cargo_insurance_router
from modules.customs_clearance.router import router as customs_clearance_router
from modules.warehouse_receiving.router import router as warehouse_receiving_router
from modules.inland_transport.router import router as inland_transport_router
from modules.financial_settlement.router import router as financial_settlement_router
from modules.file_closure.router import router as file_closure_router
from modules.notifications.router import router as notifications_router, ws_router as notifications_ws_router
from modules.integrations.router import router as integrations_router
from modules.container_loader.router import container_loader_router
from modules.smart_tasks.router import router as smart_tasks_router
from modules.shipment_updates.router import router as shipment_updates_router
from modules.import_requirements.router import router as import_requirements_router
from modules.demurrage_detention.router import router as demurrage_detention_router
from modules.lifecycle_board.router import router as lifecycle_board_router
from modules.smart_document_upload.router import router as smart_document_upload_router
from modules.docs_customs_approval.router import router as docs_customs_approval_router
from modules.cargox.router import router as cargox_router
from modules.original_documents_collection.router import router as original_documents_collection_router
from modules.production_sync.router import router as production_sync_router
from modules.route_intelligence.router import router as route_intelligence_router
from modules.simulation.router import router as simulation_router
from modules.smart_email_listener.router import router as smart_email_listener_router, compat_router as smart_email_compat_router
from modules.formal_letters.router import router as formal_letters_router
from modules.freight_data_connector.router import freight_data_router
from modules.expense_catalog.router import router as expense_catalog_router
from modules.experience_guide.router import router as experience_guide_router
from modules.smart_checklists.router import router as smart_checklists_router
from modules.recalculation.router import router as recalculation_router
from modules.system_observability.router import router as system_observability_router
from modules.app_update.router import router as app_update_router
from modules.logistics_invoices.router import router as logistics_invoices_router
from modules.containers.router import router as containers_router
from modules.system_observability.middleware import ObservabilityMiddleware
from modules.system_observability.service import setup_query_listener

# Setup query execution timing on SQLAlchemy engine
setup_query_listener(engine)

# ==================================================
# Create FastAPI Application
# ==================================================

import logging as _logging
import settings as _settings

# Interactive API docs expose the full route map: served only when ENABLE_API_DOCS is set.
INSTALLED_VERSION = read_installed_version()  # "unknown" when version.json is missing/malformed

app = FastAPI(
    title="Sorour Logistics ERP API",
    version=INSTALLED_VERSION,
    docs_url="/docs" if _settings.ENABLE_API_DOCS else None,
    redoc_url="/redoc" if _settings.ENABLE_API_DOCS else None,
    openapi_url="/openapi.json" if _settings.ENABLE_API_DOCS else None,
)

if _settings.ALLOW_DEV_AUTH_BYPASS:
    _logging.getLogger("main").warning(
        "ALLOW_DEV_AUTH_BYPASS is enabled: requests without an Authorization header are resolved to "
        "a local user. Never enable this on a networked or production deployment."
    )

# ==================================================
# Observability & Request Correlation Middleware
# ==================================================
app.add_middleware(ObservabilityMiddleware)

# ==================================================
# Response Compression Middleware (GZip)
# ==================================================
from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(GZipMiddleware, minimum_size=1000)

# ==================================================
# Maintenance Mode (writes blocked after a failed startup DB upgrade, R8/A11)
# ==================================================
# Registered before the CORS middleware so the CORS headers still wrap the 503 response.


@app.middleware("http")
async def maintenance_mode_middleware(request: Request, call_next):
    if is_maintenance_mode() and not is_request_allowed_in_maintenance(request.method, request.url.path):
        from fastapi.responses import JSONResponse

        return JSONResponse(
            status_code=503,
            content={"detail": MAINTENANCE_DETAIL, "maintenance_mode": True},
        )
    return await call_next(request)

# ==================================================
# CORS & Private Network Access (PNA) Middleware
# ==================================================
# NOTE: We use a single unified custom middleware instead of FastAPI's built-in
# CORSMiddleware to avoid conflicts. In Starlette, middlewares execute LIFO
# (Last In, First Out), so two separate CORS handlers conflict — the http
# middleware intercepts OPTIONS before CORSMiddleware can add its headers.
# This unified handler covers both preflight (OPTIONS) and actual requests.

import re as _re

CORS_ALLOWED_METHODS = "GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD"
CORS_ALLOWED_ORIGIN_REGEX = r"^https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2[0-9]|3[0-1])\.\d+\.\d+)(:[0-9]+)?$"

# Keep LOCAL_ORIGIN_REGEX as alias used in the global exception handler below
LOCAL_ORIGIN_REGEX = CORS_ALLOWED_ORIGIN_REGEX


def is_cors_origin_allowed(origin: str) -> bool:
    """True only for an http(s) origin on localhost / a private network address (CORS_ALLOWED_ORIGIN_REGEX)."""
    return bool(origin and _re.match(CORS_ALLOWED_ORIGIN_REGEX, origin))


@app.middleware("http")
async def cors_and_pna_middleware(request: Request, call_next):
    raw_origin = request.headers.get("origin", "")
    # Only real local / LAN origins. "null" (sandboxed iframes, file:// pages) and "*" are never echoed back
    # with credentials: any web page could otherwise drive this API (e.g. log in with the default admin).
    is_allowed = is_cors_origin_allowed(raw_origin)

    # Security headers applied system-wide
    sec_headers = {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "Referrer-Policy": "strict-origin-when-cross-origin",
        "Content-Security-Policy": "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; frame-ancestors 'none'; object-src 'none';",
        "Permissions-Policy": "geolocation=(), camera=(), microphone=()",
    }
    proto = request.headers.get("x-forwarded-proto", request.url.scheme)
    if proto == "https":
        sec_headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    # Handle CORS preflight (OPTIONS) immediately
    if request.method == "OPTIONS":
        req_headers = request.headers.get("access-control-request-headers", "*")
        response = Response(status_code=204)
        for k, v in sec_headers.items():
            response.headers[k] = v
        if is_allowed:
            response.headers["Access-Control-Allow-Origin"] = raw_origin
            response.headers["Access-Control-Allow-Methods"] = CORS_ALLOWED_METHODS
            response.headers["Access-Control-Allow-Headers"] = req_headers
            response.headers["Access-Control-Expose-Headers"] = "*"
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Private-Network"] = "true"
            response.headers["Access-Control-Max-Age"] = "86400"
            response.headers["Vary"] = "Origin"
        return response

    response = await call_next(request)

    # Inject security headers on every response
    for k, v in sec_headers.items():
        response.headers[k] = v

    # Inject CORS + PNA headers strictly if origin is authorized
    if is_allowed:
        response.headers["Access-Control-Allow-Origin"] = raw_origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Private-Network"] = "true"
        response.headers["Access-Control-Expose-Headers"] = "*"
        response.headers["Vary"] = "Origin"

    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import logging
    import os
    import re
    from fastapi.responses import JSONResponse

    logging.getLogger("main").error(f"Unhandled server error: {exc}", exc_info=True)
    raw_origin = request.headers.get("origin", "")
    is_allowed = bool(raw_origin and re.match(LOCAL_ORIGIN_REGEX, raw_origin))
    headers = {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "Referrer-Policy": "strict-origin-when-cross-origin",
    }
    if is_allowed:
        headers["Access-Control-Allow-Origin"] = raw_origin
        headers["Access-Control-Allow-Credentials"] = "true"
        headers["Access-Control-Allow-Private-Network"] = "true"
        headers["Vary"] = "Origin"

    is_debug = os.getenv("DEBUG", "false").lower() in ("true", "1")
    detail = f"Internal Server Error: {str(exc)}" if is_debug else "Internal Server Error"
    return JSONResponse(
        status_code=500,
        content={"detail": detail},
        headers=headers,
    )



# ==================================================
# Include Routers
# ==================================================

app.include_router(auth_router)
app.include_router(import_router)
app.include_router(supplier_router)
app.include_router(provider_router)
app.include_router(audit_router)
app.include_router(incoterms_router)
app.include_router(customs_tariff_router)
app.include_router(transport_locations_router)
app.include_router(currencies_router)
app.include_router(projects_router)
app.include_router(purchase_orders_router)
app.include_router(cbm_calculator_router)
app.include_router(container_loader_router)
app.include_router(shipping_scenarios_router)
app.include_router(customs_consultation_router)
app.include_router(freight_quotations_router)
app.include_router(customs_clearance_quotations_router)
app.include_router(financial_approval_router)
app.include_router(import_documentation_router)
app.include_router(import_files_router)
app.include_router(freight_booking_router)
app.include_router(cargo_shipping_router)
app.include_router(cargo_insurance_router)
app.include_router(customs_clearance_router)
app.include_router(inland_transport_router)
app.include_router(warehouse_receiving_router)
app.include_router(financial_settlement_router)
app.include_router(file_closure_router)
app.include_router(notifications_router)
app.include_router(notifications_ws_router)
app.include_router(integrations_router)
app.include_router(smart_tasks_router)
app.include_router(shipment_updates_router)
app.include_router(import_requirements_router)
app.include_router(demurrage_detention_router)
app.include_router(lifecycle_board_router)
app.include_router(smart_document_upload_router)
app.include_router(docs_customs_approval_router)
app.include_router(cargox_router)
app.include_router(original_documents_collection_router)
app.include_router(production_sync_router)
app.include_router(route_intelligence_router)
app.include_router(simulation_router)
app.include_router(smart_email_listener_router)
app.include_router(smart_email_compat_router)
app.include_router(formal_letters_router)
app.include_router(freight_data_router)
app.include_router(expense_catalog_router)
app.include_router(experience_guide_router)
app.include_router(smart_checklists_router)
app.include_router(recalculation_router)
app.include_router(system_observability_router)
app.include_router(app_update_router)
app.include_router(logistics_invoices_router)
app.include_router(containers_router)



# ==================================================
# Create & Incrementally Upgrade Database Tables Safely
# ==================================================

from database.schema_upgrade_service import SchemaUpgradeService

# Automated Safe In-Place Schema Upgrade and Master Data Synchronization.
# A failure never crashes the import silently or lets the app keep writing to a half-upgraded DB:
# it is logged at CRITICAL level and the app starts in maintenance mode (writes return 503).
try:
    SchemaUpgradeService.execute_safe_startup_upgrade(
        target_engine=engine,
        metadata=Base.metadata,
    )
except Exception as _startup_exc:  # noqa: BLE001 - any failure must block writes, not crash silently
    _logging.getLogger("main").critical(
        "Startup database upgrade raised %s: %s", type(_startup_exc).__name__, _startup_exc, exc_info=True
    )
    enter_maintenance_mode(f"startup upgrade raised {type(_startup_exc).__name__}: {_startup_exc}")




# ==================================================
# Dashboard
# ==================================================

@app.get("/")
def dashboard():
    return {
        "system": "Sorour Logistics ERP",
        "version": INSTALLED_VERSION,
        "status": "running",
    }


# ==================================================
# Health Check
# ==================================================

@app.get("/health")
@app.get("/api/v1/health")
def health_check():
    import sqlite3
    import os
    db_path = DB_PATH
    db_exists = os.path.exists(db_path)
    db_size_kb = round(os.path.getsize(db_path) / 1024, 1) if db_exists else 0
    tables_count = 0
    if db_exists:
        try:
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()
            cur.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
            tables_count = cur.fetchone()[0]
            conn.close()
        except Exception:
            pass

    return {
        "status": "OK",
        "system": "Sorour Logistics ERP",
        "version": INSTALLED_VERSION,
        "database": {
            "connected": db_exists,
            "size_kb": db_size_kb,
            "tables_count": tables_count,
        },
        "maintenance_mode": is_maintenance_mode(),
    }


# ==================================================
# System Version & Client Update Check
# ==================================================

def _parse_semver(v_str: str):
    try:
        parts = [int(p) for p in re.sub(r"[^\d\.]", "", v_str.strip()).split(".")[:3]]
        while len(parts) < 3:
            parts.append(0)
        return tuple(parts)
    except Exception:
        return (0, 0, 0)


@app.get("/api/v1/system/version-check")
@app.get("/api/v1/system/version")
def system_version_check(
    client_version: Optional[str] = Query(None, description="Current client app semver"),
    x_client_version: Optional[str] = Header(None, alias="X-Client-Version"),
):
    version_file = version_file_path()
    ver_data = {}
    if version_file.exists():
        try:
            with open(version_file, "r", encoding="utf-8") as f:
                ver_data = json.load(f)
        except Exception:
            pass

    ver_str = ver_data.get("version", "1.0.198")
    build_num = ver_data.get("build_number", 199)
    min_compat_str = ver_data.get("min_compatible_version", "1.0.180")

    req_client_ver = client_version or x_client_version
    parsed_server_ver = _parse_semver(ver_str)
    parsed_min_compat = _parse_semver(min_compat_str)

    has_update = False
    is_compatible = True
    force_update = False

    if req_client_ver:
        parsed_client_ver = _parse_semver(req_client_ver)
        if parsed_client_ver < parsed_server_ver:
            has_update = True
        if parsed_client_ver < parsed_min_compat:
            is_compatible = False
            force_update = True

    return {
        "status": "OK",
        "system_name": "Sorour Logistics ERP",
        "current_version": ver_str,
        "latest_version": ver_str,
        "client_version": req_client_ver,
        "min_compatible_version": min_compat_str,
        "build_number": build_num,
        "has_update": has_update,
        "is_compatible": is_compatible,
        "force_update": force_update,
        "check_status": "update_available" if has_update else "up_to_date",
        "installer_url": ver_data.get("installer_url", f"https://github.com/ahmedsalahsorour88/import_flow/releases/download/v{ver_str}/Sorour_Logistics_Setup_v{ver_str}.exe"),
        "installer_filename": ver_data.get("installer_filename", f"Sorour_Logistics_Setup_v{ver_str}.exe"),
        "installer_size_mb": ver_data.get("installer_size_mb", 198.04),
        "release_notes": ver_data.get("release_notes", [
            "Sorour Logistics ERP Production Release",
            "Full enterprise import workflow, customs calculation, and landed cost modules",
        ]),
        "updated_at": ver_data.get("updated_at", ""),
    }


# ==================================================
# Graceful System Shutdown
# ==================================================

@app.post("/shutdown")
@app.post("/api/v1/shutdown")
def shutdown_system(current_user: User = Depends(require_admin)):
    import os
    import threading
    import time

    def _delayed_exit():
        time.sleep(0.3)
        checkpoint_wal(DB_PATH)
        os._exit(0)

    threading.Thread(target=_delayed_exit, daemon=True).start()
    return {
        "status": "shutting down",
        "message": "Sorour Logistics backend is shutting down gracefully...",
    }


if __name__ == "__main__":
    import uvicorn

    from utils.runtime_port import resolve_port

    uvicorn.run("main:app", host="127.0.0.1", port=resolve_port(), log_config=None, access_log=False)
