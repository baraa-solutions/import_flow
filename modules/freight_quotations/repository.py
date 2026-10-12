"""
Freight Quotations Repository Layer (BP-008)
"""

from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.freight_quotations.schemas import FreightRFQRequestCreate, FreightRFQRequestUpdate


class FreightQuotationRepository:

    @staticmethod
    def generate_rfq_code(db: Session) -> str:
        """
        Generates auto-incremented RFQ code in format RFQ-YYYY-XXX (e.g. RFQ-2026-001).
        """
        current_year = datetime.now(timezone.utc).year
        prefix = f"RFQ-{current_year}-"

        last_rfq = (
            db.query(FreightRFQRequest)
            .filter(FreightRFQRequest.rfq_code.like(f"{prefix}%"))
            .order_by(FreightRFQRequest.rfq_id.desc())
            .first()
        )

        if last_rfq:
            try:
                last_num = int(last_rfq.rfq_code.split("-")[-1])
                new_num = last_num + 1
            except ValueError:
                new_num = 1
        else:
            new_num = 1

        return f"{prefix}{new_num:03d}"

    @staticmethod
    def create(db: Session, rfq_in: FreightRFQRequestCreate) -> FreightRFQRequest:
        code = FreightQuotationRepository.generate_rfq_code(db)

        db_rfq = FreightRFQRequest(
            rfq_code=code,
            title=rfq_in.title,
            shipping_method=rfq_in.shipping_method,
            crd_date=rfq_in.crd_date,
            pol_id=rfq_in.pol_id,
            pol_name=rfq_in.pol_name,
            pod_id=rfq_in.pod_id,
            pod_name=rfq_in.pod_name,
            import_file_id=rfq_in.import_file_id,
            po_id=rfq_in.po_id,
            project_id=rfq_in.project_id,
            total_cbm=rfq_in.total_cbm,
            total_gross_weight_kg=rfq_in.total_gross_weight_kg,
            chargeable_weight_kg=rfq_in.chargeable_weight_kg,
            status="Draft",
            selected_quotation_id=None,
            notes=rfq_in.notes,
            is_active=True,
        )

        db.add(db_rfq)
        db.flush()

        for q_in in rfq_in.quotations:
            tot_cost = q_in.ocean_freight_cost + q_in.local_charges_cost + q_in.inland_cost
            t_days = (q_in.estimated_arrival_date - q_in.sailing_date).days

            db_quote = FreightQuotationItem(
                rfq_id=db_rfq.rfq_id,
                provider_id=q_in.provider_id,
                provider_name=q_in.provider_name,
                vessel_name=q_in.vessel_name,
                voyage_number=q_in.voyage_number,
                currency_code=q_in.currency_code,
                ocean_freight_cost=q_in.ocean_freight_cost,
                local_charges_cost=q_in.local_charges_cost,
                inland_cost=q_in.inland_cost,
                total_cost=tot_cost,
                sailing_date=q_in.sailing_date,
                estimated_arrival_date=q_in.estimated_arrival_date,
                transit_days=t_days,
                free_days_at_pod=q_in.free_days_at_pod,
                is_awarded=False,
                is_excluded_from_avg=q_in.is_excluded_from_avg,
                remarks=q_in.remarks,
            )
            db.add(db_quote)

        db.flush()
        return db_rfq

    @staticmethod
    def get_by_id(db: Session, rfq_id: int) -> Optional[FreightRFQRequest]:
        return db.query(FreightRFQRequest).filter(FreightRFQRequest.rfq_id == rfq_id).first()

    @staticmethod
    def get_all(
        db: Session,
        include_inactive: bool = False,
        search: Optional[str] = None,
        shipping_method: Optional[str] = None,
        import_file_id: Optional[int] = None,
        po_id: Optional[int] = None,
        project_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> List[FreightRFQRequest]:
        query = db.query(FreightRFQRequest)

        if not include_inactive:
            query = query.filter(FreightRFQRequest.is_active == True)

        if shipping_method:
            query = query.filter(FreightRFQRequest.shipping_method == shipping_method)

        if import_file_id:
            query = query.filter(FreightRFQRequest.import_file_id == import_file_id)

        if po_id:
            query = query.filter(FreightRFQRequest.po_id == po_id)

        if project_id:
            query = query.filter(FreightRFQRequest.project_id == project_id)

        if status:
            query = query.filter(FreightRFQRequest.status == status)

        if search:
            pattern = f"%{search}%"
            query = query.filter(
                (FreightRFQRequest.rfq_code.ilike(pattern))
                | (FreightRFQRequest.title.ilike(pattern))
                | (FreightRFQRequest.pol_name.ilike(pattern))
                | (FreightRFQRequest.pod_name.ilike(pattern))
            )

        return query.order_by(FreightRFQRequest.rfq_id.desc()).all()

    @staticmethod
    def update(
        db: Session, db_rfq: FreightRFQRequest, update_in: FreightRFQRequestUpdate
    ) -> FreightRFQRequest:
        update_data = update_in.model_dump(exclude_unset=True, exclude={"quotations"})

        for field, val in update_data.items():
            setattr(db_rfq, field, val)

        if update_in.quotations is not None:
            existing_quotes = {q.quotation_id: q for q in list(db_rfq.quotations)}
            payload_quote_ids = set()

            for q_in in update_in.quotations:
                tot_cost = q_in.ocean_freight_cost + q_in.local_charges_cost + q_in.inland_cost
                t_days = (q_in.estimated_arrival_date - q_in.sailing_date).days

                if q_in.quotation_id and q_in.quotation_id in existing_quotes:
                    q_obj = existing_quotes[q_in.quotation_id]
                    payload_quote_ids.add(q_in.quotation_id)
                    q_obj.provider_id = q_in.provider_id
                    q_obj.provider_name = q_in.provider_name
                    q_obj.vessel_name = q_in.vessel_name
                    q_obj.voyage_number = q_in.voyage_number
                    q_obj.currency_code = q_in.currency_code
                    q_obj.ocean_freight_cost = q_in.ocean_freight_cost
                    q_obj.local_charges_cost = q_in.local_charges_cost
                    q_obj.inland_cost = q_in.inland_cost
                    q_obj.total_cost = tot_cost
                    q_obj.sailing_date = q_in.sailing_date
                    q_obj.estimated_arrival_date = q_in.estimated_arrival_date
                    q_obj.transit_days = t_days
                    q_obj.free_days_at_pod = q_in.free_days_at_pod
                    q_obj.is_excluded_from_avg = q_in.is_excluded_from_avg
                    q_obj.remarks = q_in.remarks
                else:
                    new_quote = FreightQuotationItem(
                        rfq_id=db_rfq.rfq_id,
                        provider_id=q_in.provider_id,
                        provider_name=q_in.provider_name,
                        vessel_name=q_in.vessel_name,
                        voyage_number=q_in.voyage_number,
                        currency_code=q_in.currency_code,
                        ocean_freight_cost=q_in.ocean_freight_cost,
                        local_charges_cost=q_in.local_charges_cost,
                        inland_cost=q_in.inland_cost,
                        total_cost=tot_cost,
                        sailing_date=q_in.sailing_date,
                        estimated_arrival_date=q_in.estimated_arrival_date,
                        transit_days=t_days,
                        free_days_at_pod=q_in.free_days_at_pod,
                        is_awarded=False,
                        is_excluded_from_avg=q_in.is_excluded_from_avg,
                        remarks=q_in.remarks,
                    )
                    db.add(new_quote)

            for q_id, q_obj in existing_quotes.items():
                if q_id not in payload_quote_ids:
                    db.delete(q_obj)

        db_rfq.updated_at = datetime.now(timezone.utc)
        db.flush()
        return db_rfq

    @staticmethod
    def soft_delete(db: Session, db_rfq: FreightRFQRequest) -> FreightRFQRequest:
        db_rfq.is_active = False
        db_rfq.updated_at = datetime.now(timezone.utc)
        db.flush()
        return db_rfq

    @staticmethod
    def restore(db: Session, db_rfq: FreightRFQRequest) -> FreightRFQRequest:
        db_rfq.is_active = True
        db_rfq.updated_at = datetime.now(timezone.utc)
        db.flush()
        return db_rfq
