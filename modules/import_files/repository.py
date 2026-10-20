"""
Repository Layer for Import Files Master & Tracking Module
"""

import re
from typing import Dict, Iterable, List, Optional
from datetime import datetime, timezone, date
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func, desc
from sqlalchemy.exc import IntegrityError

from modules.import_files.model import ImportFile
from modules.external_service_providers.model import ExternalServiceProvider
from modules.common.pagination import PageParams, like_term, paginate


IMPORT_FILE_SORT_MAP = {
    "import_file_code": ImportFile.import_file_code,
    "created_at": ImportFile.created_at,
    "required_eta": ImportFile.required_eta,
    "file_opening_date": ImportFile.file_opening_date,
    "status": ImportFile.status,
    "progress_percent": ImportFile.progress_percent,
    "company_name": ImportFile.company_name,
}


from modules.common.sequence_generator import next_yearly_code


def generate_import_file_code(db: Session, year: Optional[int] = None) -> str:
    """Generates unique import file code: IMP-YYYY-XXXX using next_yearly_code."""
    return next_yearly_code(db, ImportFile.import_file_code, "IMP", pad=4, year=year)


def _apply_import_file_filters(
    query,
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
):
    if not include_inactive:
        query = query.filter(ImportFile.is_active == True)

    if parent_import_file_id is not None:
        query = query.filter(ImportFile.parent_import_file_id == parent_import_file_id)
    if is_partial_shipment is not None:
        query = query.filter(ImportFile.is_partial_shipment == is_partial_shipment)

    if company_id:
        query = query.filter(ImportFile.company_id == company_id)
    if supplier_id:
        query = query.filter(ImportFile.supplier_id == supplier_id)
    if status and status != "All":
        query = query.filter(ImportFile.status == status)
    if owner and owner != "All":
        query = query.filter(ImportFile.owner == owner)

    if hs_code and hs_code.strip():
        term = f"%{hs_code.strip()}%"
        query = query.filter(ImportFile.hs_code.ilike(term))
    if incoterm_code and incoterm_code.strip() and incoterm_code != "All":
        query = query.filter(ImportFile.incoterm_code.ilike(incoterm_code.strip()))
    if port_of_loading and port_of_loading.strip():
        term = f"%{port_of_loading.strip()}%"
        query = query.filter(ImportFile.port_of_loading.ilike(term))
    if port_of_discharge and port_of_discharge.strip():
        term = f"%{port_of_discharge.strip()}%"
        query = query.filter(ImportFile.port_of_discharge.ilike(term))
    if shipment_mode and shipment_mode.strip() and shipment_mode != "All":
        term = f"%{shipment_mode.strip()}%"
        query = query.filter(ImportFile.shipment_mode.ilike(term))
    if carrier and carrier.strip():
        term = f"%{carrier.strip()}%"
        query = query.filter(ImportFile.selected_scenario.ilike(term))

    if date_from:
        query = query.filter(
            or_(
                ImportFile.required_eta >= date_from,
                ImportFile.file_opening_date >= date_from,
            )
        )
    if date_to:
        query = query.filter(
            or_(
                ImportFile.required_eta <= date_to,
                ImportFile.file_opening_date <= date_to,
            )
        )

    if search and search.strip():
        term = like_term(search)
        query = query.filter(
            or_(
                ImportFile.import_file_code.ilike(term, escape="\\"),
                ImportFile.custom_file_number.ilike(term, escape="\\"),
                ImportFile.company_name.ilike(term, escape="\\"),
                ImportFile.supplier_name.ilike(term, escape="\\"),
                ImportFile.po_number.ilike(term, escape="\\"),
                ImportFile.pi_number.ilike(term, escape="\\"),
                ImportFile.owner.ilike(term, escape="\\"),
                ImportFile.hs_code.ilike(term, escape="\\"),
                ImportFile.product_category.ilike(term, escape="\\"),
                ImportFile.port_of_loading.ilike(term, escape="\\"),
                ImportFile.port_of_discharge.ilike(term, escape="\\"),
                ImportFile.selected_scenario.ilike(term, escape="\\"),
                ImportFile.notes.ilike(term, escape="\\"),
            )
        )

    return query


def get_all_import_files(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
) -> List[ImportFile]:
    query = db.query(ImportFile)
    query = _apply_import_file_filters(
        query,
        include_inactive=include_inactive,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        parent_import_file_id=parent_import_file_id,
        is_partial_shipment=is_partial_shipment,
    )
    return query.order_by(ImportFile.import_file_id.desc()).all()


