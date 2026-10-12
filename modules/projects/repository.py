from datetime import datetime
from typing import List, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from modules.common.sequence_generator import next_yearly_code
from modules.projects.model import Project
from modules.projects.schemas import ProjectCreate, ProjectUpdate


class ProjectRepository:

    def __init__(self, db: Session):
        self.db = db

    def generate_project_code(self, year: Optional[int] = None) -> str:
        return next_yearly_code(self.db, Project.project_code, "PRJ", pad=3, year=year)

    def get_by_id(self, project_id: int) -> Optional[Project]:
        return self.db.query(Project).filter(Project.project_id == project_id).first()

    def get_by_code(self, project_code: str) -> Optional[Project]:
        return self.db.query(Project).filter(Project.project_code == project_code.upper().strip()).first()

    def get_all(
        self,
        include_inactive: bool = False,
        status_filter: Optional[str] = None,
        company_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[Project]:
        query = self.db.query(Project)

        if not include_inactive:
            query = query.filter(Project.is_active.is_(True))

        if status_filter:
            query = query.filter(Project.status == status_filter)

        if company_id:
            query = query.filter(Project.company_id == company_id)

        if supplier_id:
            query = query.filter(Project.supplier_id == supplier_id)

        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    Project.project_code.ilike(pattern),
                    Project.project_name.ilike(pattern),
                    Project.project_owner.ilike(pattern),
                )
            )

        return query.order_by(Project.created_at.desc()).all()

    def create(self, data: ProjectCreate) -> Project:
        explicit_code = bool(data.project_code and data.project_code.strip())

        primary_cid = data.company_id
        add_cids_str = None
        if data.company_ids and len(data.company_ids) > 0:
            primary_cid = data.company_ids[0]
            if len(data.company_ids) > 1:
                add_cids_str = ",".join(str(cid) for cid in data.company_ids[1:])

        for attempt in range(3):
            code = data.project_code.upper().strip() if explicit_code else self.generate_project_code()

            project = Project(
                project_code=code,
                project_name=data.project_name.strip(),
                project_owner=data.project_owner.strip(),
                company_id=primary_cid,
                additional_company_ids=add_cids_str,
                supplier_id=data.supplier_id,
                incoterm_id=data.incoterm_id,
                import_type=data.import_type.strip(),
                priority=data.priority.strip(),
                shipment_category=data.shipment_category.strip(),
                allow_multi_shipment=data.allow_multi_shipment,
                allow_multi_company=data.allow_multi_company,
                total_budget_usd=data.total_budget_usd,
                target_end_date=data.target_end_date.strip() if data.target_end_date else None,
                status="Open",
                notes=data.notes.strip() if data.notes else None,
                is_active=True,
            )
            self.db.add(project)
            try:
                self.db.commit()
                self.db.refresh(project)
                return project
            except IntegrityError:
                self.db.rollback()
                if attempt == 2 or explicit_code:
                    raise

    def update(self, project: Project, data: ProjectUpdate) -> Project:
        update_data = data.model_dump(exclude_unset=True)

        if "company_ids" in update_data and update_data["company_ids"]:
            cids = update_data.pop("company_ids")
            if cids and len(cids) > 0:
                project.company_id = cids[0]
                project.additional_company_ids = ",".join(str(cid) for cid in cids[1:]) if len(cids) > 1 else None

        for field, value in update_data.items():
            if value is not None and isinstance(value, str):
                value = value.strip()
            setattr(project, field, value)

        self.db.commit()
        self.db.refresh(project)
        return project

    def soft_delete(self, project: Project) -> Project:
        project.is_active = False
        self.db.commit()
        self.db.refresh(project)
        return project

    def restore(self, project: Project) -> Project:
        project.is_active = True
        self.db.commit()
        self.db.refresh(project)
        return project
