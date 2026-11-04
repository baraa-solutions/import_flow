"""
Service Layer for Smart Shipment Experience Guide (KB-GUIDE-012)
Matching Engine & Dynamic Institutional Knowledge Platform
"""
import re
import json
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from datetime import datetime, timezone

from modules.experience_guide.model import GuideEntry, GuideEntryScope
from modules.experience_guide.schemas import (
    GuideEntryCreate,
    GuideEntryUpdate,
    GuideEntryResponse,
    GuideMatchRequest,
    GuideMatchResponse,
    SimilarShipmentResponse,
    DetectedPatternResponse,
    SmartReferenceCardResponse,
    GuideEntryPromoteRequest,
    GuideEntryRejectRequest,
    ProvenanceResponse,
    AutonomousAuditLogResponse,
    AutonomousRecalculateResponse,
)
from modules.experience_guide.repository import ExperienceGuideRepository
from modules.experience_guide.autonomous_engine import AutonomousLearningEngine
from modules.experience_guide.validators import validate_guide_entry_data, validate_guide_entry_update
from modules.import_files.model import ImportFile


class ExperienceGuideService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ExperienceGuideRepository(db)

    def list_entries(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        scope_type: Optional[str] = None,
        scope_value: Optional[str] = None,
        is_active: Optional[bool] = None,
        source_type: Optional[str] = None,
        status: Optional[str] = None,
    ) -> List[GuideEntryResponse]:
        entries = self.repo.list_entries(
            skip=skip,
            limit=limit,
            search=search,
            scope_type=scope_type,
            scope_value=scope_value,
            is_active=is_active,
            source_type=source_type,
            status=status,
        )
        return [GuideEntryResponse.model_validate(e) for e in entries]

    def get_entry(self, entry_id: int) -> GuideEntryResponse:
        entry = self.repo.get_by_id(entry_id)
        if not entry:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guide entry not found")
        return GuideEntryResponse.model_validate(entry)

    def create_entry(self, data: GuideEntryCreate) -> GuideEntryResponse:
        validate_guide_entry_data(data)
        entry = self.repo.create_entry(data)
        return GuideEntryResponse.model_validate(entry)

    def update_entry(self, entry_id: int, data: GuideEntryUpdate) -> GuideEntryResponse:
        validate_guide_entry_update(data)
        updated = self.repo.update_entry(entry_id, data)
        if not updated:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guide entry not found")
        return GuideEntryResponse.model_validate(updated)

    def delete_entry(self, entry_id: int) -> bool:
        success = self.repo.delete_entry(entry_id)
        if not success:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guide entry not found")
        return True

    def upvote_entry(self, entry_id: int) -> GuideEntryResponse:
        entry = self.repo.upvote_entry(entry_id)
        if not entry:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Guide entry not found")
        return GuideEntryResponse.model_validate(entry)

    def search_entries(self, query: str, limit: int = 50) -> List[GuideEntryResponse]:
        entries = self.repo.search_entries(query, limit=limit)
        return [GuideEntryResponse.model_validate(e) for e in entries]

    def match_shipment(self, params: GuideMatchRequest) -> GuideMatchResponse:
        """
        Run multi-dimensional ranked matching engine against input parameters.
        Returns ranked matched entries grouped by severity and actionable operational guidance.
        """
        param_dict = params.model_dump(exclude_none=True)
        raw_matched = self.repo.find_matching_entries(param_dict)

        matched_responses: List[GuideEntryResponse] = []
        for entry, score, dims in raw_matched:
            resp = GuideEntryResponse.model_validate(entry)
            resp.match_score = score
            resp.matched_dimensions = dims
            matched_responses.append(resp)

        critical_entries = [e for e in matched_responses if e.severity == "critical"]
        warning_entries = [e for e in matched_responses if e.severity == "warning"]
        info_entries = [e for e in matched_responses if e.severity == "info"]
        positive_entries = [e for e in matched_responses if e.severity == "positive"]

        has_critical = len(critical_entries) > 0
        has_warning = len(warning_entries) > 0
        has_blocking = has_critical

        mandatory_ports = set()
        required_docs = set()
        suggested_notes = []

        for e in matched_responses:
            suggested_notes.append(f"[{e.title}]: {e.content}")

            content_norm = e.content.lower()
            if "إسكندرية" in content_norm or "اسكندرية" in content_norm or "alexandria" in content_norm:
                mandatory_ports.add("ميناء الإسكندرية / الدخيلة")

            if e.entry_type == "required_document" or "منشأ" in content_norm or "origin" in content_norm:
                required_docs.add("شهادة منشأ أصلية معتمدة (COO)")
            if "فحص" in content_norm or "goeic" in content_norm or "واردات" in content_norm:
                required_docs.add("شهادة فحص مسبق / عينات واردات")
            if "تحفظ" in content_norm or "bond" in content_norm:
                required_docs.add("إقرار تحفظ جمركي ونقل مؤقت")

        return GuideMatchResponse(
            matched_entries=matched_responses,
            critical_entries=critical_entries,
            warning_entries=warning_entries,
            info_entries=info_entries,
            positive_entries=positive_entries,
            has_critical_alert=has_critical,
            has_blocking_critical_alert=has_blocking,
            has_warning_alert=has_warning,
            mandatory_ports=list(mandatory_ports),
            required_documents=list(required_docs),
            suggested_notes=suggested_notes,
        )

    def get_similar_shipments(self, import_file_id: int) -> List[SimilarShipmentResponse]:
        raw_list = self.repo.find_similar_shipments(import_file_id)
        return [SimilarShipmentResponse.model_validate(item) for item in raw_list]

    def get_detected_patterns(self) -> List[DetectedPatternResponse]:
        raw_patterns = self.repo.detect_operational_patterns()
        return [DetectedPatternResponse.model_validate(p) for p in raw_patterns]

    @staticmethod
    def _derive_season(d: Optional[datetime]) -> str:
        if not d:
            now = datetime.now()
            month = now.month
        else:
            month = d.month

        if month in (3, 4):
            return "Q1 / موسم رمضان"
        elif month in (6, 7, 8):
            return "Q3 / موسم الصيف وتكدس الموانئ"
        elif month in (9, 10, 11, 12):
            return "Q4 / ذروة الشحن السنوي"
        else:
            return "Q1 / بداية الربع الأول"

    def sync_anti_dumping_guide_entry(
        self,
        hs_code: str,
        hs_description: str,
        anti_dumping_notes: Optional[str] = None,
    ) -> GuideEntry:
        """
        Ensures an active CRITICAL Experience Guide Entry exists for any HS Code subject
        to Anti-Dumping duties & Safeguard measures (غ6555 / غ6904).
        Powers both the Shipment Smart Reference Card Critical Alert and ExperienceGuideAlertBanner.
        """
        clean_hs = hs_code.replace(".", "").strip()
        existing = (
            self.db.query(GuideEntry)
            .join(GuideEntryScope)
            .filter(
                GuideEntryScope.scope_type == "hs_code",
                GuideEntryScope.scope_value == clean_hs,
                GuideEntry.severity == "critical",
                GuideEntry.is_active == True,
            )
            .first()
        )
        if existing:
            return existing

        desc_snippet = hs_description[:60] if hs_description else "الصنف"
        content_text = (
            f"تحذير تشغيلي حرج يمنع استكمال الإجراءات حتى الإقرار والاطلاع: هذا البند الجمركي خاضع لاشتراطات رسوم الإغراق والتدابير الوقائية. "
            f"يراعى إيداع حصيلة رسم الإغراق والتدابير الوقائية لحساب وزارة الاستثمار والتجارة الخارجية (غ6555). "
            f"مطلوب شهادة منشأ أصلية مصدقة ومرفقة قبل الشحن وفاتورة مصنع تفصيلية واستيفاء شرط الشحن المباشر من بلد المنشأ (ق4122) "
            f"لتفادي التحفظ الجمركي أو فرض غرامات ورسوم إغراق باهظة."
        )
        if anti_dumping_notes:
            content_text += f"\nاشتراطات نافذة:\n{anti_dumping_notes}"

        category_title = "السجاد والأرضيات" if ("سجاد" in hs_description or "أرضيات" in hs_description) else desc_snippet

        entry = GuideEntry(
            title=f"صنف {category_title} — اشتراطات ورسوم إغراق وتدابير وقائية",
            content=content_text,
            entry_type="alert",
            severity="critical",
            department="Logistics",
            created_by="System Seed (Logistics)",
            status="ACTIVE",
            source_type="HUMAN_AUTHORED",
            is_active=True,
        )
        self.db.add(entry)
        self.db.flush()

        scope_hs = GuideEntryScope(
            guide_entry_id=entry.entry_id,
            scope_type="hs_code",
            scope_value=clean_hs,
        )
        self.db.add(scope_hs)

        if "سجاد" in hs_description or "أرضيات" in hs_description:
            self.db.add(GuideEntryScope(
                guide_entry_id=entry.entry_id,
                scope_type="product_category",
                scope_value="سجاد وأغطية أرضيات",
            ))

        self.db.commit()
        self.db.refresh(entry)
        return entry

    def generate_smart_reference_card(self, import_file_id: int) -> SmartReferenceCardResponse:
        """
        Dynamically aggregates live actual data from a specific shipment to generate
        the Smart Reference Card (KB-GUIDE-012 Part 2) with historical similar shipments.
        """
        file = self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not file:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Import file not found")

        # 1. Product Summary & Linked POs Integration
        from modules.purchase_orders.model import PurchaseOrder, PackingListItem, POLineItem

        linked_pos = (
            self.db.query(PurchaseOrder)
            .filter(
                (PurchaseOrder.import_file_id == import_file_id)
                | (PurchaseOrder.po_number == file.po_number)
                | (PurchaseOrder.proforma_invoice_number == file.pi_number)
                | (PurchaseOrder.proforma_invoice_number == file.po_number)
            )
            .all()
        )
        if file.po_ids:
            try:
                import json
                ids = json.loads(file.po_ids) if isinstance(file.po_ids, str) else file.po_ids
                if isinstance(ids, list) and ids:
                    additional_pos = (
                        self.db.query(PurchaseOrder)
                        .filter(PurchaseOrder.po_id.in_(ids))
                        .all()
                    )
                    seen_ids = {p.po_id for p in linked_pos}
                    for p in additional_pos:
                        if p.po_id not in seen_ids:
                            linked_pos.append(p)
                            seen_ids.add(p.po_id)
            except Exception:
                pass

        hs_summaries: Dict[str, Dict[str, Any]] = {}
        shipment_hs_codes: List[str] = []
        shipment_categories: List[str] = []

        # 1A. Extract and group from PackingListItem
        for po in linked_pos:
            for pli in po.packing_list_items:
                hs = (pli.hs_code or "").strip()
                if not hs and file.hs_code:
                    hs = file.hs_code.strip()
                if not hs and po.line_items:
                    for li in po.line_items:
                        if li.hs_code and li.hs_code.strip():
                            hs = li.hs_code.strip()
                            break
                if not hs:
                    hs = "5602290000" if "Acoustic" in (pli.description or "") or "أكوستيك" in (pli.description or "") else "Unspecified"

                if hs not in hs_summaries:
                    hs_summaries[hs] = {
                        "hs_code": hs,
                        "description": pli.description or pli.main_description or "",
                        "cbm": 0.0,
                        "gross_weight_kg": 0.0,
                        "net_weight_kg": 0.0,
                        "packages_count": 0,
                        "quantity_pcs": 0.0,
                    }
                hs_summaries[hs]["cbm"] += float(pli.total_cbm or 0.0)
                hs_summaries[hs]["gross_weight_kg"] += float(pli.total_gross_weight_kg or 0.0)
                hs_summaries[hs]["net_weight_kg"] += float(pli.total_net_weight_kg or 0.0)
                hs_summaries[hs]["packages_count"] += int(pli.qty_pkg or 0)
                hs_summaries[hs]["quantity_pcs"] += float(pli.qty_pcs or 0.0)

                if hs not in shipment_hs_codes and hs != "Unspecified":
                    shipment_hs_codes.append(hs)
                desc = pli.description or pli.main_description
                if desc and desc not in shipment_categories:
                    shipment_categories.append(desc)

        # 1B. Fallback to POLineItem if packing_list_items was empty
        if not hs_summaries:
            for po in linked_pos:
                for li in po.line_items:
                    hs = (li.hs_code or "").strip() or (file.hs_code or "").strip()
                    if not hs:
                        hs = "5602290000" if ("Acoustic" in (li.main_description or "") or "أكوستيك" in (li.description_ar or "")) else "Unspecified"
                    if hs not in hs_summaries:
                        hs_summaries[hs] = {
                            "hs_code": hs,
                            "description": li.main_description or li.description_ar or "",
                            "cbm": 0.0,
                            "gross_weight_kg": 0.0,
                            "net_weight_kg": 0.0,
                            "packages_count": 0,
                            "quantity_pcs": 0.0,
                        }
                    cbm_val = float(li.total_cbm or 0.0) or (float(li.cbm_per_unit or 0.0) * float(li.quantity or 0.0))
                    gross_val = float(li.gross_weight_kg or 0.0)
                    net_val = float(li.net_weight_kg or 0.0)
                    hs_summaries[hs]["cbm"] += cbm_val
                    hs_summaries[hs]["gross_weight_kg"] += gross_val
                    hs_summaries[hs]["net_weight_kg"] += net_val
                    hs_summaries[hs]["packages_count"] += int(li.quantity or 0)
                    hs_summaries[hs]["quantity_pcs"] += float(li.quantity or 0.0)

                    if hs not in shipment_hs_codes and hs != "Unspecified":
                        shipment_hs_codes.append(hs)
                    desc = li.main_description or li.description_ar
                    if desc and desc not in shipment_categories:
                        shipment_categories.append(desc)

        # 1C. Fallback to file.packing_lists_data if still empty
        if not hs_summaries and file.packing_lists_data:
            pl_data = file.packing_lists_data or []
            for p in pl_data:
                hs = (p.get("hs_code") or file.hs_code or "Unspecified").strip()
                if hs not in hs_summaries:
                    hs_summaries[hs] = {
                        "hs_code": hs,
                        "description": p.get("description") or file.product_category or "",
                        "cbm": 0.0,
                        "gross_weight_kg": 0.0,
                        "net_weight_kg": 0.0,
                        "packages_count": 0,
                        "quantity_pcs": 0.0,
                    }
                hs_summaries[hs]["cbm"] += float(p.get("cbm", 0) or 0)
                hs_summaries[hs]["gross_weight_kg"] += float(p.get("gross_weight_kg", 0) or 0)
                hs_summaries[hs]["packages_count"] += int(p.get("total_packages", 0) or 0)
                if hs not in shipment_hs_codes and hs != "Unspecified":
                    shipment_hs_codes.append(hs)

        if hs_summaries:
            total_packages = sum(s["packages_count"] for s in hs_summaries.values())
            total_cbm = sum(s["cbm"] for s in hs_summaries.values())
            total_weight = sum(s["gross_weight_kg"] for s in hs_summaries.values())
            total_net_weight = sum(s["net_weight_kg"] for s in hs_summaries.values())
            for s in hs_summaries.values():
                s["cbm"] = round(s["cbm"], 4)
                s["gross_weight_kg"] = round(s["gross_weight_kg"], 2)
                s["net_weight_kg"] = round(s["net_weight_kg"], 2)
                s["quantity_pcs"] = round(s["quantity_pcs"], 2)
        elif linked_pos:
            total_cbm = sum(float(po.total_cbm or 0.0) for po in linked_pos)
            total_weight = sum(float(po.total_gross_weight_kg or 0.0) for po in linked_pos)
            total_net_weight = sum(float(po.total_net_weight_kg or 0.0) for po in linked_pos)
            total_packages = sum(int(po.total_packages_count or 0) for po in linked_pos)
        else:
            total_packages = 0
            total_cbm = 0.0
            total_weight = 0.0
            total_net_weight = 0.0

        if file.hs_code and file.hs_code not in shipment_hs_codes:
            shipment_hs_codes.insert(0, file.hs_code)
        if file.product_category and file.product_category not in shipment_categories:
            shipment_categories.insert(0, file.product_category)

        primary_hs = file.hs_code or (shipment_hs_codes[0] if shipment_hs_codes else "5602290000")
        primary_category = file.product_category or (shipment_categories[0] if shipment_categories else "PET Acoustic Panels (أكوستيك)")

        # 2. Route & Line Summary
        route_summary = {
            "origin_port": file.port_of_loading or "غير محدد",
            "destination_port": file.port_of_discharge or "ميناء الإسكندرية",
            "shipment_mode": file.shipment_mode,
            "incoterm_code": file.incoterm_code,
            "shipping_line": file.selected_scenario or "خط ملاحي معتمد (MSC/CMA)",
            "supplier_name": file.supplier_name,
            "importer_name": file.company_name,
        }

        # 3. Critical Dates
        critical_dates = {
            "file_opening_date": str(file.file_opening_date) if file.file_opening_date else None,
            "cargo_ready_date": str(file.cargo_ready_date) if file.cargo_ready_date else None,
            "required_eta": str(file.required_eta) if file.required_eta else None,
            "target_free_days": file.target_free_days or 21,
            "free_time_status": f"{file.target_free_days or 21} يوماً فترة سماح للحاويات — فترة آمنة",
        }

        # 4. Multi-dimensional Matching
        from modules.customs_tariff.model import CustomsTariff
        for h_code in (shipment_hs_codes or [primary_hs]):
            if not h_code:
                continue
            clean_h = h_code.replace(".", "").strip()
            tariff_rec = self.db.query(CustomsTariff).filter(
                CustomsTariff.hs_code == clean_h,
                CustomsTariff.is_active == True,
            ).first()
            if tariff_rec and getattr(tariff_rec, "has_anti_dumping_risk", False):
                self.sync_anti_dumping_guide_entry(
                    hs_code=clean_h,
                    hs_description=tariff_rec.hs_description,
                    anti_dumping_notes=tariff_rec.anti_dumping_notes,
                )

        match_req = GuideMatchRequest(
            hs_code=primary_hs,
            hs_codes=shipment_hs_codes or [primary_hs],
            product_category=primary_category,
            product_categories=shipment_categories or [primary_category],
            destination_port=file.port_of_discharge,
            port_of_discharge=file.port_of_discharge,
            port_of_loading=file.port_of_loading,
            supplier=file.supplier_name,
            shipping_line=file.selected_scenario,
            incoterm=file.incoterm_code,
            season_timing=self._derive_season(file.file_opening_date),
            import_file_reference=file.import_file_code,
            import_file_id=file.import_file_id,
        )
        match_result = self.match_shipment(match_req)

        # 5. Document Checklist Status
        coo_required = any(
            "منشأ" in d.lower() or "coo" in d.lower() for d in match_result.required_documents
        ) or any("8520" in h or "5602" in h for h in shipment_hs_codes) or ("أكوستيك" in primary_category or "Acoustic" in primary_category)

        attached_docs = []
        pending_docs = []

        if file.form4_no:
            attached_docs.append(f"نموذج 4 بنكي ({file.form4_no})")
        else:
            pending_docs.append("نموذج 4 البنكي")

        if file.acid_number:
            attached_docs.append(f"رقم نافذة ACID ({file.acid_number})")
        else:
            pending_docs.append("رقم قيد نافذة ACID")

        # Invoices check: check file invoices or linked PO invoices
        has_invoices = bool(file.invoices_data) or any(bool(po.proforma_invoice_number) for po in linked_pos)
        if file.invoices_data:
            attached_docs.append(f"الفواتير التجارية ({len(file.invoices_data)} فاتورة)")
        elif any(bool(po.proforma_invoice_number) for po in linked_pos):
            pi_nums = [po.proforma_invoice_number for po in linked_pos if po.proforma_invoice_number]
            attached_docs.append(f"الفواتير التجارية / المبدئية ({', '.join(pi_nums)})")
        else:
            pending_docs.append("الفاتورة التجارية")

        # Packing lists check
        has_pl = bool(file.packing_lists_data) or any(bool(po.packing_list_items or po.pallet_plan or po.total_cbm > 0) for po in linked_pos)
        if has_pl:
            attached_docs.append("بيان العبوة (Packing List)")
        else:
            pending_docs.append("بيان العبوة (Packing List)")

        has_coo = bool(file.notes and ("شهادة المنشأ" in file.notes or "COO" in file.notes))
        if coo_required:
            if has_coo:
                attached_docs.append("شهادة المنشأ الأصلية")
            else:
                pending_docs.append("شهادة المنشأ الأصلية (مطلوبة إجبارياً)")

        total_req_count = len(attached_docs) + len(pending_docs)
        is_complete = len(pending_docs) == 0

        document_status = {
            "is_complete": is_complete,
            "total_required": total_req_count,
            "attached_count": len(attached_docs),
            "attached_documents": attached_docs,
            "pending_documents": pending_docs,
            "has_coo_attached": has_coo,
            "is_coo_required": coo_required,
        }

        # 6. Cost Summary
        inv_data = file.invoices_data or []
        actual_invoiced = sum(float(i.get("amount", 0) or 0) for i in inv_data)
        if actual_invoiced == 0.0 and file.estimated_cost > 0:
            actual_invoiced = file.estimated_cost

        est_cost = file.estimated_cost
        diff = actual_invoiced - est_cost
        diff_pct = (diff / est_cost * 100) if est_cost > 0 else 0.0

        cost_summary = {
            "estimated_cost": est_cost,
            "actual_invoiced_cost": actual_invoiced,
            "currency": file.estimated_cost_currency,
            "variance_amount": round(diff, 2),
            "variance_percentage": round(diff_pct, 1),
            "status": "ضمن الميزانية التقديرية" if diff <= 0 else "تجاوز الميزانية التقديرية",
        }

        # 7. Similar Historical Shipments
        similar_shipments = self.get_similar_shipments(import_file_id)

        return SmartReferenceCardResponse(
            import_file_id=file.import_file_id,
            import_file_code=file.import_file_code,
            custom_file_number=file.custom_file_number,
            product_summary={
                "hs_code": primary_hs,
                "product_category": primary_category,
                "packages_count": total_packages,
                "total_cbm": round(total_cbm, 4),
                "total_gross_weight_kg": round(total_weight, 2),
                "total_net_weight_kg": round(total_net_weight, 2),
                "all_hs_codes": list(hs_summaries.keys()),
                "hs_summaries": list(hs_summaries.values()),
            },
            route_summary=route_summary,
            critical_dates=critical_dates,
            document_status=document_status,
            matched_guide_entries=match_result.matched_entries,
            similar_shipments=similar_shipments,
            cost_summary=cost_summary,
        )

    # =========================================================================
    # Autonomous Learning Engine (Section 5A) Methods
    # =========================================================================

    @classmethod
    def run_autonomous_learning(
        cls,
        db: Session,
        trigger_import_file_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Triggers continuous statistical mining and updates autonomous reference notes.
        Can be called by shipment closure hooks or background cron jobs.
        """
        return AutonomousLearningEngine.run_full_autonomous_cycle(
            db, trigger_import_file_id=trigger_import_file_id
        )

    def recalculate_autonomous(
        self,
        trigger_import_file_id: Optional[int] = None,
    ) -> AutonomousRecalculateResponse:
        res = AutonomousLearningEngine.run_full_autonomous_cycle(
            self.db, trigger_import_file_id=trigger_import_file_id
        )
        return AutonomousRecalculateResponse(**res)

    def promote_inferred_entry(
        self,
        entry_id: int,
        payload: GuideEntryPromoteRequest,
    ) -> GuideEntryResponse:
        entry = self.repo.promote_entry(
            entry_id=entry_id,
            promoted_by=payload.promoted_by,
            edited_title=payload.edited_title,
            edited_content=payload.edited_content,
            edited_severity=payload.edited_severity,
        )
        if not entry:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guide entry not found",
            )
        return GuideEntryResponse.model_validate(entry)

    def reject_inferred_entry(
        self,
        entry_id: int,
        payload: GuideEntryRejectRequest,
    ) -> GuideEntryResponse:
        entry = self.repo.reject_entry(
            entry_id=entry_id,
            rejected_by=payload.rejected_by,
            rejection_reason=payload.rejection_reason,
        )
        if not entry:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guide entry not found",
            )
        return GuideEntryResponse.model_validate(entry)

    def get_entry_provenance(self, entry_id: int) -> ProvenanceResponse:
        entry = self.repo.get_by_id(entry_id)
        if not entry:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guide entry not found",
            )

        contributing = []
        if entry.contributing_files_json:
            try:
                contributing = json.loads(entry.contributing_files_json)
            except Exception:
                contributing = []

        return ProvenanceResponse(
            entry_id=entry.entry_id,
            title=entry.title,
            content=entry.content,
            source_type=entry.source_type or "HUMAN_AUTHORED",
            status=entry.status or "ACTIVE",
            pattern_category=entry.pattern_category,
            confidence_score=entry.confidence_score,
            confidence_level=entry.confidence_level,
            sample_size=entry.sample_size,
            evidence_summary=entry.evidence_summary,
            contributing_files=contributing,
            reason_why=entry.reason_why,
            first_detected_at=entry.first_detected_at,
            last_recalculated_at=entry.last_recalculated_at,
            confirmed_by=entry.confirmed_by,
            confirmed_at=entry.confirmed_at,
            rejected_by=entry.rejected_by,
            rejected_at=entry.rejected_at,
            rejection_reason=entry.rejection_reason,
        )

    def get_autonomous_audit_logs(
        self,
        limit: int = 50,
        entry_id: Optional[int] = None,
    ) -> List[AutonomousAuditLogResponse]:
        logs = self.repo.get_audit_logs(limit=limit, entry_id=entry_id)
        return [AutonomousAuditLogResponse.model_validate(l) for l in logs]
