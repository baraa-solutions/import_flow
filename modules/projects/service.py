from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.projects.model import Project
from modules.projects.repository import ProjectRepository
from modules.projects.schemas import ProjectCreate, ProjectResponse, ProjectUpdate
from modules.projects.validators import ProjectValidator


class ProjectService:

    def __init__(self, db: Session):
        self.db = db
        self.repo = ProjectRepository(db)
        self.validator = ProjectValidator(db)

    def _calculate_commitment_totals(
        self,
        budget_usd: Optional[float],
        po_data: List[tuple],
        currency_service: "CurrencyService",
    ) -> dict:
        po_count = sum(r[2] for r in po_data)
        committed_by_currency: dict[str, float] = {}
        for cur_code, amt, _ in po_data:
            code = (cur_code or "").upper().strip()
            if code:
                committed_by_currency[code] = round(committed_by_currency.get(code, 0.0) + amt, 2)

        if po_count == 0 or not committed_by_currency:
            rem = round(budget_usd, 2) if budget_usd is not None else None
            return {
                "total_committed_usd": 0.0,
                "remaining_budget_usd": rem,
                "budget_utilization_percent": 0.0,
                "po_count": 0,
                "missing_rate_currencies": [],
                "committed_by_currency": {},
            }

        missing_rate_currencies: List[str] = []
        has_non_usd = any(cur != "USD" for cur in committed_by_currency.keys())

        usd_rate_to_egp = None
        if has_non_usd:
            try:
                rate_val, _, _ = currency_service._get_rate_to_egp("USD", rate_type="commercial")
                usd_rate_to_egp = float(rate_val)
            except HTTPException:
                if "USD" not in missing_rate_currencies:
                    missing_rate_currencies.append("USD")
            except Exception:
                if "USD" not in missing_rate_currencies:
                    missing_rate_currencies.append("USD")

        converted_amounts_usd: List[float] = []

        for cur_code, cur_amount in committed_by_currency.items():
            if cur_code == "USD":
                converted_amounts_usd.append(cur_amount)
            else:
                try:
                    rate_val, _, _ = currency_service._get_rate_to_egp(cur_code, rate_type="commercial")
                    cur_rate_to_egp = float(rate_val)
                    if usd_rate_to_egp is not None and usd_rate_to_egp > 0:
                        converted_amounts_usd.append(cur_amount * cur_rate_to_egp / usd_rate_to_egp)
                except HTTPException:
                    if cur_code not in missing_rate_currencies:
                        missing_rate_currencies.append(cur_code)
                except Exception:
                    if cur_code not in missing_rate_currencies:
                        missing_rate_currencies.append(cur_code)

        missing_rate_currencies.sort()

        if missing_rate_currencies:
            return {
                "total_committed_usd": None,
                "remaining_budget_usd": None,
                "budget_utilization_percent": None,
                "po_count": po_count,
                "missing_rate_currencies": missing_rate_currencies,
                "committed_by_currency": committed_by_currency,
            }

        total_committed_usd = round(sum(converted_amounts_usd), 2)
        remaining_budget_usd = None
        budget_utilization_percent = 0.0

        if budget_usd is not None:
            remaining_budget_usd = round(budget_usd - total_committed_usd, 2)
            if budget_usd > 0:
                budget_utilization_percent = round((total_committed_usd / budget_usd) * 100.0, 1)

        return {
            "total_committed_usd": total_committed_usd,
            "remaining_budget_usd": remaining_budget_usd,
            "budget_utilization_percent": budget_utilization_percent,
            "po_count": po_count,
            "missing_rate_currencies": [],
            "committed_by_currency": committed_by_currency,
        }

    def _to_response(
        self,
        project: Project,
        company_names_str: Optional[str] = None,
        company_ids: Optional[List[int]] = None,
        stats: Optional[dict] = None,
    ) -> ProjectResponse:
        if company_ids is None:
            company_ids = [project.company_id]
            if project.additional_company_ids:
                try:
                    extra_ids = [int(x.strip()) for x in project.additional_company_ids.split(",") if x.strip().isdigit()]
                    company_ids.extend(extra_ids)
                except Exception:
                    pass

        if company_names_str is None:
            company_names = []
            if company_ids:
                from modules.import_companies.model import ImportCompany
                companies = self.db.query(ImportCompany).filter(ImportCompany.company_id.in_(company_ids)).all()
                comp_map = {c.company_id: c.importer_name for c in companies}
                company_names = [comp_map[cid] for cid in company_ids if cid in comp_map]
            company_names_str = ", ".join(company_names) if company_names else (project.company.importer_name if project.company else None)

        if stats is None:
            from modules.purchase_orders.model import PurchaseOrder
            from modules.currencies.model import Currency
            from modules.currencies.service import CurrencyService
            from sqlalchemy import func

            po_rows = (
                self.db.query(
                    Currency.currency_code,
                    func.coalesce(func.sum(PurchaseOrder.total_amount_fob), 0.0),
                    func.count(PurchaseOrder.po_id),
                )
                .join(Currency, PurchaseOrder.currency_id == Currency.currency_id)
                .filter(
                    PurchaseOrder.project_id == project.project_id,
                    PurchaseOrder.is_active.is_(True),
                )
                .group_by(Currency.currency_code)
                .all()
            )
            po_data = [(cur_code, float(amt), int(cnt)) for cur_code, amt, cnt in po_rows]
            currency_service = CurrencyService(self.db)
            budget = float(project.total_budget_usd) if project.total_budget_usd is not None else None
            stats = self._calculate_commitment_totals(budget, po_data, currency_service)

        return ProjectResponse(
            project_id=project.project_id,
            project_code=project.project_code,
            project_name=project.project_name,
            project_owner=project.project_owner,
            company_id=project.company_id,
            company_ids=company_ids,
            supplier_id=project.supplier_id,
            incoterm_id=project.incoterm_id,
            import_type=project.import_type,
            priority=project.priority,
            shipment_category=project.shipment_category,
            allow_multi_shipment=project.allow_multi_shipment,
            allow_multi_company=project.allow_multi_company,
            total_budget_usd=float(project.total_budget_usd) if project.total_budget_usd is not None else None,
            target_end_date=project.target_end_date,
            status=project.status,
            notes=project.notes,
            is_active=project.is_active,
            created_at=project.created_at,
            updated_at=project.updated_at,
            company_name=company_names_str,
            supplier_name=project.supplier.company_name if project.supplier else None,
            incoterm_code=project.incoterm.incoterm_code if project.incoterm else None,
            total_committed_usd=stats["total_committed_usd"],
            po_count=stats["po_count"],
            remaining_budget_usd=stats["remaining_budget_usd"],
            budget_utilization_percent=stats["budget_utilization_percent"],
            missing_rate_currencies=stats["missing_rate_currencies"],
            committed_by_currency=stats["committed_by_currency"],
        )

    def get_financial_commitments(self, project_id: int) -> dict:
        project = self.repo.get_by_id(project_id)
        if not project:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Project with ID {project_id} not found.",
            )
        from modules.purchase_orders.model import PurchaseOrder
        from modules.currencies.model import Currency
        from modules.currencies.service import CurrencyService

        pos = (
            self.db.query(PurchaseOrder, Currency.currency_code)
            .join(Currency, PurchaseOrder.currency_id == Currency.currency_id)
            .filter(
                PurchaseOrder.project_id == project_id,
                PurchaseOrder.is_active.is_(True),
            )
            .all()
        )

        po_data = [(cur_code, float(p.total_amount_fob or 0.0), 1) for p, cur_code in pos]
        currency_service = CurrencyService(self.db)
        budget = float(project.total_budget_usd) if project.total_budget_usd is not None else None
        stats = self._calculate_commitment_totals(budget, po_data, currency_service)

        total_cbm = sum(float(p.total_cbm or 0.0) for p, _ in pos)
        total_gross_wt = sum(float(p.total_gross_weight_kg or 0.0) for p, _ in pos)

        return {
            "project_id": project.project_id,
            "project_code": project.project_code,
            "project_name": project.project_name,
            "total_budget_usd": budget,
            "total_committed_usd": stats["total_committed_usd"],
            "remaining_budget_usd": stats["remaining_budget_usd"],
            "budget_utilization_percent": stats["budget_utilization_percent"],
            "missing_rate_currencies": stats["missing_rate_currencies"],
            "committed_by_currency": stats["committed_by_currency"],
            "po_count": stats["po_count"],
            "total_cbm": round(total_cbm, 4),
            "total_gross_weight_kg": round(total_gross_wt, 2),
            "purchase_orders": [
                {
                    "po_id": p.po_id,
                    "po_number": p.po_number,
                    "po_reference": p.po_reference,
                    "status": p.status,
                    "total_amount_fob": float(p.total_amount_fob),
                    "total_cbm": float(p.total_cbm),
                    "total_gross_weight_kg": float(p.total_gross_weight_kg),
                    "import_file_id": p.import_file_id,
                    "order_date": p.order_date.isoformat() if p.order_date else None,
                }
                for p, _ in pos
            ],
        }

    def get_all(
        self,
        include_inactive: bool = False,
        status_filter: Optional[str] = None,
        company_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[ProjectResponse]:
        projects = self.repo.get_all(
            include_inactive=include_inactive,
            status_filter=status_filter,
            company_id=company_id,
            supplier_id=supplier_id,
            search=search,
        )
        if not projects:
            return []

        project_ids = [p.project_id for p in projects]

        # 1. Batch query companies
        all_company_ids = set()
        for p in projects:
            if p.company_id:
                all_company_ids.add(p.company_id)
            if p.additional_company_ids:
                try:
                    extra_ids = [int(x.strip()) for x in p.additional_company_ids.split(",") if x.strip().isdigit()]
                    all_company_ids.update(extra_ids)
                except Exception:
                    pass

        company_map = {}
        if all_company_ids:
            from modules.import_companies.model import ImportCompany
            companies = self.db.query(ImportCompany).filter(ImportCompany.company_id.in_(all_company_ids)).all()
            company_map = {c.company_id: c.importer_name for c in companies}

        # 2. Batch query POs grouped by project and currency
        from modules.purchase_orders.model import PurchaseOrder
        from modules.currencies.model import Currency
        from sqlalchemy import func

        po_rows = (
            self.db.query(
                PurchaseOrder.project_id,
                Currency.currency_code,
                func.coalesce(func.sum(PurchaseOrder.total_amount_fob), 0.0),
                func.count(PurchaseOrder.po_id),
            )
            .join(Currency, PurchaseOrder.currency_id == Currency.currency_id)
            .filter(
                PurchaseOrder.project_id.in_(project_ids),
                PurchaseOrder.is_active.is_(True),
            )
            .group_by(PurchaseOrder.project_id, Currency.currency_code)
            .all()
        )

        po_by_project: dict[int, list[tuple]] = {pid: [] for pid in project_ids}
        for pid, cur_code, amt, cnt in po_rows:
            po_by_project[pid].append((cur_code, float(amt), int(cnt)))

        from modules.currencies.service import CurrencyService
        currency_service = CurrencyService(self.db)

        # 3. Build response for each project
        results = []
        for p in projects:
            c_ids = [p.company_id]
            if p.additional_company_ids:
                try:
                    extra_ids = [int(x.strip()) for x in p.additional_company_ids.split(",") if x.strip().isdigit()]
                    c_ids.extend(extra_ids)
                except Exception:
                    pass
            c_names = [company_map[cid] for cid in c_ids if cid in company_map]
            c_names_str = ", ".join(c_names) if c_names else (p.company.importer_name if p.company else None)

            budget = float(p.total_budget_usd) if p.total_budget_usd is not None else None
            p_stats = self._calculate_commitment_totals(budget, po_by_project.get(p.project_id, []), currency_service)

            results.append(self._to_response(p, company_names_str=c_names_str, company_ids=c_ids, stats=p_stats))

        return results

    def get_by_id(self, project_id: int) -> ProjectResponse:
        project = self.repo.get_by_id(project_id)
        if not project:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Project with ID {project_id} not found.",
            )
        return self._to_response(project)

    def create(self, data: ProjectCreate) -> ProjectResponse:
        if data.project_code:
            self.validator.validate_unique_code(data.project_code)
        self.validator.validate_foreign_keys(data.company_id, data.supplier_id, data.incoterm_id)
        project = self.repo.create(data)
        return self._to_response(project)

    def update(self, project_id: int, data: ProjectUpdate) -> ProjectResponse:
        project = self.repo.get_by_id(project_id)
        if not project:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Project with ID {project_id} not found.",
            )

        if data.company_id or data.supplier_id or data.incoterm_id:
            c_id = data.company_id or project.company_id
            s_id = data.supplier_id or project.supplier_id
            i_id = data.incoterm_id or project.incoterm_id
            self.validator.validate_foreign_keys(c_id, s_id, i_id)

        updated = self.repo.update(project, data)
        return self._to_response(updated)

    def soft_delete(self, project_id: int) -> ProjectResponse:
        project = self.repo.get_by_id(project_id)
        if not project:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Project with ID {project_id} not found.",
            )
        deleted = self.repo.soft_delete(project)
        return self._to_response(deleted)

    def restore(self, project_id: int) -> ProjectResponse:
        project = self.repo.get_by_id(project_id)
        if not project:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Project with ID {project_id} not found.",
            )
        restored = self.repo.restore(project)
        return self._to_response(restored)
