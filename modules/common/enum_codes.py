"""
Tier-3 enum codes (single-language storage).

Values picked from fixed lists are stored as UPPER_SNAKE codes (currency as ISO ``EGP``). The UI renders a
localized label per code. Requests may still send a legacy label (Arabic, English or the mixed
"English (Arabic)" / "English / Arabic" forms old clients use): ``normalize`` maps it to the code before
saving. Unknown values are returned unchanged, because these fields were open text before and must not
start failing with 422.

The English label of each code is ``LABELS_EN[type][code]``; Flutter holds its own ar/en label maps
(``frontend/lib/core/localization/domain_enum_labels.dart``) and the same legacy reverse maps.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

CONTRACT_PATH = Path(__file__).resolve().parents[2] / "docs" / "enum_codes.json"

# ── Enum types ──────────────────────────────────────────────────────────────────
RELEASE_TYPE = "RELEASE_TYPE"
PAYMENT_METHOD = "PAYMENT_METHOD"
DUTY_BANK = "DUTY_BANK"
CLEARANCE_EXPENSE_CATEGORY = "CLEARANCE_EXPENSE_CATEGORY"
TRUCK_TYPE = "TRUCK_TYPE"
REGULATORY_BODY = "REGULATORY_BODY"
CLEARANCE_QUOTE_SERVICE_CATEGORY = "CLEARANCE_QUOTE_SERVICE_CATEGORY"
BROKER_EXPENSE_CATEGORY = "BROKER_EXPENSE_CATEGORY"
PRICING_UNIT = "PRICING_UNIT"
EMPTY_CONTAINER_DEPOT = "EMPTY_CONTAINER_DEPOT"
SKIP_REASON_CATEGORY = "SKIP_REASON_CATEGORY"
HOLD_REASON = "HOLD_REASON"
STAGE = "STAGE"
PHASE_FOLLOW_UP_TASK = "PHASE_FOLLOW_UP_TASK"
INSPECTION_YARD = "INSPECTION_YARD"
CUSTOMS_CHANNEL = "CUSTOMS_CHANNEL"
INSPECTION_RESULT = "INSPECTION_RESULT"
REQUIREMENT_STATUS = "REQUIREMENT_STATUS"
WAREHOUSE_INSPECTION_VERDICT = "WAREHOUSE_INSPECTION_VERDICT"
DB_HEALTH_VERDICT = "DB_HEALTH_VERDICT"
ALERT_SEVERITY = "ALERT_SEVERITY"
LANDED_COST_VARIANCE_STATUS = "LANDED_COST_VARIANCE_STATUS"
CUSTOMS_CATEGORY = "CUSTOMS_CATEGORY"
VALUE_PLACEHOLDER = "VALUE_PLACEHOLDER"
MEASURE_UNIT = "MEASURE_UNIT"

# code -> English label, per enum type (insertion order = display order)
LABELS_EN: Dict[str, Dict[str, str]] = {
    RELEASE_TYPE: {
        "FINAL_GREEN": "Final Green Release",
        "UNDER_BOND": "Under-Bond Release",
        "TEMPORARY_ADMISSION": "Temporary Admission",
        "POST_TESTING_CONFORMING": "Post-Testing Conforming Release",
    },
    PAYMENT_METHOD: {
        "SADAD_EFINANCE": "E-Finance / Sadad",
        "BANK_TRANSFER": "Bank Transfer",
        "CBE_DIRECT": "CBE Direct Debit",
        "CASHIER_DEPOSIT": "Customs Cashier Deposit",
    },
    DUTY_BANK: {
        "NBE": "National Bank of Egypt (NBE)",
        "BM": "Banque Misr (BM)",
        "CIB": "Commercial International Bank (CIB)",
        "BDC": "Banque du Caire (BDC)",
        "QNB": "QNB Alahli (QNB)",
        "CBE": "Central Bank of Egypt (CBE)",
        "MTS_CASHIER": "Customs Authority Cashier (MTS)",
        "OTHER": "Other",
    },
    CLEARANCE_EXPENSE_CATEGORY: {
        # Codes keep the English keywords (broker / port / storage / handling / clearance) that
        # customs_clearance aggregates match by substring.
        "BROKER_FEES": "Customs Broker Fees",
        "PORT_DUES_WHARFAGE": "Port Dues & Wharfage",
        "STEVEDORING_HANDLING": "Stevedoring & Handling",
        "INSPECTION_WEIGHING": "Inspection & Weighing",
        "LABORATORY_TESTING": "Laboratory & Testing Fees",
        "STORAGE_DEMURRAGE": "Storage & Demurrage",
        "OTHER_CLEARANCE": "Other Clearance Expenses",
    },
    TRUCK_TYPE: {
        "FLATBED": "Flatbed Trailer",
        "SIDE_DROP": "Side-Drop Trailer",
        "CURTAINSIDER": "Curtainsider",
        "CONTAINER_CHASSIS": "Container Chassis (20/40 ft)",
        "BOX_TRUCK": "Box Truck",
        "REEFER": "Reefer Truck",
        "LOW_BED": "Heavy Low-bed",
    },
    REGULATORY_BODY: {
        "GOEIC": "General Organization for Export & Import Control (GOEIC)",
        "NFSA": "National Food Safety Authority (NFSA)",
        "NTRA": "National Telecom Regulatory Authority (NTRA)",
        "CHEMISTRY_DEPT": "Chemistry Administration",
        "QUARANTINE": "Agricultural / Veterinary Quarantine",
        "AGRICULTURAL_QUARANTINE": "Agricultural Quarantine",
        "VETERINARY_QUARANTINE": "Veterinary Quarantine",
        "EDA": "Egyptian Drug Authority (EDA)",
        "INDUSTRIAL_CONTROL": "Industrial Control Authority",
        "ATOMIC_ENERGY": "Radiation Protection / Atomic Energy Authority",
        "WEIGHTS_MEASURES": "Weights, Measures & Hallmarks Authority",
    },
    CLEARANCE_QUOTE_SERVICE_CATEGORY: {
        "CLEARANCE_FEE": "Clearance Agency Fee",
        "INLAND_TRANSPORT": "Inland Transport",
        "INSPECTION_FEE": "Inspection & Examination Fee",
        "PORT_CHARGES": "Port & Demurrage Charges",
    },
    BROKER_EXPENSE_CATEGORY: {
        "CLEARANCE_FEES": "Clearance Fees",
        "PROCEDURES_APPROVALS": "Procedures & Approvals",
        "INLAND_TRANSPORT": "Inland Transport",
        "PORT_HANDLING": "Port & Handling",
        "OFFICIAL_RECEIPTS": "Official Port & Shipping Line Receipts",
        "OTHER_FEES": "Other Fees",
    },
    PRICING_UNIT: {
        "FIXED": "Fixed",
        "PER_INVOICE": "Per Invoice",
        "PER_TON": "Per Ton",
        "PER_EXTRA_TON": "Per Extra Ton",
        "PER_CONTAINER": "Per Container",
        "PER_CONTAINER_20FT": "Per Container 20ft",
        "PER_CONTAINER_40FT": "Per Container 40ft",
        "PER_TRUCK": "Per Truck",
        "PER_VEHICLE": "Per Vehicle",
        "PER_TRIP": "Per Trip",
        "PER_DAY": "Per Day",
        "PER_NIGHT": "Per Night",
        "PER_SHIPMENT": "Per Shipment",
        "PER_DECLARATION": "Per Declaration",
        "PER_BL": "Per B/L",
        "PER_INSPECTION": "Per Inspection",
        "PER_CASE": "Per Case",
        "PER_SAMPLE": "Per Sample",
        "PER_TRAILER": "Per Trailer",
        "RANGE": "Range",
    },
    EMPTY_CONTAINER_DEPOT: {
        "ALEXANDRIA_CARRIER_DEPOT": "Alexandria Port Carrier Depot",
        "DEKHEILA_YARD": "Dekheila Yard",
        "SOKHNA_LOGISTICS_DEPOT": "Sokhna Logistics Depot",
        "PORT_SAID_WEST_DEPOT": "Port Said West Depot",
        "DAMIETTA_EMPTY_YARD": "Damietta Port Empty Yard",
        "SOKHNA_DP_WORLD_YARD": "Ain Sokhna DP World Yard",
    },
    SKIP_REASON_CATEGORY: {
        "CLIENT_AGREEMENT": "Client Agreement",
        "NOT_APPLICABLE_TO_MODE": "Not Applicable to Mode",
        "REGULATORY_EXEMPTION": "Regulatory Exemption",
        "OTHER": "Other",
    },
    HOLD_REASON: {
        "AWAITING_SUPPLIER_APPROVAL": "Awaiting foreign supplier approval",
        "DRAFT_BL_AMENDMENT": "Requested amendment on draft B/L",
        "AWAITING_BANK_FORM4": "Awaiting bank Form 4 issuance",
        "PENDING_REGULATORY_APPROVAL": "Pending regulatory authority approval",
        "BOOKING_DELAYED": "Shipping line booking delayed",
        "TARIFF_VALUATION_REVIEW": "Customs tariff valuation review",
        "ADDITIONAL_INSPECTION": "Additional physical inspection required",
        "ADMIN_HOLD": "Temporary administrative hold",
        "OTHER": "Other",
    },
    STAGE: {
        # Lifecycle phases (rendered from PHASES_DEFINITION title_en)...
        "PHASE_1": "1. Pre-Planning & Studies",
        "PHASE_2": "2. Shipment Initiation",
        "PHASE_3": "3. Booking & Doc Prep",
        "PHASE_4": "4. Digital & Banking",
        "PHASE_5": "5. Port Operations & Clearance",
        "PHASE_6": "6. Inbound & Final Closure",
        # ...and special stages that are not a phase.
        "DRAFT": "Draft",
        "CUSTOMS_BROKER_AUTHORIZED": "Customs Broker Authorized",
        "DELIVERY_ORDER_PAID": "Delivery Order Paid & Received",
        "UNDER_CUSTOMS_CLEARANCE": "Under Customs Clearance",
        "CUSTOMS_INSPECTION_COMPLETED": "Customs Inspection & Sampling Completed",
        "CUSTOMS_DUTY_ASSESSED": "Customs Duty Assessed",
        "DUTY_PAID": "Duty Paid",
        "CUSTOMS_RELEASED": "Customs Released",
        "UNDER_BOND_QUARANTINE": "Under-Bond Quarantine",
        "LAB_APPROVED_RELEASED": "Lab Approved & Final Released",
        "LAB_REJECTED": "Lab Rejected",
        "INLAND_TRANSPORT_BOOKED": "Inland Transport Booked",
        "IN_TRANSIT_TO_WAREHOUSE": "In Transit to Warehouse",
        "ARRIVED_AT_WAREHOUSE": "Arrived at Warehouse",
        "GOODS_RECEIVED": "Goods Received",
        "QC_PASSED": "QC Passed - Ready for Landed Cost",
        "QUARANTINED_UNDER_INSPECTION": "Quarantined under Inspection",
        "DISCREPANCY_PROTOCOL_FILED": "Discrepancy Protocol Filed",
        "LANDED_COST_CALCULATED": "Landed Cost Calculated",
        "CLOSURE_IN_PROGRESS": "Closure In-Progress",
        "ARCHIVED_CLOSED": "Archived & Closed",
        "CLOSED_EARLY": "Closed Early",
        "REOPENED": "Reopened",
    },
    INSPECTION_YARD: {
        "ALEXANDRIA_BERTH_42": "Joint Inspection Yard - Alexandria Port (Berth 42)",
        "DEKHEILA": "Joint Inspection Yard - Dekheila Port",
        "AIN_SOKHNA": "Joint Inspection Yard - Ain Sokhna Port",
        "DAMIETTA": "Inspection Yard - Damietta Port",
        "WEST_PORT_SAID": "Inspection Yard - West Port Said Port",
        "EAST_PORT_SAID": "Customs Inspection Yard - East Port Said Port",
        "OCTOBER_DRY_PORT": "Joint Inspection Yard - 6th of October Dry Port",
        "TENTH_RAMADAN_DRY_PORT": "Inspection Yard - 10th of Ramadan Dry Port",
        "CAIRO_AIRPORT_CARGO": "Cargo Village - Cairo International Airport",
        "ADABIYA": "Joint Inspection Yard - Adabiya Port (Suez)",
    },
    PHASE_FOLLOW_UP_TASK: {
        "FREIGHT_SCENARIO_FOLLOW_UP": "Follow up freight studies, scenarios and line availability",
        "PAYMENT_BUDGET_FOLLOW_UP": "Follow up the financial approval and the payment release",
        "NAFEZA_ACID_FOLLOW_UP": "Follow up the Nafeza registration and the ACID number",
        "BOOKING_BL_FOLLOW_UP": "Follow up the booking, container stuffing and B/L confirmation",
        "CARGOX_DOCUMENT_TRANSFER": "Receive the commercial invoice and transfer documents via CargoX",
        "ARRIVAL_NOTICE_DECLARATION_46": "Follow up the arrival notice and register declaration 46",
        "BROKER_RELEASE_FOLLOW_UP": "Execute the broker's notes and obtain the final release",
        "WAREHOUSE_GRN_REVIEW": "Review cargo integrity, warehouse receiving and the GRN",
        "LANDED_COST_SETTLEMENT": "Settle the landed cost engine and allocate expenses",
        "ARCHIVE_REVIEW": "Review archiving conditions and close the historical file",
    },
    CUSTOMS_CHANNEL: {
        "RED": "Red Channel",
        "YELLOW": "Yellow Channel",
        "GREEN": "Green Channel",
    },
    INSPECTION_RESULT: {
        "CONFORMING": "Conforming",
        "SHORTAGE": "Shortage",
        "SURPLUS": "Surplus",
        "DISCREPANCY": "Discrepancy",
    },
    REQUIREMENT_STATUS: {
        "NOT_REQUIRED": "Not Required",
        "PENDING": "Pending",
        "APPLIED": "Applied",
        "IN_PROGRESS": "In Progress",
        "RECEIVED": "Received",
        "OBTAINED": "Obtained",
        "VERIFIED": "Verified",
        "APPROVED": "Approved",
        "COMPLETED": "Completed",
        "REJECTED": "Rejected",
        "EXPIRED": "Expired",
    },
    WAREHOUSE_INSPECTION_VERDICT: {
        "PENDING": "Pending",
        "ACCEPTED_FULL": "Accepted in full",
        "ACCEPTED_WITH_DISCREPANCY": "Accepted with discrepancy",
        "REJECTED_QUARANTINED": "Rejected / quarantined",
        "DAMAGE_CLAIM_PENDING": "Damage claim pending",
    },
    DB_HEALTH_VERDICT: {
        "HEALTHY": "Healthy",
        "DEGRADED": "Degraded",
        "CRITICAL": "Critical",
    },
    ALERT_SEVERITY: {
        "INFO": "Info",
        "WARNING": "Warning",
        "HIGH": "High",
        "CRITICAL": "Critical",
    },
    LANDED_COST_VARIANCE_STATUS: {
        "UNDER_BUDGET": "Under budget",
        "ON_BUDGET": "On budget",
        "OVER_BUDGET": "Over budget",
    },
    # customs_tariff.customs_category (free text before; unknown values still pass through)
    CUSTOMS_CATEGORY: {
        "MACHINERY_EQUIPMENT": "Machinery, appliances & equipment",
        "GENERAL_GOODS": "General goods",
        "ELECTRONICS": "Electronics",
        "AUTOMOTIVE": "Automotive",
        "AUTOMOTIVE_SPARE_PARTS": "Automotive Spare Parts",
        "TELECOMMUNICATIONS": "Telecommunications",
        "INDUSTRIAL_MACHINERY": "Industrial Machinery",
        "TEXTILES": "Textiles",
        "RAW_MATERIALS_METALS": "Raw Materials & Metals",
        "PHARMACEUTICALS": "Pharmaceuticals",
        "FOOD_AGRICULTURAL": "Food & Agricultural",
        "PLASTICS_POLYMERS": "Plastics & Polymers",
    },
    # Placeholder shown instead of a value in document comparison items (structured_values[].placeholder)
    VALUE_PLACEHOLDER: {
        "NOT_SET": "Not set in the system",
        "NOT_IN_DOCUMENT": "Not found in the document",
        "NOT_IN_INVOICE": "Not stated in the invoice",
        "NOT_IN_PACKING_LIST": "Not included in the packing list",
        "NOT_EXTRACTED": "Not extracted",
        "OPTIONAL_NOT_INCLUDED": "Optional / not included",
        "NOT_IN_BL": "Not found in the B/L",
        "NOT_SPECIFIED": "Not specified",
    },
    # Unit of a numeric value in document comparison items (structured_values[].unit)
    MEASURE_UNIT: {
        "PACKAGES": "packages",
        "KG": "kg",
        "CBM": "CBM",
        "PACKAGES_PALLETS": "packages/pallets",
    },
}

# Legacy labels exactly as older clients / defaults sent them -> code.
_LEGACY: Dict[str, Dict[str, str]] = {
    RELEASE_TYPE: {
        "نهائي وبات (Final Green Release)": "FINAL_GREEN",
        "إفراج مؤقت تحت التحفظ (Under-Bond Release)": "UNDER_BOND",
        "إفراج برسم السماح المؤقت (Temporary Admission)": "TEMPORARY_ADMISSION",
        "إفراج قطعي بعد استيفاء العينات (Post-Testing Conforming Release)": "POST_TESTING_CONFORMING",
        "نهائي وبات": "FINAL_GREEN",
    },
    PAYMENT_METHOD: {
        "E-Finance / Sadad": "SADAD_EFINANCE",
        "Sadad / E-Finance": "SADAD_EFINANCE",
        "Bank Transfer / تحويل بنكي": "BANK_TRANSFER",
        "CBE Direct / خصم البنك المركزي": "CBE_DIRECT",
        "Cashier Deposit / إيداع خزينة الجمرك": "CASHIER_DEPOSIT",
        "Sadad": "SADAD_EFINANCE",
        "E-Finance": "SADAD_EFINANCE",
    },
    DUTY_BANK: {
        "البنك الأهلي المصري (NBE)": "NBE",
        "بنك مصر (BM)": "BM",
        "البنك التجاري الدولي (CIB)": "CIB",
        "بنك القاهرة (BDC)": "BDC",
        "بنك قطر الوطني الأهلي (QNB)": "QNB",
        "البنك المركزي المصري (CBE)": "CBE",
        "خزينة مصلحة الجمارك (MTS Cashier)": "MTS_CASHIER",
        "أخرى": "OTHER",
    },
    CLEARANCE_EXPENSE_CATEGORY: {
        "Customs Broker Fees (أتعاب التخليص الجمركي)": "BROKER_FEES",
        "Port Dues & Wharfage (نولون ورسوم الميناء والرصيف)": "PORT_DUES_WHARFAGE",
        "Stevedoring & Handling (مصاريف العتالة والشحن والتفريغ)": "STEVEDORING_HANDLING",
        "Inspection & Weighing (رسوم الفحص والوزن والمعاينة)": "INSPECTION_WEIGHING",
        "Laboratory & Testing Fees (مصاريف التحاليل والمعامل)": "LABORATORY_TESTING",
        "Storage & Demurrage (رسوم الأرضيات وغرامات التأخير)": "STORAGE_DEMURRAGE",
        "Other Clearance Expenses (مصاريف تخليص أخرى)": "OTHER_CLEARANCE",
    },
    TRUCK_TYPE: {
        "Flatbed Trailer (تريلا مسطح)": "FLATBED",
        "Side-Drop Trailer (تريلا جوانب)": "SIDE_DROP",
        "Curtainsider (تريلا ستارة)": "CURTAINSIDER",
        "Container Chassis (شاسية حاوية 40/20 قدم)": "CONTAINER_CHASSIS",
        "Box Truck (جامبو مغلق)": "BOX_TRUCK",
        "Reefer Truck (شاحنة مبردة)": "REEFER",
        "Heavy Low-bed (لوبد ثقيل للطرود الضخمة)": "LOW_BED",
    },
    REGULATORY_BODY: {
        "الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)": "GOEIC",
        "الهيئة القومية لسلامة الغذاء (NFSA)": "NFSA",
        "الجهاز القومي لتنظيم الاتصالات (NTRA)": "NTRA",
        "مصلحة الكيمياء (Chemistry Dept)": "CHEMISTRY_DEPT",
        "مصلحة الكيمياء المصرية (Chemistry Dept)": "CHEMISTRY_DEPT",
        "الحجر الزراعي / البيطري (Quarantine)": "QUARANTINE",
        "الحجر الزراعي المصري": "AGRICULTURAL_QUARANTINE",
        "الحجر البيطري": "VETERINARY_QUARANTINE",
        "هيئة الدواء المصرية (EDA)": "EDA",
        "مصلحة الرقابة الصناعية": "INDUSTRIAL_CONTROL",
        "إدارة الوقاية الإشعاعية وهيئة الطاقة الذرية": "ATOMIC_ENERGY",
        "مصلحة الموازين والدمغة": "WEIGHTS_MEASURES",
        "Food Safety Authority": "NFSA",
        "Food Safety": "NFSA",
        "Chemistry Dept": "CHEMISTRY_DEPT",
        "Radiation": "ATOMIC_ENERGY",
        "Chemistry": "CHEMISTRY_DEPT",
    },
    CLEARANCE_QUOTE_SERVICE_CATEGORY: {
        "أتعاب التخليص الجمركي": "CLEARANCE_FEE",
        "النقل الداخلي": "INLAND_TRANSPORT",
        "مصاريف الفحص والعرض": "INSPECTION_FEE",
        "رسوم ومصاريف الموانئ": "PORT_CHARGES",
        "Clearance Fee": "CLEARANCE_FEE",
        "Clearance Agency Fee": "CLEARANCE_FEE",
        "Inspection & Examination Fee": "INSPECTION_FEE",
        "Port & Demurrage Charges": "PORT_CHARGES",
    },
    BROKER_EXPENSE_CATEGORY: {
        "Clearance Fees (أتعاب ومصاريف تخليص)": "CLEARANCE_FEES",
        "Procedures & Approvals (إجراءات وموافقات وفحص)": "PROCEDURES_APPROVALS",
        "Inland Transport (نقل بري وشاحنات)": "INLAND_TRANSPORT",
        "Port & Handling (موانئ وتعتيق وتفريغ)": "PORT_HANDLING",
        "Other Fees (مصاريف أخرى)": "OTHER_FEES",
        "Official Port & Shipping Line Receipts": "OFFICIAL_RECEIPTS",
        "Port Handling & Storage": "PORT_HANDLING",
        "أتعاب ومصاريف تخليص": "CLEARANCE_FEES",
    },
    PRICING_UNIT: {
        # Every unit label written by seeds (seed_clearance_expenses.py, master_data_sync_service.py) and the
        # broker quotation extractor (smart_document_upload/extractors/customs_broker_quotation.py).
        "Fixed (مبلغ ثابت)": "FIXED",
        "Fixed Amount": "FIXED",
        "Per Case (لكل حالة)": "PER_CASE",
        "Per Case (لكل عرض)": "PER_CASE",
        "Per Container (لكل حاوية إضافية)": "PER_CONTAINER",
        "Per Container (لكل نقلة وزن)": "PER_CONTAINER",
        "Per Inspection (لكل عرض)": "PER_INSPECTION",
        "Per Inspection (لكل كشف)": "PER_INSPECTION",
        "Per Night (لكل ليلة)": "PER_NIGHT",
        "Per Sample (لكل إجراء)": "PER_SAMPLE",
        "Per Sample (لكل عينة)": "PER_SAMPLE",
        "Per Shipment (لكل إقرار)": "PER_SHIPMENT",
        "Per Shipment (لكل تعتيق)": "PER_SHIPMENT",
        "Per Shipment (لكل شحنة)": "PER_SHIPMENT",
        "Per Shipment (لكل وزن)": "PER_SHIPMENT",
        "Per Trailer (لكل تريلا)": "PER_TRAILER",
        "Per Vehicle (لكل سيارة)": "PER_VEHICLE",
        "Per Invoice (لكل فاتورة)": "PER_INVOICE",
        "Per Ton (لكل طن)": "PER_TON",
        "Per Ton (لكل طن إضافي)": "PER_EXTRA_TON",
        "Per Container (لكل حاوية)": "PER_CONTAINER",
        "Per B/L (لكل بوليصة)": "PER_BL",
        "Per B/L": "PER_BL",
    },
    EMPTY_CONTAINER_DEPOT: {
        "Alexandria Port Carrier Depot (مستودع الإسكندرية الفارغ)": "ALEXANDRIA_CARRIER_DEPOT",
        "Dekheila Yard (ساحة حاويات الدخيلة)": "DEKHEILA_YARD",
        "Sokhna Logistics Depot (مستودع السخنة اللوجستي)": "SOKHNA_LOGISTICS_DEPOT",
        "Port Said West Depot (مستودع غرب بورسعيد)": "PORT_SAID_WEST_DEPOT",
        "Damietta Port Empty Yard (ساحة دمياط الفارغ)": "DAMIETTA_EMPTY_YARD",
        "Ain Sokhna DP World Yard (ساحة موانئ دبي السخنة)": "SOKHNA_DP_WORLD_YARD",
    },
    SKIP_REASON_CATEGORY: {
        "Client Agreement / العميل يتولى الإجراء حسب الاتفاقية": "CLIENT_AGREEMENT",
        "Not Applicable to Mode / لا تنطبق على نمط الشحن": "NOT_APPLICABLE_TO_MODE",
        "Regulatory Exemption / إعفاء رسمي أو رقابي": "REGULATORY_EXEMPTION",
        "Other / أخرى": "OTHER",
    },
    HOLD_REASON: {
        "في انتظار رد وموافقة المورد الخارجي": "AWAITING_SUPPLIER_APPROVAL",
        "طلب تعديل على مسودة بوليصة الشحن": "DRAFT_BL_AMENDMENT",
        "في انتظار موافقة البنك وإصدار نموذج 4": "AWAITING_BANK_FORM4",
        "استيفاء موافقة جهة العرض والرقابة": "PENDING_REGULATORY_APPROVAL",
        "تأخير الحجز وتأكيد الخط الملاحي": "BOOKING_DELAYED",
        "مراجعة وتدقيق أسعار بنود التعريفة الجمركية": "TARIFF_VALUATION_REVIEW",
        "طلب فحص ومعاينة إضافية للبضاعة": "ADDITIONAL_INSPECTION",
        "تعليق إداري مؤقت للشحنة": "ADMIN_HOLD",
    },
    STAGE: {
        "Customs Broker Authorized (تفويض المخلص الجمركي)": "CUSTOMS_BROKER_AUTHORIZED",
        "Delivery Order Paid & Received (سداد إذن التسليم الملاحي)": "DELIVERY_ORDER_PAID",
        "Under Customs Clearance (تحت التخليص والكشف 46)": "UNDER_CUSTOMS_CLEARANCE",
        "Customs Inspection & Sampling Completed (تم الكشف وسحب العينات)": "CUSTOMS_INSPECTION_COMPLETED",
        "Customs Duty Assessed (احتساب الرسوم الجمركية والمطالبة)": "CUSTOMS_DUTY_ASSESSED",
        "Duty Paid (تم سداد الرسوم الجمركية بسداد)": "DUTY_PAID",
        "Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)": "CUSTOMS_RELEASED",
        "Under-Bond Quarantine (سحب على عهدة)": "UNDER_BOND_QUARANTINE",
        "Lab Rejected (مرفوض معملياً)": "LAB_REJECTED",
        "In Transit to Warehouse (الشحنة في الطريق للمخزن)": "IN_TRANSIT_TO_WAREHOUSE",
        "المرحلة الأولى: التخطيط والدراسات المسبقة": "PHASE_1",
        "المرحلة الثانية: بداية الشحنة": "PHASE_2",
        "المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي": "PHASE_3",
        "المرحلة الرابعة: التوثيق الرقمي والاعتماد البنكي": "PHASE_4",
        "المرحلة الخامسة: عمليات الميناء والتخليص الجمركي": "PHASE_5",
        "المرحلة السادسة: الاستلام المخزني والتسوية المالية": "PHASE_6",
        "Phase 1: Pre-Planning & Studies": "PHASE_1",
        "Phase 2: Approvals & ACID": "PHASE_2",
        "Phase 3: Booking & Doc Prep": "PHASE_3",
        "Phase 4: Digital & Banking": "PHASE_4",
        "Phase 5: Port Operations & Clearance": "PHASE_5",
        "Phase 6: Inbound & Final Closure": "PHASE_6",
    },
    PHASE_FOLLOW_UP_TASK: {},
    INSPECTION_YARD: {
        "ساحة الفحص المشترك - ميناء الإسكندرية (رصيف 42)": "ALEXANDRIA_BERTH_42",
        "ساحة الفحص المشترك - ميناء الدخيلة": "DEKHEILA",
        "ساحة الفحص والكشف المشترك - ميناء العين السخنة": "AIN_SOKHNA",
        "ساحة المعاينة والكشف - ميناء دمياط البحري": "DAMIETTA",
        "ساحة المعاينة والفحص - ميناء غرب بورسعيد": "WEST_PORT_SAID",
        "ساحة الفحص الجمركي - ميناء شرق بورسعيد": "EAST_PORT_SAID",
        "ساحة الفحص المشترك بالميناء الجاف بمدينة 6 أكتوبر": "OCTOBER_DRY_PORT",
        "ساحة الفحص بالميناء الجاف بمدينة العاشر من رمضان": "TENTH_RAMADAN_DRY_PORT",
        "قرية البضائع - مطار القاهرة الدولي": "CAIRO_AIRPORT_CARGO",
        "ساحة الفحص المشترك - ميناء الأدبية بالسويس": "ADABIYA",
    },
    CUSTOMS_CATEGORY: {
        "آلات وأجهزة وتجهيزات": "MACHINERY_EQUIPMENT",
        "أصناف عامة": "GENERAL_GOODS",
        "General": "GENERAL_GOODS",
    },
    VALUE_PLACEHOLDER: {
        "غير مسجل بالسستم": "NOT_SET",
        "غير محدد بالسستم": "NOT_SET",
        "غير مسجل": "NOT_SET",
        "غير متوفر بالسستم": "NOT_SET",
        "غير متوفر بالمستند": "NOT_IN_DOCUMENT",
        "غير متوفر": "NOT_IN_DOCUMENT",
        "غير مذكور بالفاتورة": "NOT_IN_INVOICE",
        "— (غير مدرج بالفاتورة)": "NOT_IN_INVOICE",
        "غير موجود بالفاتورة": "NOT_IN_INVOICE",
        "غير متوفر بالفاتورة": "NOT_IN_INVOICE",
        "غير محدد بالفاتورة": "NOT_IN_INVOICE",
        "غير موجود بالباكينج": "NOT_IN_PACKING_LIST",
        "غير متوفر بالباكينج": "NOT_IN_PACKING_LIST",
        "غير محدد بالباكينج": "NOT_IN_PACKING_LIST",
        "غير مسجل بالباكينج": "NOT_IN_PACKING_LIST",
        "غير موجود بالبوليصة": "NOT_IN_BL",
        "غير متوفر بالبوليصة": "NOT_IN_BL",
        "غير محدد بالبوليصة": "NOT_IN_BL",
        "غير محدد": "NOT_SPECIFIED",
        "— (غير مدرج بالباكينج)": "NOT_IN_PACKING_LIST",
        "لم يتم الاستخراج": "NOT_EXTRACTED",
        "اختياري / غير مدرج": "OPTIONAL_NOT_INCLUDED",
    },
    MEASURE_UNIT: {
        "طرد": "PACKAGES",
        "كجم": "KG",
        "م³": "CBM",
        "طرد/بالتة": "PACKAGES_PALLETS",
    },
}

ENUM_TYPES: Tuple[str, ...] = tuple(LABELS_EN.keys())

# ISO currency aliases (Arabic / lower-case forms old clients sent).
_CURRENCY_ALIASES: Dict[str, str] = {
    "جنيه": "EGP",
    "جنيه مصري": "EGP",
    "ج.م": "EGP",
    "ج م": "EGP",
    "جم": "EGP",
    "le": "EGP",
    "l.e": "EGP",
    "l.e.": "EGP",
    "دولار": "USD",
    "دولار أمريكي": "USD",
    "يورو": "EUR",
}

_WS_RE = re.compile(r"\s+")
_NON_ALNUM_RE = re.compile(r"[^A-Za-z0-9]+")
_ARABIC_RE = re.compile(r"[؀-ۿ]")


def _key(value: str) -> str:
    return _WS_RE.sub(" ", value).strip().casefold()


def _derived_code(text: str) -> str:
    return _NON_ALNUM_RE.sub("_", text).strip("_").upper()


def _build_lookup() -> Dict[str, Dict[str, str]]:
    """casefolded legacy label / English label -> code, per type."""
    lookup: Dict[str, Dict[str, str]] = {}
    for enum_type, labels in LABELS_EN.items():
        table: Dict[str, str] = {}
        for code, label in labels.items():
            table[_key(label)] = code
        for legacy, code in _LEGACY.get(enum_type, {}).items():
            if code not in labels:  # pragma: no cover - guarded by tests
                raise ValueError(f"legacy label of {enum_type} maps to unknown code {code}")
            table[_key(legacy)] = code
        lookup[enum_type] = table
    return lookup


_LOOKUP = _build_lookup()


def codes(enum_type: str) -> List[str]:
    return list(LABELS_EN[enum_type].keys())


def is_code(enum_type: str, value: Any) -> bool:
    return isinstance(value, str) and value in LABELS_EN.get(enum_type, {})


def label_en(enum_type: str, value: Optional[str]) -> Optional[str]:
    """English label of a code; anything that is not a code comes back unchanged."""
    if value is None:
        return None
    return LABELS_EN.get(enum_type, {}).get(value, value)


def label_ar(enum_type: str, value: Optional[str]) -> Optional[str]:
    """Arabic label of a code, taken from the Arabic part of its first legacy label ("English (عربي)",
    "English / عربي" or a plain Arabic label). Falls back to the English label; non-codes come back unchanged."""
    if value is None:
        return None
    if not is_code(enum_type, value):
        return value
    for legacy, code in _LEGACY.get(enum_type, {}).items():
        if code != value or not _ARABIC_RE.search(legacy):
            continue
        for piece in _candidates(legacy):
            piece = piece.strip()
            if piece and _ARABIC_RE.search(piece) and not re.search(r"[A-Za-z]", piece):
                return piece
    return label_en(enum_type, value)


def legacy_text(enum_type: str, value: Optional[str]) -> str:
    """The legacy stored text for a code / known label (its first legacy label), else ``value`` unchanged.
    Keyword classifiers (landed-cost buckets, Odoo accounts) run on this so coded rows classify exactly like
    the legacy rows did."""
    if not isinstance(value, str):
        return value or ""
    code = normalize(enum_type, value)
    if not is_code(enum_type, code):
        return value
    for legacy, mapped in _LEGACY.get(enum_type, {}).items():
        if mapped == code:
            return legacy
    return label_en(enum_type, code)


def legacy_labels() -> Dict[str, Dict[str, str]]:
    """Copy of the legacy label -> code maps (for tests and for the Flutter reverse map review)."""
    return {t: dict(m) for t, m in _LEGACY.items()}


def _candidates(text: str) -> Iterable[str]:
    """Pieces of a mixed label worth trying: the whole text, the part before '(' or ' / ', and the
    parenthesised part ("البنك الأهلي المصري (NBE)" -> "NBE")."""
    yield text
    if "(" in text:
        head, _, rest = text.partition("(")
        yield head
        yield rest.split(")", 1)[0]
    if " / " in text:
        for piece in text.split(" / "):
            yield piece


def normalize(enum_type: str, value: Any) -> Any:
    """Map a legacy label (or a code in any case) to the enum code. Unknown values are returned unchanged;
    ``None`` and non-strings pass through. Never raises for a known ``enum_type``."""
    if enum_type not in LABELS_EN:
        raise KeyError(f"Unknown enum type: {enum_type}")
    if not isinstance(value, str):
        return value
    text = value.strip()
    if not text:
        return value
    labels = LABELS_EN[enum_type]
    if text in labels:
        return text
    table = _LOOKUP[enum_type]
    for candidate in _candidates(text):
        candidate = candidate.strip()
        if not candidate:
            continue
        hit = table.get(_key(candidate))
        if hit:
            return hit
        if not _ARABIC_RE.search(candidate):
            derived = _derived_code(candidate)
            if derived in labels:
                return derived
    return value


def normalize_list(enum_type: str, values: Optional[Iterable[Any]]) -> Optional[List[Any]]:
    """``normalize`` every item, dropping duplicates while keeping the first occurrence order."""
    if values is None:
        return None
    result: List[Any] = []
    for item in values:
        code = normalize(enum_type, item)
        if code not in result:
            result.append(code)
    return result


def legacy_values(enum_type: str, code: str) -> List[str]:
    """The code plus every legacy label that normalizes to it (for filters that must also hit old rows)."""
    values = [code]
    label = LABELS_EN.get(enum_type, {}).get(code)
    if label and label not in values:
        values.append(label)
    for legacy, mapped in _LEGACY.get(enum_type, {}).items():
        if mapped == code and legacy not in values:
            values.append(legacy)
    return values


def normalize_currency(value: Any) -> Any:
    """ISO currency code: Arabic aliases ('جنيه' -> 'EGP') and lower-case ISO codes are mapped;
    anything else is returned unchanged."""
    if not isinstance(value, str):
        return value
    text = value.strip()
    if not text:
        return value
    alias = _CURRENCY_ALIASES.get(_key(text))
    if alias:
        return alias
    if re.fullmatch(r"[A-Za-z]{3}", text):
        return text.upper()
    return value


# ── Lifecycle stage references sent by clients ─────────────────────────────────
_STEP_RE = re.compile(r"STEP[_\- ]?(\d{2})(?:[_\-](PO|BL|MATCH|COO|COC))?(?![A-Z0-9])", re.IGNORECASE)
_PHASE_RE = re.compile(r"PHASE[_\- ]?(\d{1,2})(?!\d)", re.IGNORECASE)


def parse_stage_reference(value: Optional[str]) -> Tuple[Optional[int], Optional[str]]:
    """Extract ``(phase_id, step_code)`` from the stage references clients send, e.g. 'STEP_08_BL',
    'STEP-08', 'PHASE-4: STEP_11', 'PHASE-5', 'PHASE_3', 'PHASE-1: STEP_02-TAX'. Either may be None."""
    if not value or not isinstance(value, str):
        return None, None
    step_code: Optional[str] = None
    step_match = _STEP_RE.search(value)
    if step_match:
        step_code = f"STEP_{step_match.group(1)}"
        if step_match.group(2):
            step_code += f"_{step_match.group(2).upper()}"
    phase_id: Optional[int] = None
    phase_match = _PHASE_RE.search(value)
    if phase_match:
        phase_id = int(phase_match.group(1))
    return phase_id, step_code


def contains_arabic(value: Optional[str]) -> bool:
    return bool(value) and bool(_ARABIC_RE.search(value))


# ── Structured values of document comparison items (single-language storage) ──
@dataclass(frozen=True)
class Placeholder:
    """A VALUE_PLACEHOLDER code standing where a comparison item has no value."""
    code: str


@dataclass(frozen=True)
class Measure:
    """A number with a MEASURE_UNIT code (``decimals=None``: integers stay integers)."""
    number: Any
    unit: str
    decimals: Optional[int] = 2


def _as_number(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def finalize_structured_values(item: Dict[str, Any]) -> Dict[str, Any]:
    """Replace ``Placeholder`` / ``Measure`` values of a JSON payload item by their English text and record
    the structure under ``item["structured_values"][key]``:
    ``{"placeholder": CODE}`` or ``{"number": n, "unit": CODE}``. Plain values are left untouched."""
    structured: Dict[str, Dict[str, Any]] = dict(item.get("structured_values") or {})
    for key, value in list(item.items()):
        if isinstance(value, Placeholder):
            if value.code not in LABELS_EN[VALUE_PLACEHOLDER]:
                raise KeyError(f"unknown {VALUE_PLACEHOLDER} code {value.code}")
            item[key] = LABELS_EN[VALUE_PLACEHOLDER][value.code]
            structured[key] = {"placeholder": value.code}
        elif isinstance(value, Measure):
            if value.unit not in LABELS_EN[MEASURE_UNIT]:
                raise KeyError(f"unknown {MEASURE_UNIT} code {value.unit}")
            unit_label = LABELS_EN[MEASURE_UNIT][value.unit]
            number = _as_number(value.number)
            if number is None:
                item[key] = f"{value.number} {unit_label}"
                structured[key] = {"number": None, "raw": str(value.number), "unit": value.unit}
                continue
            if value.decimals is None:
                shown: Any = int(number) if number.is_integer() else number
                item[key] = f"{shown} {unit_label}"
            else:
                shown = round(number, value.decimals)
                item[key] = f"{number:,.{value.decimals}f} {unit_label}"
            structured[key] = {"number": shown, "unit": value.unit}
    if structured:
        item["structured_values"] = structured
    return item


# ── Flutter contract: docs/enum_codes.json ──
def build_contract() -> Dict[str, Dict[str, Dict[str, str]]]:
    """``{TYPE: {"codes": {CODE: English label}, "legacy": {legacy label: CODE}}}``."""
    return {
        enum_type: {"codes": dict(LABELS_EN[enum_type]), "legacy": dict(_LEGACY.get(enum_type, {}))}
        for enum_type in ENUM_TYPES
    }


def contract_json() -> str:
    return json.dumps(build_contract(), ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def write_contract(path: Optional[Path] = None) -> Path:
    target = Path(path) if path is not None else CONTRACT_PATH
    target.write_text(contract_json(), encoding="utf-8", newline="\n")
    return target


if __name__ == "__main__":  # pragma: no cover - developer helper
    print(f"Wrote {write_contract()}")