def count_import_files(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
) -> int:
    query = db.query(ImportFile)
    query = _apply_import_file_filters(
        query,
        include_inactive=include_inactive,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        parent_import_file_id=parent_import_file_id,
        is_partial_shipment=is_partial_shipment,
    )
    return query.count()


def get_paginated_import_files(
    db: Session,
    params: PageParams,
    *,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
) -> dict:
    effective_search = params.q if params.q is not None else search

    query = db.query(ImportFile)
    query = _apply_import_file_filters(
        query,
        include_inactive=params.include_inactive,
        search=effective_search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        parent_import_file_id=parent_import_file_id,
        is_partial_shipment=is_partial_shipment,
    )

    return paginate(
        query,
        params,
        sort_map=IMPORT_FILE_SORT_MAP,
        default_sort=[ImportFile.import_file_id.desc()],
        pk=ImportFile.import_file_id,
    )


def get_child_partial_files(db: Session, parent_file_id: int) -> List[ImportFile]:
    """Fetches all active child partial files linked to a parent file."""
    return (
        db.query(ImportFile)
        .filter(
            ImportFile.parent_import_file_id == parent_file_id,
            ImportFile.is_active == True,
        )
        .order_by(ImportFile.import_file_id.asc())
        .all()
    )


def count_child_partial_files(db: Session, parent_file_id: int) -> int:
    """Counts total child partial files linked to a parent file."""
    return (
        db.query(ImportFile)
        .filter(
            ImportFile.parent_import_file_id == parent_file_id,
        )
        .count()
    )




def get_import_file_by_id(db: Session, import_file_id: int) -> Optional[ImportFile]:
    return db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True
    ).first()


def codes_by_ids(db: Session, ids: Iterable[Optional[int]]) -> Dict[int, str]:
    """Display code per import file id (``import_file_code``, else ``custom_file_number``), one query.
    Soft-deleted files are included (the code is still the business reference); ids without a code are omitted."""
    wanted = {i for i in ids if i is not None}
    if not wanted:
        return {}
    rows = (
        db.query(ImportFile.import_file_id, ImportFile.import_file_code, ImportFile.custom_file_number)
        .filter(ImportFile.import_file_id.in_(wanted))
        .all()
    )
    return {fid: (code or custom) for fid, code, custom in rows if (code or custom)}


def get_import_file_by_code(
    db: Session, code_or_custom_num: str, include_inactive: bool = False
) -> Optional[ImportFile]:
    term = (code_or_custom_num or "").strip()
    query = db.query(ImportFile).filter(
        or_(
            ImportFile.import_file_code == term,
            ImportFile.custom_file_number == term,
        )
    )
    if not include_inactive:
        query = query.filter(ImportFile.is_active == True)
    return query.first()


def create_import_file(db: Session, obj_data: dict) -> ImportFile:
    auto_code = not bool(obj_data.get("import_file_code"))

    for attempt in range(3):
        if auto_code:
            obj_data["import_file_code"] = generate_import_file_code(db)
            if not obj_data.get("custom_file_number"):
                obj_data["custom_file_number"] = obj_data["import_file_code"].replace("IMP-", "FILE-")
        db_obj = ImportFile(**obj_data)
        db.add(db_obj)
        try:
            db.commit()
            db.refresh(db_obj)
            return db_obj
        except IntegrityError:
            db.rollback()
            if attempt == 2 or not auto_code:
                raise
            obj_data.pop("import_file_code", None)
            if obj_data.get("custom_file_number", "").startswith("FILE-"):
                obj_data.pop("custom_file_number", None)


def update_import_file(db: Session, import_file_id: int, update_data: dict) -> Optional[ImportFile]:
    db_obj = get_import_file_by_id(db, import_file_id)
    if not db_obj:
        return None

    for key, value in update_data.items():
        if hasattr(db_obj, key):
            setattr(db_obj, key, value)

    db_obj.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_obj)
    return db_obj


def soft_delete_import_file(db: Session, import_file_id: int) -> bool:
    db_obj = get_import_file_by_id(db, import_file_id)
    if not db_obj:
        return False

    db_obj.is_active = False
    db_obj.updated_at = datetime.now(timezone.utc)
    db.commit()
    return True


def _parse_phase_number(phase: str) -> Optional[int]:
    """'Phase 5' / 'PHASE_5' / '5' -> 5; anything else -> None (legacy text filter only)."""
    match = re.fullmatch(r"(?:phase[\s_-]*)?(\d{1,2})", phase.strip(), re.IGNORECASE)
    return int(match.group(1)) if match else None


