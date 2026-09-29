"""
Master Data Synchronization Service (MasterDataSyncService)
============================================================
Performs safe, incremental, non-destructive upserts of reference master data:
- Incoterms 2020 & Responsibility Matrix & Cost Items (MD-006)
- Currencies & Standard Official Customs Exchange Rates (MD-004)
- Customs Tariff, HS Codes, Nafeza Fee Codes & Trade Agreements (MD-008)
- Clearance Expense Catalog (MD-007)
- Default Core System Users (if empty)

Zero Data Loss Guarantee:
- Never deletes or overwrites operational client records.
- Uses entity existence checking on unique business keys.
"""
from typing import Dict, Any
from sqlalchemy.orm import Session
from datetime import date, datetime, timezone

from modules.users.model import User
import settings
from modules.auth.security import hash_password, verify_password
from settings import ADMIN_INITIAL_PASSWORD
from utils.db_safety import is_frozen_build
from modules.incoterms.model import Incoterm, CostItem, IncotermResponsibility
from modules.incoterms.incoterms_matrix import IncotermsMatrix, Party
from modules.customs_tariff.model import CustomsTariff, FeeCode, PreferentialAgreement
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_consultation.model import ClearanceExpenseType
from modules.auth.seed_rbac import seed_rbac
from modules.experience_guide.model import GuideEntry, GuideEntryScope


