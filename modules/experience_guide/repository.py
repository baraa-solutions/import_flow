"""
Repository for Smart Shipment Experience Guide (KB-GUIDE-012)
Institutional Knowledge Engine & Operational Memory
"""
import re
import difflib
from typing import List, Optional, Dict, Any, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc, func
from datetime import datetime, timezone

from modules.experience_guide.model import GuideEntry, GuideEntryScope, AutonomousPatternAuditLog
from modules.experience_guide.schemas import GuideEntryCreate, GuideEntryUpdate
from modules.import_files.model import ImportFile



def _drop_system_message_if_text_changed(
    entry: GuideEntry, new_title: Optional[str], new_content: Optional[str]
) -> None:
    """A user edit of an engine-generated title/content replaces the system message: clear the code so
    the UI shows the user's text instead of re-rendering the catalog template."""
    if not getattr(entry, "msg_code", None):
        return
    if (new_title is not None and new_title != entry.title) or (
        new_content is not None and new_content != entry.content
    ):
        entry.msg_code = None
        entry.msg_params = None

class ExperienceGuideRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, entry_id: int) -> Optional[GuideEntry]:
        return self.db.query(GuideEntry).filter(GuideEntry.entry_id == entry_id).first()

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
    ) -> List[GuideEntry]:
        query = self.db.query(GuideEntry)

        if is_active is not None:
            query = query.filter(GuideEntry.is_active == is_active)

        if source_type:
            query = query.filter(GuideEntry.source_type == source_type)

        if status:
            query = query.filter(GuideEntry.status == status)

        if search:
            s = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    GuideEntry.title.ilike(s),
                    GuideEntry.content.ilike(s),
                    GuideEntry.department.ilike(s),
                )
            )

        if scope_type or scope_value:
            query = query.join(GuideEntry.scopes)
            if scope_type:
                query = query.filter(GuideEntryScope.scope_type == scope_type)
            if scope_value:
                query = query.filter(GuideEntryScope.scope_value.ilike(f"%{scope_value.strip()}%"))

        return query.order_by(desc(GuideEntry.created_at)).offset(skip).limit(limit).all()

    def create_entry(self, data: GuideEntryCreate) -> GuideEntry:
        entry = GuideEntry(
            title=data.title.strip(),
            content=data.content.strip(),
            entry_type=data.entry_type,
            severity=data.severity,
            department=data.department.strip() if data.department else None,
            expires_at=data.expires_at,
            created_by=data.created_by.strip() or "System",
            is_active=True,
            upvotes=0,
        )
        self.db.add(entry)
        self.db.flush()

        for sc in data.scopes:
            scope_obj = GuideEntryScope(
                guide_entry_id=entry.entry_id,
                scope_type=sc.scope_type.strip(),
                scope_value=sc.scope_value.strip(),
            )
            self.db.add(scope_obj)

        self.db.commit()
        self.db.refresh(entry)
        return entry

    def update_entry(self, entry_id: int, data: GuideEntryUpdate) -> Optional[GuideEntry]:
        entry = self.get_by_id(entry_id)
        if not entry:
            return None

        if data.title is not None or data.content is not None:
            _drop_system_message_if_text_changed(
                entry,
                data.title.strip() if data.title is not None else None,
                data.content.strip() if data.content is not None else None,
            )
        if data.title is not None:
            entry.title = data.title.strip()
        if data.content is not None:
            entry.content = data.content.strip()
        if data.entry_type is not None:
            entry.entry_type = data.entry_type
        if data.severity is not None:
            entry.severity = data.severity
        if data.department is not None:
            entry.department = data.department.strip() if data.department else None
        if data.expires_at is not None:
            entry.expires_at = data.expires_at
        if data.is_active is not None:
            entry.is_active = data.is_active

        entry.updated_at = datetime.now(timezone.utc)

        if data.scopes is not None:
            self.db.query(GuideEntryScope).filter(GuideEntryScope.guide_entry_id == entry_id).delete()
            for sc in data.scopes:
                scope_obj = GuideEntryScope(
                    guide_entry_id=entry.entry_id,
                    scope_type=sc.scope_type.strip(),
                    scope_value=sc.scope_value.strip(),
                )
                self.db.add(scope_obj)

        self.db.commit()
        self.db.refresh(entry)
        return entry

    def delete_entry(self, entry_id: int) -> bool:
        entry = self.get_by_id(entry_id)
        if not entry:
            return False
        entry.is_active = False
        entry.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        return True

    def upvote_entry(self, entry_id: int) -> Optional[GuideEntry]:
        entry = self.get_by_id(entry_id)
        if not entry:
            return None
        entry.upvotes = (entry.upvotes or 0) + 1
        entry.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def search_entries(self, query_text: str, limit: int = 50) -> List[GuideEntry]:
        """
        Free-text / semantic keyword search across title, content, scopes, and department.
        """
        if not query_text or not query_text.strip():
            return self.list_entries(limit=limit)

        q = query_text.strip()
        tokens = [t.strip() for t in q.split() if len(t.strip()) >= 2]
        base_query = self.db.query(GuideEntry).filter(GuideEntry.is_active == True)

        or_conditions = [
            GuideEntry.title.ilike(f"%{q}%"),
            GuideEntry.content.ilike(f"%{q}%"),
            GuideEntry.department.ilike(f"%{q}%"),
        ]
        for t in tokens:
            or_conditions.append(GuideEntry.title.ilike(f"%{t}%"))
            or_conditions.append(GuideEntry.content.ilike(f"%{t}%"))

        matched_ids = set()
        for e in base_query.filter(or_(*or_conditions)).all():
            matched_ids.add(e.entry_id)

        # Also search in scopes
        scope_matches = (
            self.db.query(GuideEntryScope.guide_entry_id)
            .filter(GuideEntryScope.scope_value.ilike(f"%{q}%"))
            .all()
        )
        for sm in scope_matches:
            matched_ids.add(sm[0])

        if not matched_ids:
            return []

        return (
            self.db.query(GuideEntry)
            .filter(GuideEntry.entry_id.in_(list(matched_ids)), GuideEntry.is_active == True)
            .order_by(desc(GuideEntry.upvotes), desc(GuideEntry.created_at))
            .limit(limit)
            .all()
        )

    @staticmethod
    def _normalize_code(val: Optional[str]) -> str:
        if not val:
            return ""
        return re.sub(r"[^A-Za-z0-9]", "", str(val)).lower()

    @staticmethod
    def _normalize_text(val: Optional[str]) -> str:
        if not val:
            return ""
        t = str(val).lower().strip()
        # Normalize Arabic characters
        t = re.sub(r"[أإآ]", "ا", t)
        t = re.sub(r"ة", "ه", t)
        t = re.sub(r"ى", "ي", t)
        # Strip common punctuation
        t = re.sub(r"[,/\\-]", " ", t)
        return re.sub(r"\s+", " ", t).strip()

    @classmethod
    def _fuzzy_match(cls, s1: str, s2: str, threshold: float = 0.80) -> bool:
        """
        Fuzzy match supporting containment, token intersection, or SequenceMatcher ratio.
        Prevents misses due to minor spelling variances (e.g. Suzhou Yuheng Textile vs Suzhou Yuheng).
        """
        if not s1 or not s2:
            return False
        n1 = cls._normalize_text(s1)
        n2 = cls._normalize_text(s2)

        if n1 in n2 or n2 in n1:
            return True

        tokens1 = set(n1.split())
        tokens2 = set(n2.split())
        if tokens1 and tokens2:
            intersection = tokens1.intersection(tokens2)
            # If 2 or more significant words match
            sig_tokens = [t for t in intersection if len(t) > 2]
            if len(sig_tokens) >= 2 or (len(tokens1) == 1 and len(tokens2) == 1 and len(sig_tokens) == 1):
                return True

        # String similarity ratio
        ratio = difflib.SequenceMatcher(None, n1, n2).ratio()
        return ratio >= threshold

    def find_matching_entries(
        self,
        shipment_params: Dict[str, Any],
    ) -> List[Tuple[GuideEntry, int, List[str]]]:
        """
        Multi-dimensional Ranked Matching Engine (Section 4).
        - Excludes inactive and expired notes.
        - Matches across any intersection of the 13 dimensions.
        - Calculates match_score (multi-dimension matches rank highest).
        - Returns List of tuples: (GuideEntry, match_score, matched_dimensions) sorted descending.
        """
        now = datetime.now(timezone.utc)
        active_entries = (
            self.db.query(GuideEntry)
            .filter(
                GuideEntry.is_active == True,
                GuideEntry.status.notin_(["ARCHIVED", "REJECTED"]),
            )
            .all()
        )

        matched_results: List[Tuple[GuideEntry, int, List[str]]] = []

        # Extract & pre-normalize input parameters
        p_hs_list = []
        if shipment_params.get("hs_codes"):
            raw_codes = shipment_params.get("hs_codes")
            if isinstance(raw_codes, list):
                p_hs_list.extend([self._normalize_code(c) for c in raw_codes if c])
            elif isinstance(raw_codes, str):
                p_hs_list.extend([self._normalize_code(c) for c in raw_codes.split(",") if c])
        if shipment_params.get("hs_code"):
            p_hs_list.append(self._normalize_code(shipment_params.get("hs_code")))
        p_hs_list = [c for c in set(p_hs_list) if c]

        p_cat_list = []
        if shipment_params.get("product_categories"):
            raw_cats = shipment_params.get("product_categories")
            if isinstance(raw_cats, list):
                p_cat_list.extend([c for c in raw_cats if c])
            elif isinstance(raw_cats, str):
                p_cat_list.extend([c for c in raw_cats.split(",") if c])
        if shipment_params.get("product_category"):
            p_cat_list.append(shipment_params.get("product_category"))
        p_cat_list = [c for c in set(p_cat_list) if c]

        p_pod = self._normalize_text(shipment_params.get("port_of_discharge") or shipment_params.get("destination_port"))
        p_pol = self._normalize_text(shipment_params.get("port_of_loading"))
        p_supp = self._normalize_text(shipment_params.get("supplier"))
        p_origin = self._normalize_code(shipment_params.get("country_of_origin"))
        p_line = self._normalize_text(shipment_params.get("shipping_line"))
        p_inco = self._normalize_code(shipment_params.get("incoterm"))
        p_pay = self._normalize_text(shipment_params.get("payment_method"))
        p_cert = self._normalize_text(shipment_params.get("certificate_type"))
        p_broker = self._normalize_text(shipment_params.get("customs_broker"))
        p_season = self._normalize_text(shipment_params.get("season_timing"))
        p_ref = self._normalize_code(shipment_params.get("import_file_reference") or str(shipment_params.get("import_file_id") or ""))

        for entry in active_entries:
            # 1. Expiration Check: Ignore expired notes (Section 4)
            if entry.expires_at is not None:
                exp = entry.expires_at if entry.expires_at.tzinfo else entry.expires_at.replace(tzinfo=timezone.utc)
                if exp < now:
                    continue

            if not entry.scopes:
                continue

            # Group scopes by dimension type (scopes of same type act as OR conditions)
            scopes_by_dim: Dict[str, List[str]] = {}
            for sc in entry.scopes:
                st = sc.scope_type.strip().lower()
                sv = sc.scope_value.strip()
                if st == "pattern_key" or not sv:
                    continue
                scopes_by_dim.setdefault(st, []).append(sv)

            if not scopes_by_dim:
                continue

            matched_dims_for_entry = []
            all_dims_matched = True

            for dim_type, values in scopes_by_dim.items():
                dim_matched = False
                for sv in values:
                    if dim_type == "hs_code":
                        target = self._normalize_code(sv)
                        if any(h and (h.startswith(target) or target.startswith(h)) for h in p_hs_list):
                            dim_matched = True
                            break

                    elif dim_type == "product_category":
                        if any(c and self._fuzzy_match(sv, c) for c in p_cat_list):
                            dim_matched = True
                            break

                    elif dim_type in ("destination_port", "port_of_discharge"):
                        target_norm = self._normalize_text(sv)
                        is_alex = ("alex" in target_norm or "اسكندر" in target_norm or "دخيل" in target_norm) and (
                            "alex" in p_pod or "اسكندر" in p_pod or "دخيل" in p_pod
                        )
                        if p_pod and (is_alex or self._fuzzy_match(target_norm, p_pod)):
                            dim_matched = True
                            break

                    elif dim_type == "port_of_loading":
                        target_norm = self._normalize_text(sv)
                        if p_pol and self._fuzzy_match(target_norm, p_pol):
                            dim_matched = True
                            break

                    elif dim_type == "supplier":
                        if p_supp and self._fuzzy_match(sv, p_supp):
                            dim_matched = True
                            break

                    elif dim_type == "country_of_origin":
                        target_norm = self._normalize_code(sv)
                        if p_origin and (p_origin == target_norm or target_norm in p_origin or p_origin in target_norm):
                            dim_matched = True
                            break

                    elif dim_type == "shipping_line":
                        if p_line and self._fuzzy_match(sv, p_line):
                            dim_matched = True
                            break

                    elif dim_type == "incoterm":
                        target_norm = self._normalize_code(sv)
                        if p_inco and target_norm == p_inco:
                            dim_matched = True
                            break

                    elif dim_type == "payment_method":
                        if p_pay and self._fuzzy_match(sv, p_pay):
                            dim_matched = True
                            break

                    elif dim_type == "certificate_type":
                        if p_cert and self._fuzzy_match(sv, p_cert):
                            dim_matched = True
                            break

                    elif dim_type == "customs_broker":
                        if p_broker and self._fuzzy_match(sv, p_broker):
                            dim_matched = True
                            break

                    elif dim_type == "season_timing":
                        if p_season and self._fuzzy_match(sv, p_season):
                            dim_matched = True
                            break

                    elif dim_type == "import_file_reference":
                        target_norm = self._normalize_code(sv)
                        if p_ref and target_norm in p_ref:
                            dim_matched = True
                            break

                if dim_matched:
                    matched_dims_for_entry.append(dim_type)
                else:
                    all_dims_matched = False

            # An entry matches if all its defined dimensions match, or if a critical product dimension matches
            entry_matches = (all_dims_matched or any(d in matched_dims_for_entry for d in ("hs_code", "product_category"))) and len(matched_dims_for_entry) > 0
            if entry_matches:
                unique_matched_dims = list(set(matched_dims_for_entry))
                match_count = len(unique_matched_dims)

                # Match strength ranking score (Section 4)
                # Base points per dimension
                score = match_count * 20

                # Multi-dimension bonus (highest priority)
                if match_count >= 3:
                    score += 50
                elif match_count == 2:
                    score += 25

                # Severity weighting
                if entry.severity == "critical":
                    score += 100  # Critical / Blocking notes rank highest
                elif entry.severity == "warning":
                    score += 40
                elif entry.severity == "positive":
                    score += 25
                elif entry.severity == "info":
                    score += 10

                # Community upvote feedback signal
                upvotes = entry.upvotes or 0
                score += min(upvotes * 2, 20)

                matched_results.append((entry, score, unique_matched_dims))

        # Sort descending by match score, then creation date
        matched_results.sort(key=lambda item: (item[1], item[0].created_at), reverse=True)
        return matched_results

    def _resolve_file_profile(self, file: ImportFile) -> Dict[str, Any]:
        """Resolves full shipment profile including linked PO packing items and line items."""
        from modules.purchase_orders.model import PurchaseOrder

        pos = (
            self.db.query(PurchaseOrder)
            .filter(
                (PurchaseOrder.import_file_id == file.import_file_id)
                | (PurchaseOrder.po_number == file.po_number)
                | (PurchaseOrder.proforma_invoice_number == file.pi_number)
            )
            .all()
        )
        if file.po_ids:
            try:
                import json
                ids = json.loads(file.po_ids) if isinstance(file.po_ids, str) else file.po_ids
                if isinstance(ids, list) and ids:
                    extra = self.db.query(PurchaseOrder).filter(PurchaseOrder.po_id.in_(ids)).all()
                    seen = {p.po_id for p in pos}
                    for p in extra:
                        if p.po_id not in seen:
                            pos.append(p)
                            seen.add(p.po_id)
            except Exception:
                pass

        hs_set = set()
        cat_set = set()
        if file.hs_code:
            hs_set.add(self._normalize_code(file.hs_code))
        if file.product_category:
            cat_set.add(file.product_category.strip())

        for po in pos:
            for pli in po.packing_list_items:
                if pli.hs_code:
                    hs_set.add(self._normalize_code(pli.hs_code))
                desc = pli.description or pli.main_description
                if desc:
                    cat_set.add(desc.strip())
            for li in po.line_items:
                if li.tariff and li.tariff.hs_code:
                    hs_set.add(self._normalize_code(li.tariff.hs_code))
                desc = li.main_description or li.description_ar
                if desc:
                    cat_set.add(desc.strip())

        return {
            "supplier": (file.supplier_name or "").strip(),
            "hs_codes": [h for h in hs_set if h],
            "categories": [c for c in cat_set if c],
            "pod": (file.port_of_discharge or "").strip(),
            "pol": (file.port_of_loading or "").strip(),
            "line": (file.selected_scenario or "").strip(),
            "origin": getattr(file, "supplier_country", None),
        }

    def find_similar_shipments(self, import_file_id: int, limit: int = 5) -> List[Dict[str, Any]]:
        """
        Finds historical Import Files sharing key dimensions (supplier, country, product, route).
        Calculates clearance delays, landed cost variance, and outcome comparison.
        Requires at least one core operational dimension (Supplier, HS Code, or Product Category)
        to prevent spurious matching based purely on destination port.
        """
        target_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
        if not target_file:
            return []

        other_files = (
            self.db.query(ImportFile)
            .filter(ImportFile.import_file_id != import_file_id)
            .order_by(desc(ImportFile.file_opening_date))
            .limit(100)
            .all()
        )

        target_prof = self._resolve_file_profile(target_file)
        similar_list = []

        for f in other_files:
            cand_prof = self._resolve_file_profile(f)
            matched_dims = []
            score = 0

            # 1. Same Supplier (Highest relevance)
            if target_prof["supplier"] and cand_prof["supplier"] and self._fuzzy_match(target_prof["supplier"], cand_prof["supplier"]):
                matched_dims.append("same_supplier")
                score += 15

            # 2. Similar HS Code (At least first 4 digits / chapter heading)
            hs_matched = False
            for th in target_prof["hs_codes"]:
                for ch in cand_prof["hs_codes"]:
                    if len(th) >= 4 and len(ch) >= 4 and th[:4] == ch[:4]:
                        hs_matched = True
                        break
                if hs_matched:
                    break
            if hs_matched:
                matched_dims.append("similar_hs_code")
                score += 15

            # 3. Product Category match
            cat_matched = False
            for tc in target_prof["categories"]:
                for cc in cand_prof["categories"]:
                    if self._fuzzy_match(tc, cc):
                        cat_matched = True
                        break
                if cat_matched:
                    break
            if cat_matched:
                matched_dims.append("same_product_category")
                score += 10

            # 4. Same Shipping Line
            if target_prof["line"] and cand_prof["line"] and self._fuzzy_match(target_prof["line"], cand_prof["line"]):
                matched_dims.append("same_shipping_line")
                score += 3

            # 5. Same Destination Port (Auxiliary ONLY)
            if target_prof["pod"] and cand_prof["pod"] and self._fuzzy_match(target_prof["pod"], cand_prof["pod"]):
                matched_dims.append("same_destination_port")
                score += 1

            # REQUIREMENT: Must have a core operational link (Supplier, HS Code, or Product Category)
            has_core_link = any(d in matched_dims for d in ("same_supplier", "similar_hs_code", "same_product_category"))
            has_multi_route_link = ("same_shipping_line" in matched_dims and len(matched_dims) >= 2 and target_prof["pol"] and cand_prof["pol"] and self._fuzzy_match(target_prof["pol"], cand_prof["pol"]))

            if has_core_link or has_multi_route_link:
                # Calculate clearance duration
                clearance_days = None
                if f.customs_released_at and f.file_opening_date:
                    try:
                        rel_date = datetime.strptime(str(f.customs_released_at)[:10], "%Y-%m-%d").date()
                        open_date = datetime.strptime(str(f.file_opening_date)[:10], "%Y-%m-%d").date()
                        clearance_days = (rel_date - open_date).days
                    except Exception:
                        pass

                # Cost variance
                cost_var_pct = None
                if f.actual_landed_cost_variance_pct is not None:
                    cost_var_pct = float(f.actual_landed_cost_variance_pct)
                elif f.estimated_cost and f.estimated_cost > 0 and f.actual_landed_cost_total_egp:
                    diff = f.actual_landed_cost_total_egp - f.estimated_cost
                    cost_var_pct = round((diff / f.estimated_cost) * 100, 1)

                similar_list.append({
                    "import_file_id": f.import_file_id,
                    "import_file_code": f.import_file_code,
                    "company_name": f.company_name or "",
                    "supplier_name": f.supplier_name or "",
                    "country_of_origin": getattr(f, "supplier_country", None),
                    "port_of_loading": f.port_of_loading,
                    "port_of_discharge": f.port_of_discharge,
                    "shipping_line": f.selected_scenario,
                    "status": f.status or "Active",
                    "opening_date": str(f.file_opening_date) if f.file_opening_date else None,
                    "clearance_duration_days": clearance_days,
                    "cost_variance_pct": cost_var_pct,
                    "matched_dimensions": matched_dims,
                    "score": len(matched_dims),
                })

        similar_list.sort(key=lambda x: (x["score"], x["opening_date"] or ""), reverse=True)
        return similar_list[:limit]

    def detect_operational_patterns(self) -> List[Dict[str, Any]]:
        """
        Pattern Detection Engine (Section 6.b):
        Scans historical shipment records to detect recurring issues and automatically
        suggest promoting them into formal Experience Guide notes.
        """
        files = self.db.query(ImportFile).all()
        patterns = []

        # 1. Supplier Delays / Variance Pattern
        supplier_records: Dict[str, List[ImportFile]] = {}
        for f in files:
            s_name = (f.supplier_name or "").strip()
            if s_name:
                supplier_records.setdefault(s_name, []).append(f)

        for supp_name, supp_files in supplier_records.items():
            if len(supp_files) >= 2:
                # Check for high cost variance or note indicators
                delayed_or_cost_heavy = [
                    f for f in supp_files
                    if (f.actual_landed_cost_variance_pct and f.actual_landed_cost_variance_pct > 7.0)
                    or (f.notes and ("تأخير" in f.notes or "delay" in f.notes.lower() or "غرامة" in f.notes))
                ]
                if len(delayed_or_cost_heavy) >= 2:
                    patterns.append({
                        "pattern_id": f"pattern-supp-{abs(hash(supp_name)) % 10000}",
                        "pattern_type": "delay",
                        "dimension_type": "supplier",
                        "dimension_value": supp_name,
                        "occurrence_count": len(delayed_or_cost_heavy),
                        "suggested_title": f"تنبيه تشغيلي متكرر: تأخيرات وفروق تكلفة لدى المورد {supp_name}",
                        "suggested_content": f"لوحظ تكرار تأخيرات أو تجاوز تكلفة في {len(delayed_or_cost_heavy)} شحنات سابقة لهذا المورد. يُنصح بإلزام المورد بمواعيد تصنيع صارمة ومتابعة اعتماد مسودات المستندات مبكراً.",
                        "suggested_severity": "warning" if len(delayed_or_cost_heavy) < 3 else "critical",
                        "suggested_entry_type": "alert",
                        "evidence_shipments": [f.import_file_code for f in delayed_or_cost_heavy[:4]],
                    })

        # 2. Port Specific Sampling Pattern
        port_files: Dict[str, List[ImportFile]] = {}
        for f in files:
            p_name = (f.port_of_discharge or "").strip()
            if p_name:
                port_files.setdefault(p_name, []).append(f)

        for pod_name, pfiles in port_files.items():
            if len(pfiles) >= 2 and ("alex" in pod_name.lower() or "إسكندرية" in pod_name or "اسكندرية" in pod_name):
                patterns.append({
                    "pattern_id": f"pattern-pod-{abs(hash(pod_name)) % 10000}",
                    "pattern_type": "port_sampling",
                    "dimension_type": "destination_port",
                    "dimension_value": pod_name,
                    "occurrence_count": len(pfiles),
                    "suggested_title": f"إجراءات سحب عينات وفحص إضافي بميناء {pod_name}",
                    "suggested_content": f"ميناء {pod_name} يتطلب إجراءات فحص ظاهري وسحب عينات معملية إضافية للأصناف الخاضعة للرقابة. يجب احتساب 5-7 أيام إضافية للتخليص.",
                    "suggested_severity": "info",
                    "suggested_entry_type": "task",
                    "evidence_shipments": [f.import_file_code for f in pfiles[:3]],
                })

        return patterns

    def promote_entry(
        self,
        entry_id: int,
        promoted_by: str,
        edited_title: Optional[str] = None,
        edited_content: Optional[str] = None,
        edited_severity: Optional[str] = None,
    ) -> Optional[GuideEntry]:
        """
        Promotes a system-inferred note into a confirmed institutional standard (Section 5A.6).
        """
        entry = self.get_by_id(entry_id)
        if not entry:
            return None

        now = datetime.now(timezone.utc)
        entry.status = "CONFIRMED"
        entry.confirmed_by = promoted_by
        entry.confirmed_at = now
        entry.updated_at = now

        _drop_system_message_if_text_changed(
            entry,
            edited_title.strip() if edited_title and edited_title.strip() else None,
            edited_content.strip() if edited_content and edited_content.strip() else None,
        )
        if edited_title and edited_title.strip():
            entry.title = edited_title.strip()
        if edited_content and edited_content.strip():
            entry.content = edited_content.strip()
        if edited_severity and edited_severity.strip():
            entry.severity = edited_severity.strip()

        # Audit log
        self.db.add(AutonomousPatternAuditLog(
            entry_id=entry.entry_id,
            pattern_key=f"PROMOTED:ENTRY:{entry.entry_id}",
            action="HUMAN_PROMOTED",
            previous_confidence=entry.confidence_score,
            new_confidence=entry.confidence_score,
            sample_size=entry.sample_size or 0,
            change_summary=f"Note promoted to CONFIRMED by {promoted_by}.",
            created_at=now,
        ))

        self.db.commit()
        self.db.refresh(entry)
        return entry

    def reject_entry(
        self,
        entry_id: int,
        rejected_by: str,
        rejection_reason: str,
    ) -> Optional[GuideEntry]:
        """
        Rejects/suppresses a system-inferred pattern with reason (Section 5A.6).
        """
        entry = self.get_by_id(entry_id)
        if not entry:
            return None

        now = datetime.now(timezone.utc)
        entry.status = "REJECTED"
        entry.is_active = False
        entry.rejected_by = rejected_by
        entry.rejected_at = now
        entry.rejection_reason = rejection_reason.strip()
        entry.updated_at = now

        # Audit log
        self.db.add(AutonomousPatternAuditLog(
            entry_id=entry.entry_id,
            pattern_key=f"REJECTED:ENTRY:{entry.entry_id}",
            action="HUMAN_REJECTED",
            previous_confidence=entry.confidence_score,
            new_confidence=0.0,
            sample_size=entry.sample_size or 0,
            change_summary=f"Inference rejected by {rejected_by}: {rejection_reason.strip()}",
            created_at=now,
        ))

        self.db.commit()
        self.db.refresh(entry)
        return entry

    def get_audit_logs(
        self,
        limit: int = 50,
        entry_id: Optional[int] = None,
    ) -> List[AutonomousPatternAuditLog]:
        query = self.db.query(AutonomousPatternAuditLog)
        if entry_id is not None:
            query = query.filter(AutonomousPatternAuditLog.entry_id == entry_id)
        return query.order_by(desc(AutonomousPatternAuditLog.created_at)).limit(limit).all()