def get_operational_dashboard_data(
    db: Session,
    phase: Optional[str] = None,
    priority: Optional[str] = None,
    broker_id: Optional[int] = None,
    broker_name: Optional[str] = None,
    search: Optional[str] = None,
):
    """
    Fetches operational dashboard shipments matching phase, priority, broker, and search
    using strict AND combination logic. Returns shipment count, list, phase counts, and dynamic brokers.
    """
    query = db.query(ImportFile).filter(ImportFile.is_active == True)

    # 1. Phase Filter
    # Coded rows match on current_phase_id; legacy rows (current_phase_id IS NULL) keep the text match.
    if phase and phase != "All":
        phase_str = str(phase).strip()
        legacy_match = or_(
            ImportFile.current_module.ilike(f"%{phase_str}%"),
            ImportFile.current_stage.ilike(f"%{phase_str}%"),
        )
        phase_num = _parse_phase_number(phase_str)
        if phase_num is None:
            query = query.filter(legacy_match)
        else:
            query = query.filter(
                or_(
                    ImportFile.current_phase_id == phase_num,
                    and_(ImportFile.current_phase_id.is_(None), legacy_match),
                )
            )

    # 2. Priority Filter
    if priority and priority != "All":
        query = query.filter(ImportFile.priority == priority)

    # 3. Customs Broker Filter
    if broker_id:
        query = query.filter(ImportFile.broker_id == broker_id)
    elif broker_name and broker_name != "All":
        query = query.filter(ImportFile.broker_name == broker_name)

    # 4. Search Filter
    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                ImportFile.import_file_code.ilike(term),
                ImportFile.custom_file_number.ilike(term),
                ImportFile.company_name.ilike(term),
                ImportFile.supplier_name.ilike(term),
                ImportFile.po_number.ilike(term),
                ImportFile.broker_name.ilike(term),
            )
        )

    shipments = query.order_by(ImportFile.import_file_id.desc()).all()
    shipment_count = len(shipments)

    # Calculate Phase distribution across all active files using lightweight column query
    active_stages = (
        db.query(ImportFile.current_phase_id, ImportFile.current_module, ImportFile.current_stage)
        .filter(ImportFile.is_active == True)
        .all()
    )
    phase_counts = {f"Phase {i}": 0 for i in range(1, 11)}
    for phase_id, mod, stg in active_stages:
        if phase_id is not None:
            key = f"Phase {phase_id}"
            if key in phase_counts:
                phase_counts[key] += 1
            continue
        stage_text = f"{mod or ''} {stg or ''}"
        for i in range(1, 11):
            if re.search(rf"Phase {i}(?!\d)", stage_text):
                phase_counts[f"Phase {i}"] += 1

    # Dynamic Brokers List from Database
    brokers_query = db.query(ImportFile.broker_id, ImportFile.broker_name).filter(
        ImportFile.is_active == True,
        ImportFile.broker_name.isnot(None),
        ImportFile.broker_name != "",
    ).distinct().all()

    ext_brokers = db.query(ExternalServiceProvider).filter(
        ExternalServiceProvider.is_active == True,
        ExternalServiceProvider.partner_type == "Customs Broker",
    ).all()

    broker_dict = {}
    for p in ext_brokers:
        broker_dict[p.partner_name] = p.provider_id
    for b_id, b_name in brokers_query:
        if b_name and b_name not in broker_dict:
            broker_dict[b_name] = b_id

    available_brokers = [
        {"broker_id": v, "broker_name": k} for k, v in broker_dict.items()
    ]

    return {
        "shipment_count": shipment_count,
        "shipments": shipments,
        "last_updated_at": datetime.now(timezone.utc),
        "available_brokers": available_brokers,
        "phase_counts": phase_counts,
    }


