"""
Freight Quotations Calculation & Business Service Engine (BP-008)
"""

from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightRFQRequestUpdate,
    FreightRFQRequestResponse,
    RankedForwarderQuote,
    RFQBenchmarkResponse,
)
from modules.freight_quotations.repository import FreightQuotationRepository
from modules.freight_quotations.validators import (
    validate_carrier_exists,
    validate_quotation_dates,
    validate_import_file_exists,
    validate_po_exists,
    validate_project_exists,
)
from modules.common.validators import get_or_404, not_null_columns
from modules.import_files.repository import codes_by_ids


class FreightQuotationService:

    @staticmethod
    def _compute_rfq_metrics(
        db: Session,
        db_rfq: FreightRFQRequest,
        import_file_code: Optional[str] = None,
    ) -> FreightRFQRequestResponse:
        """
        Calculates summary metrics: lowest freight cost, avg freight cost, fastest transit days, avg transit days, awarded provider name.
        Pure read computation: never mutates quotation or RFQ state.
        """
        quotes = db_rfq.quotations or []
        total_count = len(quotes)

        included_quotes = [q for q in quotes if not q.is_excluded_from_avg]

        lowest_cost = 0.0
        avg_cost = 0.0
        fastest_transit = 0
        avg_transit = 0.0
        awarded_name: Optional[str] = None

        if quotes:
            costs = [q.total_cost for q in quotes]
            lowest_cost = round(min(costs), 2)

            if db_rfq.selected_quotation_id:
                for q in quotes:
                    if q.quotation_id == db_rfq.selected_quotation_id:
                        awarded_name = q.provider_name
                        break

        if included_quotes:
            inc_costs = [q.total_cost for q in included_quotes]
            avg_cost = round(sum(inc_costs) / len(inc_costs), 2)

            transits = [q.transit_days for q in included_quotes]
            fastest_transit = min(transits)
            avg_transit = round(sum(transits) / len(transits), 1)

        if import_file_code is None and db_rfq.import_file_id:
            import_file_code = codes_by_ids(db, [db_rfq.import_file_id]).get(db_rfq.import_file_id)

        res = FreightRFQRequestResponse.model_validate(db_rfq)
        res.total_quotations_count = total_count
        res.lowest_freight_cost = lowest_cost
        res.average_freight_cost = avg_cost
        res.fastest_transit_days = fastest_transit
        res.average_transit_days = avg_transit
        res.awarded_provider_name = awarded_name
        res.import_file_code = import_file_code
        return res

    @staticmethod
    def create_rfq(db: Session, rfq_in: FreightRFQRequestCreate) -> FreightRFQRequestResponse:
        if rfq_in.import_file_id:
            validate_import_file_exists(db, rfq_in.import_file_id)
        if rfq_in.po_id:
            validate_po_exists(db, rfq_in.po_id)
        if rfq_in.project_id:
            validate_project_exists(db, rfq_in.project_id)

        for q in rfq_in.quotations:
            validate_carrier_exists(db, q.provider_id)
            validate_quotation_dates(rfq_in.crd_date, q.sailing_date, q.estimated_arrival_date)

        for attempt in range(1, 4):
            code = FreightQuotationRepository.generate_rfq_code(db)
            try:
                db_rfq = FreightQuotationRepository.create(db, rfq_in, code=code)  # flush only
                db.commit()
                db.refresh(db_rfq)
                return FreightQuotationService._compute_rfq_metrics(db, db_rfq)
            except IntegrityError:
                db.rollback()
                if not FreightQuotationRepository.get_by_code(db, code):
                    raise
                if attempt == 3:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail=f"كود طلب عروض الأسعار '{code}' مستخدم بالفعل، يرجى إعادة المحاولة.",
                    )
                continue
        raise AssertionError("unreachable")  # pragma: no cover

    @staticmethod
    def get_rfq(db: Session, rfq_id: int) -> FreightRFQRequestResponse:
        db_rfq = get_or_404(db, FreightRFQRequest, rfq_id, "طلب عروض الأسعار")
        return FreightQuotationService._compute_rfq_metrics(db, db_rfq)

    @staticmethod
    def list_rfqs(
        db: Session,
        include_inactive: bool = False,
        search: Optional[str] = None,
        shipping_method: Optional[str] = None,
        import_file_id: Optional[int] = None,
        po_id: Optional[int] = None,
        project_id: Optional[int] = None,
        status: Optional[str] = None,
    ) -> List[FreightRFQRequestResponse]:
        rfqs = FreightQuotationRepository.get_all(
            db,
            include_inactive=include_inactive,
            search=search,
            shipping_method=shipping_method,
            import_file_id=import_file_id,
            po_id=po_id,
            project_id=project_id,
            status=status,
        )
        file_ids = [r.import_file_id for r in rfqs if r.import_file_id]
        codes_map = codes_by_ids(db, file_ids) if file_ids else {}
        return [
            FreightQuotationService._compute_rfq_metrics(
                db, r, import_file_code=codes_map.get(r.import_file_id)
            )
            for r in rfqs
        ]

    @staticmethod
    def update_rfq(
        db: Session, rfq_id: int, update_in: FreightRFQRequestUpdate
    ) -> FreightRFQRequestResponse:
        db_rfq = get_or_404(db, FreightRFQRequest, rfq_id, "طلب عروض الأسعار")

        data = update_in.model_dump(exclude_unset=True)
        protected = not_null_columns(FreightRFQRequest)
        cleared = sorted(name for name, val in data.items() if val is None and name in protected)
        if cleared:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"لا يمكن مسح الحقول الإلزامية: {', '.join(cleared)}",
            )

        if update_in.import_file_id:
            validate_import_file_exists(db, update_in.import_file_id)
        if update_in.po_id:
            validate_po_exists(db, update_in.po_id)
        if update_in.project_id:
            validate_project_exists(db, update_in.project_id)

        crd = update_in.crd_date or db_rfq.crd_date
        if update_in.quotations is not None:
            sent_ids = [q.quotation_id for q in update_in.quotations if q.quotation_id is not None]
            if len(sent_ids) != len(set(sent_ids)):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="يوجد تكرار في معرفات عروض الأسعار في الطلب.",
                )

            if db_rfq.selected_quotation_id and db_rfq.selected_quotation_id not in sent_ids:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="لا يمكن حذف العرض المعتمد.",
                )

            existing_ids = {q.quotation_id for q in db_rfq.quotations}
            for q in update_in.quotations:
                if q.quotation_id is not None and q.quotation_id not in existing_ids:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"عرض السعر رقم {q.quotation_id} غير تابع لطلب عروض الأسعار.",
                    )
                validate_carrier_exists(db, q.provider_id)
                validate_quotation_dates(crd, q.sailing_date, q.estimated_arrival_date)

        updated_rfq = FreightQuotationRepository.update(db, db_rfq, update_in)
        db.commit()
        db.refresh(updated_rfq)
        return FreightQuotationService._compute_rfq_metrics(db, updated_rfq)

    @staticmethod
    def award_quotation(db: Session, rfq_id: int, quotation_id: int) -> FreightRFQRequestResponse:
        """
        Awards a specific carrier quotation, freezes choice, and updates RFQ status to 'Awarded'.
        Also bidirectionally synchronizes the awarded scenario with the linked ImportFile.
        """
        db_rfq = get_or_404(db, FreightRFQRequest, rfq_id, "طلب عروض الأسعار", active_only=True)

        if db_rfq.status == "Cancelled":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="لا يمكن اعتماد عرض سعر لطلب عروض أسعار ملغي (Cancelled).",
            )

        found_quote = None
        for q in db_rfq.quotations:
            if q.quotation_id == quotation_id:
                q.is_awarded = True
                found_quote = q
            else:
                q.is_awarded = False

        if not found_quote:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Quotation item with ID '{quotation_id}' not found in RFQ '{rfq_id}'.",
            )

        db_rfq.selected_quotation_id = quotation_id
        db_rfq.status = "Awarded"
        db_rfq.updated_at = datetime.now(timezone.utc)

        # Bidirectional sync with linked ImportFile
        if db_rfq.import_file_id:
            from modules.import_files.model import ImportFile
            imp = db.query(ImportFile).filter(
                ImportFile.import_file_id == db_rfq.import_file_id
            ).first()
            if imp:
                imp.selected_scenario = f"{found_quote.provider_name} ({db_rfq.rfq_code})"
                if found_quote.free_days_at_pod:
                    imp.target_free_days = found_quote.free_days_at_pod
                if db_rfq.pol_name:
                    imp.port_of_loading = db_rfq.pol_name
                if db_rfq.pod_name:
                    imp.port_of_discharge = db_rfq.pod_name
                if db_rfq.crd_date:
                    imp.cargo_ready_date = db_rfq.crd_date

        db.commit()
        db.refresh(db_rfq)
        return FreightQuotationService._compute_rfq_metrics(db, db_rfq)

    @staticmethod
    def soft_delete_rfq(db: Session, rfq_id: int) -> FreightRFQRequestResponse:
        db_rfq = get_or_404(db, FreightRFQRequest, rfq_id, "طلب عروض الأسعار")
        deleted_rfq = FreightQuotationRepository.soft_delete(db, db_rfq)
        db.commit()
        db.refresh(deleted_rfq)
        return FreightQuotationService._compute_rfq_metrics(db, deleted_rfq)

    @staticmethod
    def restore_rfq(db: Session, rfq_id: int) -> FreightRFQRequestResponse:
        db_rfq = get_or_404(db, FreightRFQRequest, rfq_id, "طلب عروض الأسعار")
        restored_rfq = FreightQuotationRepository.restore(db, db_rfq)
        db.commit()
        db.refresh(restored_rfq)
        return FreightQuotationService._compute_rfq_metrics(db, restored_rfq)

    @staticmethod
    def evaluate_and_rank_rfq_quotes(db: Session, rfq_id: int) -> RFQBenchmarkResponse:
        """
        AI-BENCH-007: Multi-Factor Weighted Scoring & Ranking Engine for Competing Freight Quotes.
        Weights: Cost (50%), Free Days (25%), Transit Time (15%), Partner Reliability (10%).
        """
        db_rfq = get_or_404(db, FreightRFQRequest, rfq_id, "طلب عروض الأسعار")

        quotes = db_rfq.quotations or []
        if not quotes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="لا توجد عروض أسعار مسجلة في هذا الطلب لإجراء المقارنة والمفاضلة.",
            )

        costs = [q.total_cost for q in quotes]
        transits = [q.transit_days for q in quotes]
        free_days_list = [q.free_days_at_pod for q in quotes]

        min_cost = min(costs)
        max_cost = max(costs)
        avg_cost = sum(costs) / len(costs)

        min_transit = min(transits)
        max_transit = max(transits)

        scored_quotes = []

        for q in quotes:
            # 1. Cost Score (50 points max)
            if max_cost == min_cost:
                cost_score = 50.0
            else:
                cost_score = 50.0 * (1.0 - (q.total_cost - min_cost) / (max_cost - min_cost))

            # 2. Free Days Score (25 points max, baseline 14 days, max 28 days)
            free_days_score = 25.0 * (min(28, max(0, q.free_days_at_pod)) / 28.0)

            # 3. Transit Score (15 points max)
            if max_transit == min_transit:
                transit_score = 15.0
            else:
                transit_score = 15.0 * (1.0 - (q.transit_days - min_transit) / (max_transit - min_transit))

            # 4. Partner Reliability (10 points)
            partner_score = 10.0 if q.is_awarded else 8.5

            cost_score = round(cost_score, 1)
            free_days_score = round(free_days_score, 1)
            transit_score = round(transit_score, 1)
            partner_score = round(partner_score, 1)
            composite_score = round(cost_score + free_days_score + transit_score + partner_score, 1)
            cost_saving = round(avg_cost - q.total_cost, 2)

            # Key Advantages
            advantages = []
            if q.total_cost == min_cost:
                advantages.append("أقل سعر إجمالي شامل")
            if q.free_days_at_pod >= 21:
                advantages.append(f"فترة سماح ممتازة بالميناء ({q.free_days_at_pod} يوماً)")
            elif q.free_days_at_pod >= 14:
                advantages.append("فترة سماح قياسية (14 يوماً)")
            if q.transit_days == min_transit:
                advantages.append(f"أسرع زمن ترانزيت ({q.transit_days} يوماً)")
            if cost_saving > 0:
                advantages.append(f"وفر مالي بقيمة ${cost_saving:,.2f} مقارنة بالمتوسط")

            scored_quotes.append({
                "quote": q,
                "cost_score": round(cost_score, 1),
                "free_days_score": round(free_days_score, 1),
                "transit_score": round(transit_score, 1),
                "reliability_score": round(partner_score, 1),
                "composite_score": composite_score,
                "cost_saving": cost_saving,
                "advantages": advantages,
            })

        # Rank descending by composite score, then by total cost ascending
        scored_quotes.sort(key=lambda x: (-x["composite_score"], x["quote"].total_cost))

        ranked_list: List[RankedForwarderQuote] = []
        for idx, item in enumerate(scored_quotes, start=1):
            q_entity = item["quote"]
            ranked_list.append(
                RankedForwarderQuote(
                    rank=idx,
                    quotation_id=q_entity.quotation_id,
                    provider_id=q_entity.provider_id,
                    provider_name=q_entity.provider_name,
                    vessel_name=q_entity.vessel_name,
                    total_cost=q_entity.total_cost,
                    currency_code=q_entity.currency_code,
                    transit_days=q_entity.transit_days,
                    free_days_at_pod=q_entity.free_days_at_pod,
                    cost_score=item["cost_score"],
                    free_days_score=item["free_days_score"],
                    transit_score=item["transit_score"],
                    reliability_score=item["reliability_score"],
                    composite_score=item["composite_score"],
                    cost_saving_vs_average=item["cost_saving"],
                    key_advantages=item["advantages"],
                )
            )

        top_three = ranked_list[:3]

        # Executive Recommendation
        winner = top_three[0]
        route_str = f"{db_rfq.pol_name} ──> {db_rfq.pod_name}"
        adv_text = "، ".join(winner.key_advantages) if winner.key_advantages else "توازن ممتاز بين السعر والشروط"
        recommendation = (
            f"التوصية التنفيذية للاعتماد: يوصى بحجز الشحنة على العرض التنافسي الأول [{winner.provider_name}] "
            f"بإجمالي تكلفة ${winner.total_cost:,.2f} {winner.currency_code}، وبزمن ترانزيت {winner.transit_days} يوماً وسماح {winner.free_days_at_pod} يوماً. "
            f"حقق العرض أعلى درجة تقييم موزونة ({winner.composite_score:.1f}/100) ويوفر ${winner.cost_saving_vs_average:,.2f} مقارنة بمتوسط عروض المسار ({adv_text})."
        )

        return RFQBenchmarkResponse(
            rfq_id=db_rfq.rfq_id,
            rfq_code=db_rfq.rfq_code,
            title=db_rfq.title,
            route=route_str,
            total_quotes_analyzed=len(quotes),
            average_cost_usd=round(avg_cost, 2),
            top_three_quotes=top_three,
            all_ranked_quotes=ranked_list,
            executive_recommendation_ar=recommendation,
        )