class MasterDataSyncService:
    def __init__(self, db: Session):
        self.db = db

    def sync_system_users(self) -> int:
        """Seed ONLY the initial admin, and only when the users table is empty. Existing users are
        never touched. The admin gets the known ADMIN_INITIAL_PASSWORD (settings.DEFAULT_ADMIN_PASSWORD
        unless overridden by env) and must_change_password=True, so it has to pick its own password on
        first login before anything else works. No other accounts are ever created."""
        added = 0
        if self.db.query(User).count() == 0:
            self.db.add(
                User(
                    username="admin",
                    email="admin@sorourlogistics.com",
                    full_name="System Admin",
                    hashed_password=hash_password(ADMIN_INITIAL_PASSWORD),
                    role="ADMIN",
                    is_active=True,
                    must_change_password=True,
                )
            )
            self.db.commit()
            added = 1
        else:
            self._forget_used_admin_initial_password()
        return added

    def _forget_used_admin_initial_password(self) -> bool:
        """Frozen build only: once the admin no longer logs in with the ADMIN_INITIAL_PASSWORD an old 2.1.x
        install wrote to .env (it was changed), drop that plaintext line. Compared against the .env value,
        not the seed default: an admin still using the generated password keeps the line. Dev .env files
        are left to the developer."""
        if not is_frozen_build():
            return False
        if not settings.env_file_defines(settings.ENV_PATH, "ADMIN_INITIAL_PASSWORD"):
            return False  # nothing to remove: skip the password hash check
        admin = self.db.query(User).filter(User.username == "admin").first()
        if admin is None or not admin.hashed_password:
            return False
        env_password = settings.env_admin_initial_password(settings.ENV_PATH)
        if env_password is None:
            return False  # unreadable line: keep it (fail closed)
        if env_password and verify_password(env_password, admin.hashed_password):
            return False
        return settings.remove_env_key(settings.ENV_PATH, "ADMIN_INITIAL_PASSWORD")

    def sync_incoterms(self) -> Dict[str, int]:
        """Incremental upsert for Incoterms 2020 rules, Cost Items, and Matrix from IncotermsMatrix Single Source of Truth."""
        added_incoterms = 0
        added_cost_items = 0
        added_resp = 0
        updated_resp = 0

        # Load verified Incoterms 2020 matrix
        matrix = IncotermsMatrix.from_json_file("incoterms_data.json")

        category_meta = {
            "trucking_origin": ("OTRK", "Trucking Origin fees", "Freight", "Trucking origin transport"),
            "export_clearance": ("XCLR", "Export Clearance fees", "Customs", "Export customs clearance and licenses"),
            "othc": ("OTHC", "OTHC fees", "Port", "Origin terminal handling charges"),
            "insurance": ("INS", "Insurance fees", "Freight", "Marine and air cargo insurance"),
            "origin_inspection": ("XINSP", "Origin Inspection", "Other", "Pre-shipment inspection and quality check"),
            "ocean_freight": ("OFR", "O/F fees", "Freight", "International ocean / air freight charges"),
            "trucking_destination": ("DTRK", "Trucking Destination fees", "Freight", "Destination inland transport to warehouse"),
            "dthc": ("DTHC", "DTHC fees", "Port", "Destination terminal handling charges"),
            "documentation": ("DOC", "Documentation fees", "Other", "Documentation and courier charges"),
            "disclaim_letter": ("DISC", "Disclaim letter", "Other", "Disclaimer letter charges (Contractual)"),
            "import_clearance": ("ICLR", "Import Clearance fees", "Customs", "Import customs brokerage and clearance"),
            "port_congestion": ("PCONG", "Port Congestion", "Port", "Port congestion surcharge (Contractual)"),
            "demurrage_detention": ("DMRG", "Demurrage & Detention", "Port", "Demurrage and detention fees (Contractual)"),
            "compliance_fees": ("XCMP", "Compliance Fees", "Other", "Regulatory compliance fees (Contractual)"),
            "form_4_lc": ("FORM4", "L/C Or Form 4 fees", "Bank", "L/C or Form 4 bank charges (Contractual)"),
            "customs_duty_tax": ("DUTY", "Tax & Customs Duties", "Customs", "Customs duty, VAT, and taxes"),
            "storage_warehousing": ("STG", "Storage/Warehousing", "Port", "Warehouse storage and holding fees (Contractual)"),
        }

        # 1. Incoterms 2020 Master
        incoterms_map = {}
        for term_code in matrix.list_terms():
            term = matrix.get_term(term_code)
            existing = self.db.query(Incoterm).filter(Incoterm.incoterm_code == term_code).first()
            if not existing:
                existing = Incoterm(
                    incoterm_code=term_code,
                    incoterm_name=term.label_ar,
                    version="Incoterms 2020",
                    description=f"Incoterms 2020 Rule ({term.mode.value})"
                )
                self.db.add(existing)
                self.db.flush()
                added_incoterms += 1
            incoterms_map[term_code] = existing.incoterm_id
        self.db.commit()

        # 2. Cost Items Master (17 Canonical Categories)
        cost_items_map = {}
        for cat in matrix.list_categories():
            code, name, category, desc = category_meta[cat.key]
            existing = self.db.query(CostItem).filter(CostItem.cost_item_code == code).first()
            if not existing:
                existing = CostItem(
                    cost_item_code=code,
                    cost_item_name=name,
                    description=desc,
                    cost_category=category
                )
                self.db.add(existing)
                self.db.flush()
                added_cost_items += 1
            cost_items_map[cat.key] = existing.cost_item_id
        self.db.commit()

        # 3. Synchronize Responsibility Matrix (11 terms x 17 categories = 187 combinations)
        for term_code in matrix.list_terms():
            inc_id = incoterms_map[term_code]
            for cat in matrix.list_categories():
                ci_id = cost_items_map[cat.key]
                party = matrix.who_pays(term_code, cat.key)
                expected_resp = "Importer" if party == Party.BUYER else "Exporter"
                included = (party == Party.SELLER)
                note = "بند تعاقدي (Contractual)" if not cat.is_icc_defined else None

                existing = self.db.query(IncotermResponsibility).filter(
                    IncotermResponsibility.incoterm_id == inc_id,
                    IncotermResponsibility.cost_item_id == ci_id,
                ).first()

                # Insert-missing only (A12): an existing row may carry user edits of
                # responsible_party / included_in_incoterm / notes, so it is never overwritten.
                if not existing:
                    resp = IncotermResponsibility(
                        incoterm_id=inc_id,
                        cost_item_id=ci_id,
                        responsible_party=expected_resp,
                        included_in_incoterm=included,
                        notes=note
                    )
                    self.db.add(resp)
                    added_resp += 1
        self.db.commit()

        return {
            "incoterms_added": added_incoterms,
            "cost_items_added": added_cost_items,
            "responsibilities_added": added_resp,
            "responsibilities_updated": updated_resp,
        }


    def sync_currencies(self) -> Dict[str, int]:
        """Incremental upsert for Currencies and official Customs Exchange Rates."""
        added_curr = 0
        added_rates = 0

        currencies_data = [
            ("EGP", "Egyptian Pound", "EGP", True),
            ("USD", "US Dollar", "$", False),
            ("EUR", "Euro", "€", False),
            ("CNY", "Chinese Yuan (RMB)", "¥", False),
            ("GBP", "British Pound", "£", False),
            ("AED", "UAE Dirham", "AED", False),
            ("SAR", "Saudi Riyal", "SAR", False),
            ("JPY", "Japanese Yen", "¥", False),
            ("TRY", "Turkish Lira", "₺", False),
            ("INR", "Indian Rupee", "₹", False),
        ]

        for code, name_en, symbol, is_base in currencies_data:
            existing = self.db.query(Currency).filter(Currency.currency_code == code).first()
            if not existing:
                c = Currency(
                    currency_code=code,
                    currency_name=name_en,
                    currency_symbol=symbol,
                    is_base_currency=is_base,
                    decimal_places=2,
                    is_active=True,
                )
                self.db.add(c)
                added_curr += 1
        self.db.commit()

        # Seed Standard Customs Exchange Rates
        curr_map = {c.currency_code: c.currency_id for c in self.db.query(Currency).all()}
        today = date.today()

        standard_rates = [
            ("USD", 48.50, 48.70),
            ("EUR", 52.80, 53.10),
            ("CNY", 6.75, 6.82),
            ("GBP", 61.50, 62.00),
            ("AED", 13.20, 13.26),
            ("SAR", 12.92, 12.98),
            ("EGP", 1.0, 1.0),
        ]

        for from_code, cust_rate, comm_rate in standard_rates:
            from_id = curr_map.get(from_code)
            if from_id:
                existing = self.db.query(ExchangeRate).filter(
                    ExchangeRate.currency_id == from_id,
                    ExchangeRate.effective_date == today,
                ).first()
                if not existing:
                    rate = ExchangeRate(
                        currency_id=from_id,
                        customs_rate=cust_rate,
                        commercial_rate=comm_rate,
                        effective_date=today,
                        is_active=True,
                    )
                    self.db.add(rate)
                    added_rates += 1
        self.db.commit()

        return {"currencies_added": added_curr, "rates_added": added_rates}

    def sync_customs_tariff_and_fees(self) -> Dict[str, int]:
        """Incremental upsert for Egyptian HS Tariff codes, Nafeza Fee codes, and Trade Agreements."""
        added_tariffs = 0
        added_fees = 0
        added_agreements = 0

        # 1. Essential HS Codes Catalog
        tariffs_data = [
            ("8471.30.00", "Laptops & Portable Computers (أجهزة حاسب آلي محمولة)", 0.0, 14.0, 0.0, 0.0, False, False, True),
            ("8471.50.00", "Desktop Computers & Servers (وحدات معالجة رقمية وحواسب مكتبية)", 0.0, 14.0, 0.0, 0.0, False, False, True),
            ("8517.13.00", "Smartphones & Mobile Devices (هواتف ذكية وأجهزة اتصالات خلوية)", 0.0, 14.0, 0.0, 5.0, True, True, True),
            ("9403.10.00", "Metal Office Furniture (أثاث مكتبي معدني)", 30.0, 14.0, 0.0, 0.0, True, False, True),
            ("9403.30.00", "Wooden Office Furniture (أثاث مكتبي خشبي)", 30.0, 14.0, 0.0, 0.0, True, False, True),
            ("9401.30.00", "Swivel Seats / Office Chairs (مقاعد دوارة)", 30.0, 14.0, 0.0, 0.0, True, False, True),
            ("8415.10.00", "Air Conditioning Machines (أجهزة تكييف الهواء)", 40.0, 14.0, 8.0, 0.0, True, True, True),
            ("8528.52.00", "Computer Monitors & Screens (شاشات عرض حواسب)", 5.0, 14.0, 0.0, 0.0, False, False, True),
            ("3926.90.90", "Plastic Articles & Industrial Components (أصناف لدائن ومصنوعاتها)", 10.0, 14.0, 0.0, 0.0, False, False, True),
            ("7318.15.00", "Steel Screws, Bolts & Nuts (براغي ومسامير صلب)", 5.0, 14.0, 0.0, 0.0, False, False, True),
        ]

        for hs, desc, duty, vat, sched, dev, coo, insp, acid in tariffs_data:
            existing = self.db.query(CustomsTariff).filter(CustomsTariff.hs_code == hs).first()
            if not existing:
                t = CustomsTariff(
                    hs_code=hs,
                    hs_description=desc,
                    customs_duty_rate=duty,
                    vat_rate=vat,
                    schedule_tax_rate=sched,
                    development_fee_rate=dev,
                    import_fee_rate=0.0,
                    customs_service_fee_rate=1.0,
                    requires_coo=coo,
                    requires_inspection=insp,
                    requires_acid=acid,
                    is_active=True,
                )
                self.db.add(t)
                added_tariffs += 1
        self.db.commit()

        # 2. Preferential Trade Agreements
        agreements_data = [
            ("8471.30.00", "Agadir Agreement (اتفاقية أغادير)", "full_duty_exemption", 1.0, "JO,TN,MA"),
            ("8471.30.00", "Egypt-EU Association Agreement (الشراكة الأوروبية)", "full_duty_exemption", 1.0, "DE,FR,IT,ES,NL,BE,PL"),
            ("9403.10.00", "Pan-Arab Free Trade Area (GAFTA)", "full_duty_exemption", 1.0, "SA,AE,KW,QA,BH,OM,JO"),
            ("9403.30.00", "Egypt-Turkey FTA (اتفاقية التجارة الحرة مع تركيا)", "full_duty_exemption", 1.0, "TR"),
        ]

        for hs, name, red_type, red_pct, origs in agreements_data:
            existing = self.db.query(PreferentialAgreement).filter(
                PreferentialAgreement.hs_code == hs,
                PreferentialAgreement.agreement_name == name,
            ).first()
            if not existing:
                a = PreferentialAgreement(
                    hs_code=hs,
                    agreement_name=name,
                    reduction_type=red_type,
                    reduction_percentage=red_pct,
                    origin_countries=origs,
                )
                self.db.add(a)
                added_agreements += 1
        self.db.commit()

        # 3. Nafeza Customs Fee Codes
        fee_codes_data = [
            ("77", "رسم طباعة بيان جمركي موحد", "رسوم النافذة الموحدة", "flat", 150.0),
            ("250", "رسم خدمة فحص ومعاينة بنافذة", "رسوم النافذة الموحدة", "flat", 350.0),
            ("798", "رسم المعاملة الإلكترونية لمنظومة ACID", "رسوم النافذة الموحدة", "flat", 500.0),
            ("60", "رسوم خدمات موانئ ومناولة", "أ.ت.ص", "flat", 200.0),
        ]

        for code, name_ar, grp, calc_type, flat_amt in fee_codes_data:
            existing = self.db.query(FeeCode).filter(FeeCode.code == code).first()
            if not existing:
                f = FeeCode(
                    code=code,
                    name_ar=name_ar,
                    collection_group=grp,
                    calculation_type=calc_type,
                    flat_amount=flat_amt,
                    is_active=True,
                )
                self.db.add(f)
                added_fees += 1
        self.db.commit()

        return {
            "tariffs_added": added_tariffs,
            "fees_added": added_fees,
            "agreements_added": added_agreements,
        }

    def sync_clearance_expenses(self) -> int:
        """Incremental upsert for Egyptian standard customs clearance expense items."""
        added = 0
        expenses_data = [
            ("EXP-CLR-001", "أتعاب تخليص LCL (لكل فاتورة)", "LCL Clearance Fee (Per Invoice)", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Invoice (لكل فاتورة)", "EGP", 1),
            ("EXP-CLR-002", "مصاريف تخليص LCL واحد طن", "LCL Clearance Expenses (1 Ton)", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Ton (لكل طن)", "EGP", 2),
            ("EXP-CLR-003", "مصاريف تخليص LCL لكل طن زيادة", "LCL Extra Ton Clearance Expenses", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Ton (لكل طن إضافي)", "EGP", 3),
            ("EXP-CLR-004", "أتعاب تخليص حاوية 20 قدم (فاتورة)", "20ft FCL Clearance Fee (Per Invoice)", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Invoice (لكل فاتورة)", "EGP", 4),
            ("EXP-CLR-005", "أتعاب تخليص حاوية 40 قدم (فاتورة)", "40ft FCL Clearance Fee (Per Invoice)", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Invoice (لكل فاتورة)", "EGP", 5),
            ("EXP-CLR-006", "مصاريف تخليص حاوية 20 قدم", "20ft FCL Clearance Expenses", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Container (لكل حاوية)", "EGP", 6),
            ("EXP-CLR-007", "مصاريف تخليص حاوية 40 قدم", "40ft FCL Clearance Expenses", "Clearance Fees (أتعاب ومصاريف تخليص)", "Per Container (لكل حاوية)", "EGP", 7),
            ("EXP-CLR-008", "مصاريف سحب إذن التسليم", "Delivery Order (D/O) Issuance Expenses", "Official Port & Shipping Line Receipts", "Per B/L (لكل بوليصة)", "EGP", 8),
            ("EXP-CLR-009", "رسوم نافذة وفحص مسبق ACID", "Nafeza Portal & Pre-Clearance Fees", "Official Port & Shipping Line Receipts", "Per Declaration", "EGP", 9),
            ("EXP-CLR-010", "أرضيات ومناولة محطة الحاويات (THC)", "Terminal Storage & Handling Charges", "Port Handling & Storage", "Per Container", "EGP", 10),
        ]

        for code, name_ar, name_en, cat, unit, curr, order in expenses_data:
            existing = self.db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_code == code).first()
            if not existing:
                e = ClearanceExpenseType(
                    expense_code=code,
                    name_ar=name_ar,
                    name_en=name_en,
                    category=cat,
                    default_unit=unit,
                    default_currency=curr,
                    display_order=order,
                    is_active=True,
                )
                self.db.add(e)
                added += 1
        self.db.commit()
        return added

    def sync_shipping_lines(self) -> int:
        """Incremental upsert for core international shipping lines."""
        from modules.external_service_providers.model import ExternalServiceProvider

        shipping_lines_data = [
            ("MSC (Mediterranean Shipping Company)", "MSCU", "https://www.msc.com/en/track-a-shipment", "https://www.msc.com", "egy-info@msc.com", None, "+20 2 2414 8000 / +20 3 488 4000", "Heliopolis, Cairo / Sultan Hussein St., Alexandria", "Egypt"),
            ("Maersk Line (A.P. Moller - Maersk)", "MAEU", "https://www.maersk.com/tracking/", "https://www.maersk.com", "egycs@maersk.com", None, "+20 2 2413 8000 / +20 3 487 0000", "Cairo / Alexandria / Port Said", "Egypt"),
            ("CMA CGM Group", "CMDU", "https://www.cma-cgm.com/ebusiness/tracking", "https://www.cma-cgm.com", "cai.genmbox@cma-cgm.com", None, "+20 2 2269 5000 / +20 3 488 2000", "Heliopolis, Cairo / Alexandria", "Egypt"),
            ("Hapag-Lloyd AG", "HLCU", "https://www.hapag-lloyd.com/en/online-business/track/track-by-booking-solution.html", "https://www.hapag-lloyd.com", "egypt@hlag.com", None, "+20 2 2696 4500", "Citystars Complex, Building 3, Heliopolis, Cairo", "Egypt"),
            ("Ocean Network Express (ONE)", "ONEY", "https://ecomm.one-line.com/one-ecom/manage-shipment/cargo-tracking", "https://www.one-line.com", "eg.customercare@one-line.com", None, "+20 2 2413 5400", "94 Al Marghany St., Heliopolis, Cairo", "Egypt"),
            ("COSCO SHIPPING Lines", "COSU", "https://elines.coscoshipping.com/ebusiness/cargoTracking", "https://lines.coscoshipping.com", "cs.egypt@coscon.com", None, "+20 2 2417 8100 / +20 3 487 5500", "47 Ramsis St., Downtown / 27 Sultan Hussein St., Alexandria", "Egypt"),
            ("China United Lines Ltd. (CULines)", "CULI", "https://www.culines.com/en/site/tracking", "https://www.culines.com", "booking@culines.com", None, None, "Shanghai Head Office / Local Liner Agent Egypt", "Egypt"),
            ("Emirates Shipping Line (ESL)", "ESLU", "https://www.emiratesline.com/tracking/", "https://www.emiratesline.com", "egypt.sales@emiratesline.com", None, "+20 2 2418 0700", "Heliopolis, Cairo", "Egypt"),
            ("Evergreen Marine Corp.", "EGLV", "https://www.shipmentlink.com/servlet/TTrk_Show", "https://www.evergreen-marine.com", "egyn-biz@evergreen-shipping.com.eg", None, "+20 2 2268 4000 / +20 3 487 7700", "11 El-Bustan St., Downtown, Cairo / Sultan Hussein St., Alexandria", "Egypt"),
            ("Yang Ming Marine Transport Corp.", "YMLU", "https://www.yangming.com/e-service/Track_Trace/track_trace.aspx", "https://www.yangming.com", "cs@yangming.com.eg", None, "+20 2 2414 7700 / +20 3 484 2200", "Heliopolis, Cairo / Alexandria", "Egypt"),
            ("ZIM Integrated Shipping Services Ltd.", "ZIMU", "https://www.zim.com/tools/track-a-shipment", "https://www.zim.com", "customer-service@zim.com", None, "+20 3 481 1200", "Alexandria / Cairo (Liner Agency Representation)", "Egypt"),
            ("Wan Hai Lines Ltd.", "WHLC", "https://www.wanhai.com/views/cargoTrack/CargoTracking.xhtml", "https://www.wanhai.com", "egypt_sales@wanhai.com", None, "+20 2 2269 0000", "Heliopolis, Cairo", "Egypt"),
            ("Pacific International Lines (Pte) Ltd (PIL)", "PCIU", "https://www.pilship.com/en-our-track-and-trace/120.html", "https://www.pilship.com", "egypt.cs@cai.pilship.com", None, "+20 2 2268 9000 / +20 3 487 0000", "Nasr City, Cairo / Alexandria", "Egypt"),
            ("HMM Co., Ltd. (Hyundai Merchant Marine)", "HDMU", "https://www.hmm21.com/cms/business/ebiz/trackTrace/trackTrace/index.jsp", "https://www.hmm21.com", "egycs@hmm21.com", None, "+20 2 2418 8800", "Sheraton Heliopolis, Cairo", "Egypt"),
            ("Tarros Line (Tarros Egypt Shipping Agency)", "GETU", "https://www.tarros.it/en/shipment-tracking/", "https://www.tarros.it", "info@tarros.com.eg", None, "+20 3 487 9000 / +20 2 2417 5000", "12 Salah Salem St., Alexandria / Heliopolis, Cairo", "Egypt"),
            ("Arkas Line (Arkas Egypt S.A.E.)", "ARKU", "https://www.arkasline.com.tr/en/tracking", "https://www.arkasline.com.tr", "egypt.cs@arkas-egypt.com", None, "+20 2 2269 8888 / +20 3 488 5555", "47 Ramses St., Heliopolis, Cairo / 22 Dr. Mostafa Mosharafa St., Alexandria", "Egypt"),
            ("Orient Overseas Container Line (OOCL)", "OOLU", "https://www.oocl.com/eng/ourservices/eservices/cargotracking/Pages/cargotracking.aspx", "https://www.oocl.com", "caiibcsv@oocl.com", "alexibcsv@oocl.com", "+20 2 2414 4000 / +20 3 487 3500", "12 Hassan Allam St., Heliopolis, Cairo / Alexandria", "Egypt"),
            ("Korea Marine Transport Co., Ltd. (KMTC Line)", "KMTC", "https://www.ekmtc.com/", "https://www.ekmtc.com", "kmtcegypt@kmtc.co.kr", None, "+20 2 2269 1100", "Heliopolis, Cairo", "Egypt"),
            ("SeaLead Shipping", "SEAU", "https://sea-lead.com/tracking/", "https://sea-lead.com", "egypt@sea-lead.com", None, "+20 2 2417 6000", "Sheraton, Cairo", "Egypt"),
            ("Grimaldi Group (Grimaldi Lines)", "GRIU", "https://www.grimaldi.napoli.it/en/cargo_tracking.html", "https://www.grimaldi.napoli.it", "info@grimaldi.napoli.it", None, "+20 3 487 1234", "Alexandria Port Area / Cairo Office", "Egypt"),
            ("SITC Container Lines Co., Ltd.", "SITC", "https://www.sitc.com/en/tracking.html", "https://www.sitc.com", "info@sitc.com", None, "+20 2 2268 7700", "Qingdao / Shanghai, China", "China"),
            ("Ignazio Messina & C. S.p.A.", "LMCU", "https://www.messinaline.it/tracking/", "https://www.messinaline.it", "alexandria@messinaline.it", None, "+20 3 486 9900", "Alexandria Port Area", "Egypt"),
            ("Turkon Container Transportation & Shipping", "TRKU", "https://www.turkon.com/en/tracking", "https://www.turkon.com", "turkonline@turkon.com", None, "+20 3 487 6622", "Alexandria / Cairo", "Egypt"),
            ("Pan Marine Shipping Services", "PMRS", "https://www.pan-marine.net/", "https://www.pan-marine.net", "shipping@pan-marine.net", "logistics@pan-marine.net", "+20 3 487 7750 / +20 100 178 8800", "12 Al-Bostan St., Downtown / 9 Al-Ferdaws St., Smouha, Alexandria", "Egypt"),
            ("Diamond Line GmbH", "DIAL", "https://www.diamondline.de/", "https://www.diamondline.de", "info@diamondline.de", "cs.egypt@coscon.com", "+20 2 2417 8100 / +20 3 487 5500", "47 Ramses St., Heliopolis, Cairo / 27 Sultan Hussein St., Alexandria", "Egypt"),
            ("Borchard Lines Ltd", "BORU", "https://www.borchardlines.com/tracking/", "https://www.borchardlines.com", "egypt@borchardlines.com", None, "+20 3 487 4000", "Alexandria / Port Said", "Egypt"),
            ("Shanghai Zhonggu Logistics Co., Ltd.", "ZGSC", "https://www.zhonggushipping.com/", "https://www.zhonggushipping.com", "service@zhonggushipping.com", None, None, "Shanghai, China", "China"),
            ("Antong Holdings Co., Ltd. (Quanzhou Anji Shipping)", "QASU", "http://www.antong56.com/", "http://www.antong56.com", "sales@antong56.com", None, None, "Quanzhou, Fujian / Shanghai, China", "China"),
            ("Sinotrans Container Lines Co., Ltd. (Sinolines)", "SNTN", "https://www.sinolines.com/track/", "https://www.sinolines.com", "sinolines@sinotrans.com", None, None, "Beijing / Shanghai, China", "China"),
            ("Shanghai Jin Jiang Shipping (Group) Co., Ltd.", "JJSC", "https://www.jinjiangshipping.com/", "https://www.jinjiangshipping.com", "service@jinjiangshipping.com", None, None, "Shanghai, China", "China"),
            ("Taicang Container Lines Co., Ltd. (TCL)", "TCIU", "http://www.tcl-line.com/", "http://www.tcl-line.com", "booking@tcl-line.com", None, None, "Jiangsu / Taicang, China", "China"),
        ]

        existing_scacs = {p.scac_code for p in self.db.query(ExternalServiceProvider.scac_code).filter(ExternalServiceProvider.scac_code.isnot(None)).all()}
        max_idx = self.db.query(ExternalServiceProvider).count()
        added = 0

        for name, scac, track_url, web, mail, sec_mail, ph, addr, ctry in shipping_lines_data:
            if scac not in existing_scacs:
                max_idx += 1
                self.db.add(ExternalServiceProvider(
                    partner_code=f"ESP-{max_idx:06d}",
                    partner_name=name,
                    partner_type="Shipping Line",
                    scac_code=scac,
                    tracking_url=track_url,
                    website=web,
                    email=mail,
                    secondary_email=sec_mail,
                    phone=ph,
                    address=addr,
                    country=ctry,
                    payment_type="Credit",
                    credit_limit=0.0,
                    rating=5.0,
                    is_active=True,
                    created_by="SYSTEM_SEED",
                ))
                existing_scacs.add(scac)
                added += 1
        if added > 0:
            self.db.commit()
        return added

    def sync_expense_catalog(self) -> Dict[str, int]:
        """
        Incremental non-destructive upsert for Coded Reference Expense Catalog (AI-EXPENSE-CATALOG-002).
        Preserves existing user-added patterns while ensuring canonical codes exist.
        """
        from modules.expense_catalog.model import ExpenseCatalog
        from modules.expense_catalog.seed_data import EXPENSE_CATALOG_SEED_DATA

        added = 0
        updated = 0

        for item in EXPENSE_CATALOG_SEED_DATA:
            code = item["code"].strip().upper()
            existing = self.db.query(ExpenseCatalog).filter(ExpenseCatalog.code == code).first()
            if not existing:
                cat_obj = ExpenseCatalog(
                    code=code,
                    canonical_name_ar=item["canonical_name_ar"],
                    canonical_name_en=item.get("canonical_name_en"),
                    category=item["category"],
                    unit_type=item.get("unit_type", "fixed"),
                    allow_composite=item.get("allow_composite", False),
                    recognition_patterns=list(item.get("recognition_patterns", [])),
                    is_active=True,
                )
                self.db.add(cat_obj)
                added += 1
            else:
                # Merge any missing recognition patterns
                cur_patterns = list(existing.recognition_patterns or [])
                changed = False
                for p in item.get("recognition_patterns", []):
                    if p not in cur_patterns:
                        cur_patterns.append(p)
                        changed = True
                if changed:
                    existing.recognition_patterns = cur_patterns
                    updated += 1

        if added > 0 or updated > 0:
            self.db.commit()
        return {"added": added, "updated": updated}

    def sync_experience_guide_seeds(self) -> Dict[str, Any]:
        """Ensures default high-value logistics & customs rules exist in the Experience Guide."""
        added = 0
        acoustic_title = "صنف الأكوستيك — اشتراطات فحص وإلزامية ميناء"
        existing = self.db.query(GuideEntry).filter(GuideEntry.title == acoustic_title).first()
        if not existing:
            entry = GuideEntry(
                title=acoustic_title,
                content="يجب أن يكون ميناء الوصول الإسكندرية حصراً لوجود معامل فحص متخصصة. مطلوب شهادة منشأ أصلية مصدقة ومرفقة قبل الشحن لتفادي التحفظ الجمركي أو فرض غرامات تأخير.",
                entry_type="required_document",
                severity="critical",
                created_by="System Seed",
                is_active=True,
            )
            self.db.add(entry)
            self.db.flush()
            scope = GuideEntryScope(
                guide_entry_id=entry.entry_id,
                scope_type="hs_code",
                scope_value="8520",
            )
            self.db.add(scope)
            added += 1
            self.db.commit()

        return {"added": added}

    def sync_all(self) -> Dict[str, Any]:
        """Runs complete master data non-destructive synchronization across all reference domains."""
        users_added = self.sync_system_users()
        incoterms_res = self.sync_incoterms()
        currencies_res = self.sync_currencies()
        customs_res = self.sync_customs_tariff_and_fees()
        clearance_added = self.sync_clearance_expenses()
        shipping_lines_added = self.sync_shipping_lines()
        rbac_res = seed_rbac(self.db)
        expense_catalog_res = self.sync_expense_catalog()
        guide_res = self.sync_experience_guide_seeds()

        return {
            "status": "synchronized_cleanly",
            "users_added": users_added,
            "incoterms": incoterms_res,
            "currencies": currencies_res,
            "customs": customs_res,
            "clearance_expenses_added": clearance_added,
            "shipping_lines_added": shipping_lines_added,
            "rbac": rbac_res,
            "expense_catalog": expense_catalog_res,
            "experience_guide": guide_res,
        }

