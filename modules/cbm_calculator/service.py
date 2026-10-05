from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.cbm_calculator.model import CBMCalculation
from modules.cbm_calculator.repository import CBMRepository
from modules.cbm_calculator.schemas import (
    CBMCalculationCreate,
    CBMCalculationResponse,
    CBMCalculationUpdate,
    CBMItemCreate,
    CBMQuickCalcRequest,
    CBMQuickCalcResponse,
    CloneCBMCalculationRequest,
)
from modules.cbm_calculator.validators import CBMValidator
from modules.common import cargo_math, enum_codes
from modules.common.validators import get_or_404
from modules.common.system_parameters import DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM, air_volumetric_kg_per_cbm
from modules.import_files.repository import codes_by_ids
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder

# "Not preloaded" marker for _to_response: list rows pass their (possibly None) values and never re-query.
_LOOKUP: Any = object()


def _containers_text(count: int) -> str:
    return f"{count} x {cargo_math.CONTAINER_C40_HC}"


def _method_code(value: Optional[str]) -> Optional[str]:
    return enum_codes.normalize(enum_codes.SHIPPING_METHOD, value) if value else value


def _container_code(value: Optional[str]) -> Optional[str]:
    # The legacy "N/A (Air Freight Cargo)" text normalizes to None (no container for air).
    return enum_codes.normalize(enum_codes.CONTAINER_TYPE, value) if value else None


