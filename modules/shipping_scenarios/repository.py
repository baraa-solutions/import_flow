from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from sqlalchemy import desc, or_
from sqlalchemy.orm import Session, selectinload

from modules.common.sequence_generator import next_yearly_code
from modules.shipping_scenarios.model import (
    ShippingEvaluationSession,
    ShippingScenarioItem,
)
from modules.shipping_scenarios.schemas import (
    SCENARIO_ITEM_FIELDS,
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCreate,
)

# Header fields an update may change (None = not sent / keep the stored value).
SESSION_UPDATE_FIELDS = (
    "title", "cargo_ready_date", "pick_up_address", "port_of_loading_id", "port_of_discharge_id",
    "avg_form4_days", "avg_clearance_days", "import_file_id", "po_id", "project_id", "notes",
)
# Item text fields stored trimmed: required ones stay strings, optional ones become None when blank.
_REQUIRED_TEXT_FIELDS = ("provider_name", "vessel_name")
_OPTIONAL_TEXT_FIELDS = ("customs_broker_name", "voyage_number", "pol_name", "pod_name")


def _item_row(session_id: int, item: ShippingScenarioItemCreate) -> ShippingScenarioItem:
    data = item.model_dump(include=set(SCENARIO_ITEM_FIELDS))
    for name in _REQUIRED_TEXT_FIELDS:
        data[name] = data[name].strip()
    for name in _OPTIONAL_TEXT_FIELDS:
        data[name] = data[name].strip() if data[name] else None
    return ShippingScenarioItem(session_id=session_id, **data)


class ShippingScenarioRepository:
    """
    Database queries & persistence layer for BP-007 Shipping Scenarios Evaluation.
    Writes flush only: the service commits once per public method.
    """

    @staticmethod
    def generate_session_code(db: Session) -> str:
        """SCE-YYYY-NNN, continuing from the highest numeric suffix used this year."""
        return next_yearly_code(db, ShippingEvaluationSession.session_code, "SCE", pad=3)

    @staticmethod
    def create(db: Session, payload: ShippingEvaluationCreate) -> ShippingEvaluationSession:
        session_obj = ShippingEvaluationSession(
            session_code=ShippingScenarioRepository.generate_session_code(db),
            title=payload.title,
            cargo_ready_date=payload.cargo_ready_date,
            pick_up_address=payload.pick_up_address,
            port_of_loading_id=payload.port_of_loading_id,
            port_of_discharge_id=payload.port_of_discharge_id,
            avg_form4_days=payload.avg_form4_days,
            avg_clearance_days=payload.avg_clearance_days,
            import_file_id=payload.import_file_id,
            po_id=payload.po_id,
            project_id=payload.project_id,
            notes=payload.notes,
            is_active=True,
        )
        db.add(session_obj)
        db.flush()
        for item in payload.items:
            db.add(_item_row(session_obj.session_id, item))
        db.flush()
        db.expire(session_obj, ["items"])
        return session_obj

    @staticmethod
    def add_items_copy(db: Session, session_id: int, source_items: List[ShippingScenarioItem]) -> None:
        """Clone: copy every scenario field; the copy is never recommended / selected."""
        for src in source_items:
            data = {f: getattr(src, f) for f in SCENARIO_ITEM_FIELDS}
            data.update(is_recommended=False, is_selected=False)
            db.add(ShippingScenarioItem(session_id=session_id, **data))

    @staticmethod
    def get_by_id(db: Session, session_id: int) -> Optional[ShippingEvaluationSession]:
        return (
            db.query(ShippingEvaluationSession)
            .options(selectinload(ShippingEvaluationSession.items))
            .filter(ShippingEvaluationSession.session_id == session_id)
            .first()
        )

    @staticmethod
    def list_sessions(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        project_id: Optional[int] = None,
        po_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[ShippingEvaluationSession]:
        query = db.query(ShippingEvaluationSession).options(selectinload(ShippingEvaluationSession.items))
        if not include_inactive:
            query = query.filter(ShippingEvaluationSession.is_active.is_(True))
        if import_file_id:
            query = query.filter(ShippingEvaluationSession.import_file_id == import_file_id)
        if project_id:
            query = query.filter(ShippingEvaluationSession.project_id == project_id)
        if po_id:
            query = query.filter(ShippingEvaluationSession.po_id == po_id)
        if search:
            pattern = f"%{search}%"
            query = query.filter(
                or_(
                    ShippingEvaluationSession.session_code.ilike(pattern),
                    ShippingEvaluationSession.title.ilike(pattern),
                    ShippingEvaluationSession.notes.ilike(pattern),
                )
            )
        return query.order_by(desc(ShippingEvaluationSession.session_id)).all()

    @staticmethod
    def update(
        db: Session, session_obj: ShippingEvaluationSession, payload: ShippingEvaluationUpdate
    ) -> ShippingEvaluationSession:
        for name in SESSION_UPDATE_FIELDS:
            value = getattr(payload, name)
            if value is not None:
                setattr(session_obj, name, value)

        if payload.items is not None:
            db.query(ShippingScenarioItem).filter(
                ShippingScenarioItem.session_id == session_obj.session_id
            ).delete()
            for item in payload.items:
                db.add(_item_row(session_obj.session_id, item))

        # An edited and saved study is reactivated unless the client says otherwise.
        session_obj.is_active = payload.is_active if payload.is_active is not None else True
        session_obj.updated_at = datetime.now(timezone.utc)
        db.flush()
        db.expire(session_obj, ["items"])
        return session_obj

    @staticmethod
    def po_and_project_names(
        db: Session, sessions: List[ShippingEvaluationSession]
    ) -> Tuple[Dict[int, str], Dict[int, str]]:
        """(po_id -> po_number, project_id -> project_name) for the sessions, one IN query each."""
        from modules.projects.model import Project
        from modules.purchase_orders.model import PurchaseOrder

        po_ids = {s.po_id for s in sessions if s.po_id}
        project_ids = {s.project_id for s in sessions if s.project_id}
        po_numbers: Dict[int, str] = {}
        project_names: Dict[int, str] = {}
        if po_ids:
            rows = db.query(PurchaseOrder.po_id, PurchaseOrder.po_number).filter(PurchaseOrder.po_id.in_(po_ids))
            po_numbers = {pid: num for pid, num in rows}
        if project_ids:
            rows = db.query(Project.project_id, Project.project_name).filter(Project.project_id.in_(project_ids))
            project_names = {pid: name for pid, name in rows}
        return po_numbers, project_names

    @staticmethod
    def set_file_selected_scenario(db: Session, import_file_id: int, scenario: str) -> None:
        from modules.import_files.model import ImportFile

        imp = db.get(ImportFile, import_file_id)
        if imp:
            imp.selected_scenario = scenario

    @staticmethod
    def soft_delete(db: Session, session_obj: ShippingEvaluationSession) -> None:
        session_obj.is_active = False
        session_obj.updated_at = datetime.now(timezone.utc)
        db.flush()

    @staticmethod
    def restore(db: Session, session_obj: ShippingEvaluationSession) -> ShippingEvaluationSession:
        session_obj.is_active = True
        session_obj.updated_at = datetime.now(timezone.utc)
        db.flush()
        return session_obj