def get_search_insights(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    company_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    owner: Optional[str] = None,
    hs_code: Optional[str] = None,
    incoterm_code: Optional[str] = None,
    port_of_loading: Optional[str] = None,
    port_of_discharge: Optional[str] = None,
    shipment_mode: Optional[str] = None,
    carrier: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    parent_import_file_id: Optional[int] = None,
    is_partial_shipment: Optional[bool] = None,
) -> Dict[str, any]:
    """Calculates Smart Insight Bar aggregations (Mode route, Mode mode, Latest freight, Avg landed cost)."""
    base_q = _apply_import_file_filters(
        db.query(ImportFile),
        include_inactive=include_inactive,
        search=search,
        company_id=company_id,
        supplier_id=supplier_id,
        status=status,
        owner=owner,
        hs_code=hs_code,
        incoterm_code=incoterm_code,
        port_of_loading=port_of_loading,
        port_of_discharge=port_of_discharge,
        shipment_mode=shipment_mode,
        carrier=carrier,
        date_from=date_from,
        date_to=date_to,
        parent_import_file_id=parent_import_file_id,
        is_partial_shipment=is_partial_shipment,
    )
    total_count = base_q.count()
    if total_count == 0:
        return {
            "total_count": 0,
            "mode_route": None,
            "mode_shipping_mode": None,
            "latest_freight_cost": None,
            "latest_freight_currency": "USD",
            "avg_landed_cost": None,
            "avg_landed_currency": "EGP",
        }

    # 1. Mode of route (most common POL -> POD)
    route_row = (
        _apply_import_file_filters(
            db.query(
                ImportFile.port_of_loading,
                ImportFile.port_of_discharge,
                func.count().label("cnt"),
            ),
            include_inactive=include_inactive,
            search=search,
            company_id=company_id,
            supplier_id=supplier_id,
            status=status,
            owner=owner,
            hs_code=hs_code,
            incoterm_code=incoterm_code,
            port_of_loading=port_of_loading,
            port_of_discharge=port_of_discharge,
            shipment_mode=shipment_mode,
            carrier=carrier,
            date_from=date_from,
            date_to=date_to,
            parent_import_file_id=parent_import_file_id,
            is_partial_shipment=is_partial_shipment,
        )
        .filter(
            or_(
                ImportFile.port_of_loading.isnot(None),
                ImportFile.port_of_discharge.isnot(None),
            )
        )
        .group_by(ImportFile.port_of_loading, ImportFile.port_of_discharge)
        .order_by(desc("cnt"))
        .first()
    )
    mode_route = None
    if route_row:
        pol = route_row[0] or "-"
        pod = route_row[1] or "-"
        mode_route = f"{pol} → {pod}"

    # 2. Mode of shipping mode (most common shipment_mode)
    mode_row = (
        _apply_import_file_filters(
            db.query(
                ImportFile.shipment_mode,
                func.count().label("cnt"),
            ),
            include_inactive=include_inactive,
            search=search,
            company_id=company_id,
            supplier_id=supplier_id,
            status=status,
            owner=owner,
            hs_code=hs_code,
            incoterm_code=incoterm_code,
            port_of_loading=port_of_loading,
            port_of_discharge=port_of_discharge,
            shipment_mode=shipment_mode,
            carrier=carrier,
            date_from=date_from,
            date_to=date_to,
            parent_import_file_id=parent_import_file_id,
            is_partial_shipment=is_partial_shipment,
        )
        .filter(ImportFile.shipment_mode.isnot(None))
        .group_by(ImportFile.shipment_mode)
        .order_by(desc("cnt"))
        .first()
    )
    mode_shipping_mode = mode_row[0] if mode_row else None

    # 3. Latest Freight Cost (most recent matching shipment by date, with freight > 0)
    latest_file = (
        base_q.filter(
            or_(
                ImportFile.estimated_cost > 0,
                ImportFile.actual_landed_cost_total_egp > 0,
            )
        )
        .order_by(
            func.coalesce(ImportFile.file_opening_date, ImportFile.created_at).desc(),
            ImportFile.import_file_id.desc(),
        )
        .first()
    )
    latest_freight_cost = None
    latest_freight_currency = "USD"
    if latest_file:
        latest_freight_cost = latest_file.estimated_cost
        latest_freight_currency = latest_file.estimated_cost_currency or "USD"

    # 4. Average final landed cost
    avg_cost_row = (
        _apply_import_file_filters(
            db.query(
                func.avg(
                    func.coalesce(
                        func.nullif(ImportFile.actual_landed_cost_total_egp, 0),
                        func.nullif(ImportFile.financial_settlement_total_egp, 0),
                        func.nullif(ImportFile.estimated_cost, 0),
                    )
                )
            ),
            include_inactive=include_inactive,
            search=search,
            company_id=company_id,
            supplier_id=supplier_id,
            status=status,
            owner=owner,
            hs_code=hs_code,
            incoterm_code=incoterm_code,
            port_of_loading=port_of_loading,
            port_of_discharge=port_of_discharge,
            shipment_mode=shipment_mode,
            carrier=carrier,
            date_from=date_from,
            date_to=date_to,
            parent_import_file_id=parent_import_file_id,
            is_partial_shipment=is_partial_shipment,
        ).scalar()
    )
    avg_landed_cost = round(float(avg_cost_row), 2) if avg_cost_row is not None else None

    return {
        "total_count": total_count,
        "mode_route": mode_route,
        "mode_shipping_mode": mode_shipping_mode,
        "latest_freight_cost": latest_freight_cost,
        "latest_freight_currency": latest_freight_currency,
        "avg_landed_cost": avg_landed_cost,
        "avg_landed_currency": "EGP",
    }

