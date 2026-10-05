from typing import List, Optional
from sqlalchemy import or_
from sqlalchemy.orm import Session, selectinload

from modules.cbm_calculator.model import CBMCalculation, CBMCalculationItem
from modules.common.sequence_generator import next_yearly_code


class CBMRepository:

    @staticmethod
    def generate_calc_code(db: Session) -> str:
        """CALC-YYYY-NNN, continuing from the highest numeric suffix used this year."""
        return next_yearly_code(db, CBMCalculation.calc_code, "CALC", pad=3)

    @staticmethod
    def add_items(db: Session, calc_id: int, items_data: List[dict]) -> None:
        for item_dict in items_data:
            db.add(
                CBMCalculationItem(
                    calc_id=calc_id,
                    package_type=item_dict.get("package_type", "Carton"),
                    quantity=item_dict.get("quantity", 1),
                    length_cm=item_dict.get("length_cm", 0.0),
                    width_cm=item_dict.get("width_cm", 0.0),
                    height_cm=item_dict.get("height_cm", 0.0),
                    gross_weight_per_unit_kg=item_dict.get("gross_weight_per_unit_kg", 0.0),
                    total_cbm=item_dict.get("total_cbm", 0.0),
                    volumetric_weight_kg=item_dict.get("volumetric_weight_kg", 0.0),
                    total_gross_weight_kg=item_dict.get("total_gross_weight_kg", 0.0),
                    is_stackable=item_dict.get("is_stackable", True),
                )
            )

    @staticmethod
    def create(db: Session, calc_data: dict, items_data: list[dict], calc_code: Optional[str] = None) -> CBMCalculation:
        calc_code = calc_code or CBMRepository.generate_calc_code(db)
        calc = CBMCalculation(
            calc_code=calc_code,
            title=calc_data.get("title"),
            import_file_id=calc_data.get("import_file_id"),
            project_id=calc_data.get("project_id"),
            po_id=calc_data.get("po_id"),
            total_qty=calc_data.get("total_qty", 0),
            total_cbm=calc_data.get("total_cbm", 0.0),
            total_gross_weight_kg=calc_data.get("total_gross_weight_kg", 0.0),
            total_volumetric_weight_kg=calc_data.get("total_volumetric_weight_kg", 0.0),
            air_chargeable_weight_kg=calc_data.get("air_chargeable_weight_kg", 0.0),
            recommended_shipping_method=calc_data.get("recommended_shipping_method"),
            recommended_container_type=calc_data.get("recommended_container_type"),
            recommended_container_count=calc_data.get("recommended_container_count", 0),
            notes=calc_data.get("notes"),
            is_stackable=calc_data.get("is_stackable", True),
            shipment_mode=calc_data.get("shipment_mode"),
            created_by=calc_data.get("created_by"),
            updated_by=calc_data.get("updated_by"),
            is_active=True,
        )
        db.add(calc)
        db.flush()

        CBMRepository.add_items(db, calc.calc_id, items_data)
        db.flush()
        db.expire(calc, ["items"])
        return calc

    @staticmethod
    def get_by_id(db: Session, calc_id: int) -> Optional[CBMCalculation]:
        return (
            db.query(CBMCalculation)
            .options(selectinload(CBMCalculation.items))
            .filter(CBMCalculation.calc_id == calc_id)
            .first()
        )

    @staticmethod
    def get_all(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        project_id: Optional[int] = None,
        po_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[CBMCalculation]:
        query = db.query(CBMCalculation).options(selectinload(CBMCalculation.items))

        if not include_inactive:
            query = query.filter(CBMCalculation.is_active.is_(True))

        if import_file_id is not None:
            query = query.filter(CBMCalculation.import_file_id == import_file_id)

        if project_id is not None:
            query = query.filter(CBMCalculation.project_id == project_id)

        if po_id is not None:
            query = query.filter(CBMCalculation.po_id == po_id)

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    CBMCalculation.calc_code.ilike(term),
                    CBMCalculation.title.ilike(term),
                    CBMCalculation.notes.ilike(term),
                    CBMCalculation.recommended_shipping_method.ilike(term),
                )
            )

        return query.order_by(CBMCalculation.calc_id.desc()).all()

    @staticmethod
    def update(db: Session, calc: CBMCalculation, calc_data: dict, items_data: Optional[list[dict]] = None) -> CBMCalculation:
        for key, value in calc_data.items():
            if hasattr(calc, key):
                setattr(calc, key, value)

        if items_data is not None:
            db.query(CBMCalculationItem).filter(CBMCalculationItem.calc_id == calc.calc_id).delete()
            CBMRepository.add_items(db, calc.calc_id, items_data)
        db.flush()
        db.expire(calc, ["items"])
        return calc

    @staticmethod
    def soft_delete(db: Session, calc: CBMCalculation) -> CBMCalculation:
        calc.is_active = False
        db.flush()
        return calc

    @staticmethod
    def restore(db: Session, calc: CBMCalculation) -> CBMCalculation:
        calc.is_active = True
        db.flush()
        return calc