class CBMService:

    @staticmethod
    def compute_items_and_totals(items: List[CBMItemCreate], kg_per_cbm: float) -> Tuple[List[dict], dict]:
        """Line measurements, volumetric / chargeable weight (``kg_per_cbm`` = configurable air factor),
        and the shipping-method / container recommendation as codes."""
        CBMValidator.validate_items(items)

        computed_items = []
        total_qty = 0
        sum_cbm = 0.0
        sum_gross_wt = 0.0

        for item in items:
            qty = item.quantity
            l_m, w_m, h_m = cargo_math.to_metres(item.length, item.width, item.height, item.unit)
            line_cbm = qty * l_m * w_m * h_m
            line_gross_wt = qty * item.gross_weight_per_unit_kg
            sum_cbm += line_cbm
            sum_gross_wt += line_gross_wt
            total_qty += qty

            computed_items.append({
                "package_type": item.package_type,
                "quantity": qty,
                "length": item.length,
                "width": item.width,
                "height": item.height,
                "unit": item.unit,
                "length_cm": round(l_m * 100.0, 2),
                "width_cm": round(w_m * 100.0, 2),
                "height_cm": round(h_m * 100.0, 2),
                "gross_weight_per_unit_kg": item.gross_weight_per_unit_kg,
                "total_cbm": round(line_cbm, 4),
                "volumetric_weight_kg": round(cargo_math.volumetric_weight_kg(line_cbm, kg_per_cbm), 2),
                "total_gross_weight_kg": round(line_gross_wt, 2),
                "is_stackable": item.is_stackable,
            })

        total_cbm = round(sum_cbm, 4)
        total_gross_weight_kg = round(sum_gross_wt, 2)
        rec = cargo_math.recommend_container(total_cbm, total_gross_weight_kg)
        hybrid, flat, savings = cargo_math.container_counts_40hc(total_cbm)

        summary_totals = {
            "total_qty": total_qty,
            "total_cbm": total_cbm,
            "total_gross_weight_kg": total_gross_weight_kg,
            "total_volumetric_weight_kg": round(cargo_math.volumetric_weight_kg(sum_cbm, kg_per_cbm), 2),
            "air_chargeable_weight_kg": round(
                cargo_math.chargeable_weight_kg(total_gross_weight_kg, sum_cbm, kg_per_cbm), 2
            ),
            "recommended_shipping_method": rec.shipping_method,
            "recommended_container_type": rec.container_type,
            "recommended_container_count": rec.container_count,
            "smart_hybrid_containers": _containers_text(hybrid),
            "flat_only_containers": _containers_text(flat),
            "hybrid_savings_count": savings,
            "smart_hybrid_containers_count": hybrid,
            "flat_only_containers_count": flat,
        }
        return computed_items, summary_totals

    @staticmethod
    def quick_calculate(
        request: CBMQuickCalcRequest, kg_per_cbm: float = DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM
    ) -> CBMQuickCalcResponse:
        computed_items, summary = CBMService.compute_items_and_totals(request.items, kg_per_cbm)
        return CBMQuickCalcResponse(**summary, items=computed_items)

    @staticmethod
    def quick_calculate_service(db: Session, request: CBMQuickCalcRequest) -> CBMQuickCalcResponse:
        return CBMService.quick_calculate(request, air_volumetric_kg_per_cbm(db))

    # ── Persistence ─────────────────────────────────────────────────────────────

    @staticmethod
    def _push_to_po(db: Session, calc: CBMCalculation, user: Optional[str]) -> None:
        """CBM totals onto the linked PO through the PO service (version bump + audit user, no commit)."""
        from modules.purchase_orders.service import PurchaseOrderService

        PurchaseOrderService(db).apply_measurements(
            calc.po_id, calc.total_cbm, calc.total_gross_weight_kg, calc.total_qty, user, commit=False
        )

    @staticmethod
    def _commit_and_respond(db: Session, calc: CBMCalculation) -> CBMCalculationResponse:
        db.commit()
        db.refresh(calc)
        return CBMService._to_response(db, calc)

    @staticmethod
    def create_calculation_service(
        db: Session, payload: CBMCalculationCreate, user: Optional[str] = None
    ) -> CBMCalculationResponse:
        CBMValidator.validate_fk_references(
            db, project_id=payload.project_id, po_id=payload.po_id, import_file_id=payload.import_file_id
        )
        computed_items, summary = CBMService.compute_items_and_totals(payload.items, air_volumetric_kg_per_cbm(db))
        calc_data = {
            "title": payload.title,
            "import_file_id": payload.import_file_id,
            "project_id": payload.project_id,
            "po_id": payload.po_id,
            "notes": payload.notes,
            "is_stackable": payload.is_stackable if payload.is_stackable is not None else True,
            "shipment_mode": payload.shipment_mode,
            "created_by": user,
            "updated_by": user,
            **summary,
        }
        calc = CBMRepository.create(db, calc_data, computed_items)
        if calc.po_id:
            CBMService._push_to_po(db, calc, user)
        return CBMService._commit_and_respond(db, calc)

    @staticmethod
    def get_calculation_service(db: Session, calc_id: int) -> CBMCalculationResponse:
        return CBMService._to_response(db, get_or_404(db, CBMCalculation, calc_id, "حساب الحجم"))

    @staticmethod
    def list_calculations_service(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        project_id: Optional[int] = None,
        po_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[CBMCalculationResponse]:
        records = CBMRepository.get_all(
            db,
            include_inactive=include_inactive,
            import_file_id=import_file_id,
            project_id=project_id,
            po_id=po_id,
            search=search,
        )
        if not records:
            return []

        # One query per linked table (no N+1).
        project_ids = {r.project_id for r in records if r.project_id}
        po_ids = {r.po_id for r in records if r.po_id}
        projects_map: Dict[int, str] = {}
        if project_ids:
            prjs = db.query(Project).filter(Project.project_id.in_(project_ids)).all()
            projects_map = {p.project_id: f"{p.project_code} - {p.project_name}" for p in prjs}
        pos_map: Dict[int, str] = {}
        if po_ids:
            pos = db.query(PurchaseOrder).filter(PurchaseOrder.po_id.in_(po_ids)).all()
            pos_map = {p.po_id: p.po_number for p in pos}
        file_codes = codes_by_ids(db, [r.import_file_id for r in records])

        return [
            CBMService._to_response(
                db,
                r,
                project_name=projects_map.get(r.project_id),
                po_number=pos_map.get(r.po_id),
                import_file_code=file_codes.get(r.import_file_id),
            )
            for r in records
        ]

    @staticmethod
    def update_calculation_service(
        db: Session, calc_id: int, payload: CBMCalculationUpdate, user: Optional[str] = None
    ) -> CBMCalculationResponse:
        calc = get_or_404(db, CBMCalculation, calc_id, "حساب الحجم")
        CBMValidator.validate_fk_references(
            db, project_id=payload.project_id, po_id=payload.po_id, import_file_id=payload.import_file_id, stored=calc
        )

        calc_data = {
            name: getattr(payload, name)
            for name in ("title", "import_file_id", "project_id", "po_id", "notes", "is_stackable", "shipment_mode")
            if getattr(payload, name) is not None
        }
        calc_data["updated_by"] = user
        computed_items = None
        if payload.items is not None:
            computed_items, summary = CBMService.compute_items_and_totals(payload.items, air_volumetric_kg_per_cbm(db))
            calc_data.update(summary)

        updated_calc = CBMRepository.update(db, calc, calc_data, computed_items)
        return CBMService._commit_and_respond(db, updated_calc)

    @staticmethod
    def link_to_po_service(
        db: Session,
        calc_id: int,
        po_id: Optional[int] = None,
        project_id: Optional[int] = None,
        user: Optional[str] = None,
        import_file_id: Optional[int] = None,
    ) -> CBMCalculationResponse:
        calc = get_or_404(db, CBMCalculation, calc_id, "حساب الحجم")
        CBMValidator.validate_fk_references(db, project_id=project_id, po_id=po_id, import_file_id=import_file_id)

        calc_data: dict = {"updated_by": user}
        if import_file_id is not None:
            calc_data["import_file_id"] = import_file_id
        if po_id is not None:
            calc_data["po_id"] = po_id
            po = db.get(PurchaseOrder, po_id)
            if po is not None and po.project_id:
                calc_data["project_id"] = po.project_id
        if project_id is not None:
            calc_data["project_id"] = project_id

        updated = CBMRepository.update(db, calc, calc_data)
        if po_id is not None:
            CBMService._push_to_po(db, updated, user)
        return CBMService._commit_and_respond(db, updated)

    @staticmethod
    def soft_delete_service(db: Session, calc_id: int, user: Optional[str] = None) -> dict:
        calc = get_or_404(db, CBMCalculation, calc_id, "حساب الحجم")
        calc.updated_by = user
        CBMRepository.soft_delete(db, calc)
        db.commit()
        return {"message": f"Calculation record '{calc.calc_code}' soft deleted successfully."}

    @staticmethod
    def restore_service(db: Session, calc_id: int, user: Optional[str] = None) -> CBMCalculationResponse:
        calc = get_or_404(db, CBMCalculation, calc_id, "حساب الحجم")
        calc.updated_by = user
        CBMRepository.restore(db, calc)
        return CBMService._commit_and_respond(db, calc)

    @staticmethod
    def clone_cbm_calculation(
        db: Session,
        calc_id: int,
        payload: CloneCBMCalculationRequest,
        user: Optional[str] = None,
    ) -> CBMCalculationResponse:
        calc = get_or_404(db, CBMCalculation, calc_id, "حساب الحجم")

        new_code = (
            payload.new_code.strip()
            if payload.new_code and payload.new_code.strip()
            else CBMRepository.generate_calc_code(db)
        )
        if db.query(CBMCalculation).filter(CBMCalculation.calc_code == new_code).first():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"كود حساب الحجم '{new_code}' مستخدم بالفعل.",
            )

        computed_items: List[dict] = []
        # No items -> no measurements and no recommendation (CBM-06).
        summary: dict = {
            "total_qty": 0,
            "total_cbm": 0.0,
            "total_gross_weight_kg": 0.0,
            "total_volumetric_weight_kg": 0.0,
            "air_chargeable_weight_kg": 0.0,
            "recommended_shipping_method": None,
            "recommended_container_type": None,
            "recommended_container_count": 0,
        }
        if payload.copy_items and calc.items:
            item_objs = [
                CBMItemCreate(
                    package_type=item.package_type,
                    quantity=item.quantity,
                    length=item.length_cm,
                    width=item.width_cm,
                    height=item.height_cm,
                    unit="cm",
                    gross_weight_per_unit_kg=item.gross_weight_per_unit_kg,
                    is_stackable=item.is_stackable,
                )
                for item in calc.items
            ]
            computed_items, summary = CBMService.compute_items_and_totals(item_objs, air_volumetric_kg_per_cbm(db))

        calc_data = {
            "title": payload.new_title or f"Copy of {calc.title or calc.calc_code}",
            "import_file_id": None,  # a clone is a new standalone draft
            "project_id": calc.project_id,
            "po_id": None,
            "notes": payload.notes if payload.notes is not None else calc.notes,
            "is_stackable": calc.is_stackable,
            "shipment_mode": calc.shipment_mode,
            "created_by": user,
            "updated_by": user,
            **summary,
        }
        new_calc = CBMRepository.create(db, calc_data, computed_items, calc_code=new_code)
        return CBMService._commit_and_respond(db, new_calc)

    @staticmethod
    def _to_response(
        db: Session,
        calc: CBMCalculation,
        project_name: Any = _LOOKUP,
        po_number: Any = _LOOKUP,
        import_file_code: Any = _LOOKUP,
    ) -> CBMCalculationResponse:
        if project_name is _LOOKUP:
            prj = db.get(Project, calc.project_id) if calc.project_id else None
            project_name = f"{prj.project_code} - {prj.project_name}" if prj else None
        if po_number is _LOOKUP:
            po = db.get(PurchaseOrder, calc.po_id) if calc.po_id else None
            po_number = po.po_number if po else None
        if import_file_code is _LOOKUP:
            import_file_code = codes_by_ids(db, [calc.import_file_id]).get(calc.import_file_id)

        resp = CBMCalculationResponse.model_validate(calc)
        resp.project_name = project_name
        resp.po_number = po_number
        resp.import_file_code = import_file_code
        # Legacy rows hold bilingual labels: answer codes.
        resp.recommended_shipping_method = _method_code(calc.recommended_shipping_method)
        resp.recommended_container_type = _container_code(calc.recommended_container_type)
        return resp
