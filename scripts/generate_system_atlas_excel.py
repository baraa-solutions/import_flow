"""
Script to generate the authoritative, comprehensive Excel Workbook (.xlsx)
documenting the complete ImportFlow ERP System Architecture, all 110 Database Tables,
all 6 Lifecycle Phases and 23 Operational Steps, the entire 154 Foreign Key Relationships network,
and the full 2,358 Columns Data Dictionary with Calculation Engines and Business Rules.
"""

import os
import sys
import re

# Add project root to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from database.database import Base
import database.models

# Explicitly import all extra modules so Base.metadata is 100% complete
extra_modules = [
    'modules.cargox.model',
    'modules.cargo_insurance.model',
    'modules.inland_transport.model',
    'modules.docs_customs_approval.model',
    'modules.original_documents_collection.model',
    'modules.smart_checklists.model',
    'modules.formal_letters.model',
    'modules.route_intelligence.model',
    'modules.experience_guide.model',
    'modules.production_sync.model',
    'modules.recalculation.model',
    'modules.simulation.model',
    'modules.smart_email_listener.model',
    'modules.freight_data_connector.model',
    'modules.auth.revoked_token_model',
    'modules.common.concurrency',
]

for m in extra_modules:
    try:
        __import__(m)
    except Exception as e:
        print(f"Warning importing {m}: {e}")

from modules.lifecycle_board.service import PHASES_DEFINITION, ORDERED_STEP_CODES, STEP_TO_PHASE_MAP, STEP_NAME_MAP

# ════════════════════════════════════════════════════════════════
# TABLE METADATA ENRICHMENT DICTIONARY (ALL 110 TABLES)
# ════════════════════════════════════════════════════════════════
TABLE_METADATA = {
    # Core Import Files & Hub
    "import_files": {
        "arabic_name": "ملفات الشحنات الاستيرادية (الملف المحوري)",
        "domain": "إدارة الاستيراد والشحنات (Core Hub)",
        "module": "import_files",
        "phase": "جميع المراحل (Phases 1-6)",
        "classification": "تشغيلي محوري (Core Hub)",
        "description": "عصب وقلب النظام، يحمل الكود الاستيرادي (IMP-YYYY-XXXX). ترتبط به جميع العمليات: أوامر الشراء، الشحن، الجمارك، الإقرارات، الفواتير، والتسوية المالية."
    },
    "import_companies": {
        "arabic_name": "شركات الاستيراد التابعة (المستوردين)",
        "domain": "البيانات الأساسية والشركات (Master Data)",
        "module": "import_companies",
        "phase": "المرحلة 1: التخطيط المسبق",
        "classification": "بيانات أساسية (Master Data)",
        "description": "بيانات الشركات والكيانات القانونية التابعة للمجموعة المسجلة لدى الجمارك، البطاقات الاستيرادية، السجلات الضريبية، وحسابات نافذة."
    },
    "suppliers": {
        "arabic_name": "الموردون الدوليون والمصانع",
        "domain": "المشتريات والموردين (Suppliers)",
        "module": "suppliers",
        "phase": "المرحلة 1: التخطيط المسبق",
        "classification": "بيانات أساسية (Master Data)",
        "description": "دليل الموردين العالميين، المصانع، العملات المعتمدة، بيانات الاتصال، البنوك المصدرة، ومعايير تقييم الموردين."
    },
    "projects": {
        "arabic_name": "المشاريع ومراكز التكلفة الاستيرادية",
        "domain": "المشاريع والموازنات (Projects)",
        "module": "projects",
        "phase": "المرحلة 1: التخطيط المسبق",
        "classification": "بيانات أساسية (Master Data)",
        "description": "المشاريع التشغيلية والاستثمارية التي يتم الاستيراد لصالحها، مراكز التكلفة، والميزانيات المعتمدة للمشروع."
    },
    "po_shipment_allocations": {
        "arabic_name": "تخصيص وتوزيع بنود أوامر الشراء على الشحنات",
        "domain": "إدارة الشحنات وأوامر الشراء",
        "module": "purchase_orders",
        "phase": "المرحلة 3: حجز الشحن",
        "classification": "تشغيلي وسيط (Operational Linking)",
        "description": "إدارة الشحنات الجزئية (Partial Shipments)، حيث يربط بين بنود أمر الشراء والكميات الموزعة على ملف شحنة محدد."
    },

    # Purchase Orders & Items
    "purchase_orders": {
        "arabic_name": "أوامر الشراء الدولية (POs)",
        "domain": "المشتريات والتعاقدات (Purchase Orders)",
        "module": "purchase_orders",
        "phase": "المرحلة 2: بداية الشحنة",
        "classification": "تشغيلي أساسي (Core Operational)",
        "description": "عقود وأوامر الشراء الرسمية الصادرة للمورد، تشمل القيمة الإجمالية، العملة، شروط الدفع، وشروط التجارة الدولية (Incoterms)."
    },
    "po_line_items": {
        "arabic_name": "بنود وتفاصيل أمر الشراء",
        "domain": "المشتريات والتعاقدات (PO Items)",
        "module": "purchase_orders",
        "phase": "المرحلة 2: بداية الشحنة",
        "classification": "تشغيلي تفصيلي (Detailed Operational)",
        "description": "تفاصيل كل صنف مشتري: الوصف، كود البند الجمركي (HS Code)، الكمية، سعر الوحدة، القيمة الإجمالية، ونسبة الضريبة المقررة."
    },
    "packing_list_items": {
        "arabic_name": "بيانات بنود قائمة التعبئة (Packing List)",
        "domain": "المشتريات واللوجستيات (Packing)",
        "module": "purchase_orders",
        "phase": "المرحلة 3: التدقيق المستندي",
        "classification": "تشغيلي تفصيلي (Detailed Operational)",
        "description": "بيانات التعبئة المادية: عدد الطرود، نوع التعبئة، الأوزان القائمة والصافية، الأبعاد (طول/عرض/ارتفاع)، والحجم بالمتر المكعب CBM."
    },
    "package_types": {
        "arabic_name": "أنواع التعبئة والتغليف (طبالي/كراتين/براميل)",
        "domain": "البيانات المرجعية (Master Data)",
        "module": "purchase_orders",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Reference Data)",
        "description": "كتالوج أنواع الطرود المعتمدة جمركياً ولوجستياً (Pallets, Cartons, Drums, Wooden Crates, Bags, etc.)."
    },
    "units_of_measure": {
        "arabic_name": "وحدات القياس المعيارية (UOM)",
        "domain": "البيانات المرجعية (Master Data)",
        "module": "purchase_orders",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Reference Data)",
        "description": "وحدات القياس المعيارية للبضائع (قطعة، كجم، طن، متر، لتر، إلخ) مع معامل التحويل الداخلي."
    },

    # Freight & Shipping Logistics
    "freight_rfq_requests": {
        "arabic_name": "طلبات عروض أسعار نولون الشحن (Freight RFQs)",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "freight_quotations",
        "phase": "المرحلة 1: دراسات الشحن (STEP_01)",
        "classification": "تشغيلي ودراسات (Studies & RFQ)",
        "description": "طلبات عروض الأسعار المرسلة لوكلاء الشحن والخطوط الملاحية لمفاضلة أسعار النولون البحري والجوي والبري."
    },
    "freight_quotation_items": {
        "arabic_name": "عروض أسعار الشحن الواردة من الوكلاء",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "freight_quotations",
        "phase": "المرحلة 1: دراسات الشحن (STEP_01)",
        "classification": "تشغيلي ودراسات (Studies & RFQ)",
        "description": "عروض الأسعار المستلمة: سعر الحاوية/الشحنة، العملة، فترات السماح المجانية، وقت العبور (Transit Time)، وصلاحية العرض."
    },
    "shipping_evaluation_sessions": {
        "arabic_name": "جلسات تقييم ومفاضلة سيناريوهات الشحن",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "shipping_scenarios",
        "phase": "المرحلة 1: دراسات الشحن (STEP_01)",
        "classification": "تحليلي ومفاضلة (Evaluation Session)",
        "description": "جلسات التحليل والمقارنة بين خطوط الشحن والمسارات اللوجستية المختلفة لاختيار السيناريو الأمثل تكلفة ووقتاً."
    },
    "shipping_scenario_items": {
        "arabic_name": "سيناريوهات وبدائل الشحن التفصيلية",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "shipping_scenarios",
        "phase": "المرحلة 1: دراسات الشحن (STEP_01)",
        "classification": "تحليلي ومفاضلة (Scenario Items)",
        "description": "بيانات السيناريو التفصيلي (89 عمود): الخط الملاحي، وكيل الشحن، ميناء الشحن والوصول، التكلفة التقديرية، نقاط القوة والمخاطر."
    },
    "shipment_bookings": {
        "arabic_name": "حجوزات الشحن المؤكدة (Freight Bookings)",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "freight_booking",
        "phase": "المرحلة 3: حجز الشحن (STEP_06)",
        "classification": "تشغيلي أساسي (Core Operational)",
        "description": "حجز الشحن المعتمد مع الخط الملاحي: رقم الحجز (Booking No)، اسم السفينة، رقم الرحلة، مواعيد الإبحار والوصول المتوقعة (ETD/ETA)."
    },
    "cargo_shipping_records": {
        "arabic_name": "سجلات حركة وتتبع الشحنات",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "cargo_shipping",
        "phase": "المرحلة 3: حجز الشحن والتحرك",
        "classification": "تشغيلي وتتبع (Tracking)",
        "description": "تتبع خط سير الشحنة الفعلي، حركة السفينة، الموانئ الوسيطة (Transshipment)، وتحديثات مواعيد الوصول."
    },
    "shipment_update_logs": {
        "arabic_name": "سجل التحديثات والتتبع اللوجستي للشحنة",
        "domain": "الشحن الدولي واللوجستيات",
        "module": "shipment_updates",
        "phase": "المراحل 3-5: التتبع الميداني",
        "classification": "سجل زمني (Event Log)",
        "description": "سجل زمني متسلسل لجميع الأحداث اللوجستية والتحديثات الواردة من وكلاء الشحن ومواقع الموانئ."
    },
    "freight_index_snapshots": {
        "arabic_name": "لقطات مؤشرات أسعار النولون العالمية",
        "domain": "الذكاء اللوجستي ومؤشرات السوق",
        "module": "freight_data_connector",
        "phase": "المرحلة 1: التخطيط المسبق",
        "classification": "ذكاء أعمال (Market Intelligence)",
        "description": "بيانات أسعار النولون العالمية التاريخية واللحظية لمراقبة تقلبات أسعار الشحن العالمية واختيار توقيت الحجز الأمثل."
    },
    "route_operational_notes": {
        "arabic_name": "الملاحظات التشغيلية والذكاء اللوجستي للمسارات",
        "domain": "الذكاء اللوجستي والمسارات",
        "module": "route_intelligence",
        "phase": "المرحلة 1: دراسات الشحن",
        "classification": "معرفي وتشغيلي (Operational Intel)",
        "description": "سجل الملاحظات الميدانية للمسارات اللوجستية والموانئ: معدلات التكدس، مشاكل المناولة، وخصائص الخطوط الملاحية."
    },
    "inland_transport_bookings": {
        "arabic_name": "حجوزات النقل البري الداخلي للشاحنات",
        "domain": "اللوجستيات والنقل الداخلي",
        "module": "inland_transport",
        "phase": "المرحلة 6: الاستلام المخزني (STEP_19)",
        "classification": "تشغيلي لوجستي (Inland Transport)",
        "description": "أوامر تشغيل سيارات النقل البري لنقل الحاويات والبضائع من الميناء الجمركي إلى مستودعات ومواقع الشركة."
    },

    # Container & CBM Calculations
    "cbm_calculations": {
        "arabic_name": "جلسات حساب CBM والوزن الحجمي",
        "domain": "الحسابات اللوجستية والأبعاد",
        "module": "cbm_calculator",
        "phase": "المرحلة 1 و 3: الحسابات المادية",
        "classification": "محرك حسابي (Calculation Session)",
        "description": "جلسات الحساب الرياضي للحجم الكلي CBM والوزن الحجمي للشحن الجوي ومقارنته بالوزن الفعلي لتحديد الوزن الخاضع للأجر."
    },
    "cbm_calculation_items": {
        "arabic_name": "تفاصيل بنود وطرود حساب CBM",
        "domain": "الحسابات اللوجستية والأبعاد",
        "module": "cbm_calculator",
        "phase": "المرحلة 1 و 3: الحسابات المادية",
        "classification": "محرك حسابي تفصيلي (Calculation Items)",
        "description": "أبعاد الطرود الفردية (طول × عرض × ارتفاع بالوحدات المختلفة: مم، سم، م) مع أوزانها والكميات لكل مقاس."
    },
    "container_specs": {
        "arabic_name": "المواصفات القياسية للحاويات (20ft/40ft/HQ)",
        "domain": "البيانات المرجعية اللوجستية",
        "module": "container_loader",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Master Specs)",
        "description": "الأبعاد الداخلية، السعة الحجمية (CBM)، الحمولة القصوى (Payload Weight)، ومقاييس الأبواب لجميع أنواع الحاويات القياسية."
    },
    "container_loader_sessions": {
        "arabic_name": "جلسات التوزيع الأمثل بالحاويات (3D Bin Packing)",
        "domain": "اللوجستيات وتوزيع الحاويات",
        "module": "container_loader",
        "phase": "المرحلة 3: تخصيص الشحن (STEP_07)",
        "classification": "محرك محاكاة ذكي (3D Packing Engine)",
        "description": "جلسات خوارزمية التعبئة ثلاثية الأبعاد لمحاكاة ترتيب الطرود وتوزيع الأوزان داخل الحاويات وتدوير الطبالي 90 درجة."
    },

    # Insurance
    "cargo_insurance_certificates": {
        "arabic_name": "وثائق وشهادات التأمين البحري على الشحنة",
        "domain": "التأمين وإدارة المخاطر",
        "module": "cargo_insurance",
        "phase": "المرحلة 2: بداية الشحنة (STEP_04)",
        "classification": "مستندي ومالي (Insurance)",
        "description": "بيانات وثيقة التأمين البحري (50 عمود): شركة التأمين، مبلغ التأمين، القسط المدفوع، نسبة التغطية، وشروط المجمع البحرية (Institute Clauses)."
    },

    # Customs Tariff & Regulations
    "customs_tariffs": {
        "arabic_name": "جدول التعريفة الجمركية المصرية (HS Codes)",
        "domain": "التعريفة والقوانين الجمركية",
        "module": "customs_tariff",
        "phase": "المرحلة 1: الدراسات الجمركية",
        "classification": "بيانات مرجعية محورية (Tariff Master)",
        "description": "جدول البنود الجمركية المصرية: كود البند (HS Code)، الوصف، نسبة ضريبة الوارد، نسبة القيمة المضافة (VAT)، وضريبة الجدول."
    },
    "fee_codes": {
        "arabic_name": "أكواد الرسوم الجمركية ومصروفات الخدمات",
        "domain": "التعريفة والقوانين الجمركية",
        "module": "customs_tariff",
        "phase": "المرحلة 1: الدراسات الجمركية",
        "classification": "بيانات مرجعية (Fee Master)",
        "description": "دليل الرسوم الإضافية وأجور الخدمات ورسوم التنمية والرسوم الإحصائية المطبقة بالمنافذ الجمركية."
    },
    "preferential_agreements": {
        "arabic_name": "الاتفاقيات التفضيلية والإعفاءات الجمركية",
        "domain": "التعريفة والقوانين الجمركية",
        "module": "customs_tariff",
        "phase": "المرحلة 1: الدراسات الجمركية",
        "classification": "بيانات مرجعية (Trade Agreements)",
        "description": "الاتفاقيات التجارية التفضيلية (الشراكة الأوروبية EUR.1، تيسير التجارة العربية، أغادير، الكويز، الكوميسا) وقواعد منشأ كل اتفاقية."
    },
    "import_requirement_assessments": {
        "arabic_name": "تقييم متطلبات واشتراطات الاستيراد والعرض الرقابي",
        "domain": "الاستشارات والرقابة على الواردات",
        "module": "import_requirements",
        "phase": "المرحلة 1: متطلبات الاستيراد (STEP_03)",
        "classification": "تشغيلي واستشاري (Compliance Assessment)",
        "description": "دراسة متطلبات الجهات الرقابية (سلامة الغذاء NFSA، الرقابة على الصادرات GOEIC، الاتصالات NTRA، الدواء EDA، وغيرها)."
    },

    # Customs Consultation & Broker RFQs
    "customs_consultation_sessions": {
        "arabic_name": "جلسات الاستشارات والدراسات الجمركية المسبقة",
        "domain": "الاستشارات الجمركية",
        "module": "customs_consultation",
        "phase": "المرحلة 1: الدراسات الجمركية (STEP_02)",
        "classification": "استشاري وتحليلي (Consultation Session)",
        "description": "جلسات توثيق الرأي الفني الاستشاري للبند الجمركي، التحقق من مستندات الاستيراد المطلوبة، وتجنب مخاطر إعادة التصنيف."
    },
    "customs_checklist_items": {
        "arabic_name": "بنود قائمة التحقق والمستندات الجمركية المطلوبة",
        "domain": "الاستشارات الجمركية",
        "module": "customs_consultation",
        "phase": "المرحلة 1: الدراسات الجمركية (STEP_02)",
        "classification": "قوائم تدقيق (Checklist Items)",
        "description": "قائمة التحقق المسبقة للمستندات والشهادات الإلزامية المطلوبة للإفراج الجمركي حسب توصية المستشار أو المخلص."
    },
    "customs_broker_quote_items": {
        "arabic_name": "بنود عروض أسعار المخلصين الجمركيين الفردية",
        "domain": "الاستشارات الجمركية وعروض التخليص",
        "module": "customs_consultation",
        "phase": "المرحلة 1: الدراسات الجمركية (STEP_02)",
        "classification": "عروض أسعار تفصيلية (Broker Quotes)",
        "description": "البنود المالية المفصلة لعروض المخلصين: أتعاب التخليص، رسوم العرض، النولون الداخلي، ومصاريف الشياكة والمناولة."
    },
    "broker_price_lists": {
        "arabic_name": "قوائم أسعار خدمات المخلصين المعتمدين",
        "domain": "الاستشارات الجمركية ومزودي الخدمات",
        "module": "customs_consultation",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات تسعير مرجعية (Price Lists)",
        "description": "قوائم الأسعار المتفق عليها مسبقاً مع مكاتب وشركات التخليص الجمركي لكل ميناء أو منفذ جمركي."
    },
    "broker_price_list_items": {
        "arabic_name": "بنود خدمات ومصروفات قوائم أسعار المخلصين",
        "domain": "الاستشارات الجمركية ومزودي الخدمات",
        "module": "customs_consultation",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات تسعير تفصيلية (Price List Items)",
        "description": "التعريفة المالية لكل خدمة تخليص أو رسم إجرائي داخل قائمة أسعار المخلص."
    },
    "clearance_expense_types": {
        "arabic_name": "دليل أنواع مصروفات ورسوم التخليص الجمركي",
        "domain": "البيانات المرجعية المالية للتخليص",
        "module": "customs_consultation",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Expense Types)",
        "description": "دليل تصنيف مصروفات التخليص (أتعاب، رسوم موانئ، حراسات، سحب عينات، موازين، عمالة كشف وتفريغ، إلخ)."
    },
    "customs_clearance_rfqs": {
        "arabic_name": "طلبات عروض أسعار التخليص الجمركي (Clearance RFQs)",
        "domain": "التخليص الجمركي وعروض الأسعار",
        "module": "customs_clearance_quotations",
        "phase": "المرحلة 1: الدراسات الجمركية (STEP_02)",
        "classification": "تشغيلي ودراسات (Clearance RFQ)",
        "description": "طلبات عروض أسعار التخليص المرسلة للمخلصين الجمركيين لمقارنة أتعاب ومصروفات الإفراج للشحنة."
    },
    "customs_clearance_quotations": {
        "arabic_name": "عروض أسعار التخليص الجمركي المستلمة",
        "domain": "التخليص الجمركي وعروض الأسعار",
        "module": "customs_clearance_quotations",
        "phase": "المرحلة 1: الدراسات الجمركية (STEP_02)",
        "classification": "عروض أسعار (Quotations)",
        "description": "عروض أسعار التخليص الواردة من المخلصين والمفاضلة بينها وترسية الشحنة على المخلص الفائز."
    },
    "clearance_price_list_items": {
        "arabic_name": "بنود أسعار التخليص المقارنة",
        "domain": "التخليص الجمركي وعروض الأسعار",
        "module": "customs_clearance_quotations",
        "phase": "المرحلة 1: الدراسات الجمركية (STEP_02)",
        "classification": "بنود مقارنة (Price Comparison)",
        "description": "مقارنة بنود الأتعاب والرسوم الإجرائية بين عروض المخلصين المختلفة لاختيار العرض الأكثر وفراً وكفاءة."
    },

    # Digital Verification, ACID & CargoX
    "acid_registration_sessions": {
        "arabic_name": "جلسات تسجيل ومتابعة الرقم المبدئي للشحنة (ACID)",
        "domain": "التوثيق الرقمي ونظام التسجيل المسبق",
        "module": "import_documentation",
        "phase": "المرحلة 2: الرقم التعريفي ACID (STEP_05)",
        "classification": "تشغيلي وقانوني حرج (ACID Compliance)",
        "description": "متابعة استخراج وصلاحية رقم ACID من نافذة (51 عمود): تاريخ الإصدار، تاريخ الانتهاء، التنبيه الآلي قبل 14 يوماً، وحظر الإفراج عند انتهاء الصلاحية."
    },
    "cargox_envelopes": {
        "arabic_name": "أظرف ومستندات منصة CargoX المعتمدة رقمياً",
        "domain": "التوثيق الرقمي وسلاسل الكتل (CargoX)",
        "module": "cargox",
        "phase": "المرحلة 4: التوثيق الرقمي (STEP_10)",
        "classification": "تشغيلي وتكامل رقمي (CargoX Integration)",
        "description": "إدارة أظرف CargoX (Envelopes) المرفوعة بواسطة المورد الخارجي وتتبع حالتها المشفرة عبر شبكة سلاسل الكتل."
    },
    "cargox_envelope_documents": {
        "arabic_name": "تفاصيل ومرفقات مستندات ظرف CargoX",
        "domain": "التوثيق الرقمي وسلاسل الكتل (CargoX)",
        "module": "cargox",
        "phase": "المرحلة 4: التوثيق الرقمي (STEP_10)",
        "classification": "مستندي تفصيلي (CargoX Documents)",
        "description": "قائمة المستندات داخل ظرف CargoX: الفاتورة، البوليصة، شهادة المنشأ، شهادة التحليل، مع بصمة الملف الرقمية (Hash)."
    },
    "cargox_standard_invoice_sessions": {
        "arabic_name": "جلسات الفاتورة المعيارية على CargoX",
        "domain": "التوثيق الرقمي وسلاسل الكتل (CargoX)",
        "module": "cargox",
        "phase": "المرحلة 4: التوثيق الرقمي (STEP_10)",
        "classification": "مستندي ومعياري (Standard Invoice)",
        "description": "جلسات التحقق من مطابقة الفاتورة التجارية المرفوعة لمعايير منظومة نافذة و CargoX بصيغة البيانات المنظمة."
    },
    "cargox_customs_invoice_tracks": {
        "arabic_name": "تتبع الفواتير الجمركية المرفوعة على المنصة",
        "domain": "التوثيق الرقمي وسلاسل الكتل (CargoX)",
        "module": "cargox",
        "phase": "المرحلة 4: التوثيق الرقمي (STEP_10)",
        "classification": "تتبع وتدقيق (Invoice Tracking)",
        "description": "تتبع اعتماد وقبول مصلحة الجمارك للفواتير المرفوعة عبر المنصة وربطها بإقرار 46 ك.م."
    },
    "original_documents_collection_sessions": {
        "arabic_name": "جلسات استلام وتتبع أصول المستندات الورقية",
        "domain": "التدقيق المستندي والأصول الورقية",
        "module": "original_documents_collection",
        "phase": "المرحلة 4: تحصيل الأصول (STEP_11)",
        "classification": "تشغيلي ومستندي (Original Docs Tracking)",
        "description": "تتبع وصول أصول المستندات عبر البريد الدولي السريع (DHL/FedEx): رقم البوليصة السريعة، استلام البنك، أو استلام المخلص."
    },

    # Document Verification & Reconciliation Sessions
    "shipment_document_items": {
        "arabic_name": "سجل ومكتبة مستندات الشحنة الرسمية",
        "domain": "التدقيق المستندي والأرشيف",
        "module": "import_documentation",
        "phase": "جميع المراحل (Documentation Hub)",
        "classification": "أرشيف مستندي (Document Store)",
        "description": "سجل لكافة الوثائق المرفوعة للشحنة: الفواتير، بوالص الشحن، شهادات المنشأ، نتائج التحاليل، مع تواريخ الرفع وحالة التدقيق."
    },
    "po_packing_reconciliation_sessions": {
        "arabic_name": "جلسات مطابقة الفاتورة والتعبئة مع أمر الشراء",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "import_documentation",
        "phase": "المرحلة 3: التدقيق المستندي (STEP_08_PO)",
        "classification": "محرك مطابقة ذكي (Reconciliation Session)",
        "description": "المطابقة الذكية بين بنود وأسعار وكميات أمر الشراء (PO) والفاتورة المبدئية وقائمة التعبئة الفعلية واكتشاف أي فروق كمية أو سعرية."
    },
    "draft_bl_review_sessions": {
        "arabic_name": "جلسات مراجعة واعتماد مسودة بوليصة الشحن",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "import_documentation",
        "phase": "المرحلة 3: التدقيق المستندي (STEP_08_BL)",
        "classification": "جلسة تدقيق قانونية (Draft BL Review)",
        "description": "التدقيق الدقيق لمسودة بوليصة الشحن (53 عمود): اسم المشحون له (Consignee)، الإخطار (Notify Party)، رقم ACID، شروط التسليم، ومطابقتها للقانون المصري."
    },
    "invoice_bl_match_sessions": {
        "arabic_name": "جلسات المطابقة الذكية بين الفاتورة والبوليصة",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "import_documentation",
        "phase": "المرحلة 3: التدقيق المستندي (STEP_08_MATCH)",
        "classification": "محرك مطابقة متقاطعة (Cross-Match Session)",
        "description": "المطابقة المتقاطعة الآلية بين الفاتورة التجارية وبوليصة الشحن: الأوزان، عدد الطرود، الوصف، شروط الشحن، وتفادي غرامات عدم التطابق."
    },
    "certificate_of_origin_review_sessions": {
        "arabic_name": "جلسات مراجعة شهادة المنشأ و EUR.1",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "import_documentation",
        "phase": "المرحلة 3: التدقيق المستندي (STEP_08_COO)",
        "classification": "جلسة تدقيق منشأ (COO Review)",
        "description": "التدقيق في شهادة المنشأ وشهادات الحركة التفضيلية (EUR.1): صحة الأختام، الصياغة الإلزامية، وقواعد بلد المنشأ للحصول على الإعفاء الجمركي."
    },
    "inspection_certificate_review_sessions": {
        "arabic_name": "جلسات مراجعة شهادات الفحص والمطابقة (COC)",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "import_documentation",
        "phase": "المرحلة 3: التدقيق المستندي (STEP_08_COC)",
        "classification": "جلسة تدقيق رقابية (COC Review)",
        "description": "مراجعة شهادات الفحص والتفتيش قبل الشحن الصادرة من شركات الفحص الدولية (SGS, TÜV, Bureau Veritas, Intertek) للهيئات الرقابية."
    },
    "docs_customs_approval_sessions": {
        "arabic_name": "جلسات الاعتماد النهائي للمستندات الجمركية",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "docs_customs_approval",
        "phase": "المرحلة 3: الاعتماد النهائي (STEP_09)",
        "classification": "اعتماد نهائي حرج (Docs Customs Approval)",
        "description": "جلسة الفحص الشامل لكامل المستندات وإصدار أمر الإذن بالشحن للمورد بعد التأكد من مطابقة جميع المستندات لشروط الجمارك المصرية بنسبة 100%."
    },
    "customs_document_approvals": {
        "arabic_name": "قرارات وتوقيعات اعتماد المستندات الجمركية",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "docs_customs_approval",
        "phase": "المرحلة 3: الاعتماد النهائي (STEP_09)",
        "classification": "سجلات اعتماد إداري (Approval Records)",
        "description": "سجل توقيعات مسؤولي الجمارك واللوجستيات باعتماد المستندات وإبراء الذمة قبل إبحار السفينة."
    },
    "discrepancy_rectification_tickets": {
        "arabic_name": "تذاكر معالجة الفروق وتعديلات المورد المستندية",
        "domain": "التدقيق والمطابقة المستندية",
        "module": "docs_customs_approval",
        "phase": "المرحلة 3: الاعتماد النهائي (STEP_09)",
        "classification": "إدارة مشاكل وتعديلات (Discrepancy Tickets)",
        "description": "تذاكر إلكترونية لمتابعة الأخطاء المستندية المكتشفة مع المورد، طلب التعديل، ومتابعة رفع النسخ المعدلة."
    },

    # Customs Clearance & Port Operations
    "customs_clearance_records": {
        "arabic_name": "سجل التخليص الجمركي وإقرار 46 ك.م الشامل",
        "domain": "التخليص الجمركي وعمليات الموانئ",
        "module": "customs_clearance",
        "phase": "المرحلة 5: عمليات الميناء (STEPS 13-17)",
        "classification": "تشغيلي محوري جمركي (Clearance Master)",
        "description": "السجل الشامل للتخليص (101 عمود): رقم إقرار 46 ك.م، تاريخ القيد، المخلص المعين، المسار (أخضر/أصفر/أحمر)، لجان الكشف، وتقديرات الرسوم."
    },
    "customs_declaration_drafts": {
        "arabic_name": "مسودات وبيانات الإقرار الجمركي المبدئي",
        "domain": "التخليص الجمركي وعمليات الموانئ",
        "module": "import_documentation",
        "phase": "المرحلة 5: إقرار 46 ك.م (STEP_13)",
        "classification": "مسودة تشغيلية (Declaration Draft)",
        "description": "مسودة بنود الإقرار الجمركي قبل القيد الرسمي للمراجعة والتدقيق المسبق للقيم والبنود التعريفية."
    },
    "clearance_expense_invoices": {
        "arabic_name": "فواتير ومصروفات التخليص الجمركي الفعلية",
        "domain": "التخليص الجمركي والتسوية المالية",
        "module": "customs_clearance",
        "phase": "المرحلة 5: الحساب الجمركي (STEP_17)",
        "classification": "مالي تشغيلي (Clearance Invoices)",
        "description": "فواتير المصروفات الفعلية المدفوعة للجمارك وهيئة الميناء وجهات العرض وأتعاب المخلص."
    },
    "demurrage_policies": {
        "arabic_name": "سياسات وفترات سماح غرامات التأخير (D&D Policies)",
        "domain": "إدارة الغرامات والموانئ",
        "module": "demurrage_detention",
        "phase": "المرحلة 5: إدارة الغرامات (STEP_18)",
        "classification": "سياسات وقواعد عمل (Policies)",
        "description": "سياسات فترات السماح (Free Time) المتفق عليها مع الخطوط الملاحية (مثلاً 14 أو 21 يوماً) وشرائح الغرامة اليومية بعد انتهاء السماح."
    },
    "demurrage_trackings": {
        "arabic_name": "تتبع غرامات وفترات سماح الحاويات بالميناء",
        "domain": "إدارة الغرامات والموانئ",
        "module": "demurrage_detention",
        "phase": "المرحلة 5: إدارة الغرامات (STEP_18)",
        "classification": "تشغيلي ومالي حرج (Demurrage Tracker)",
        "description": "التتبع اليومي لحركة الحاويات داخل الدائرة الجمركية، حساب الأيام المتبقية من فترة السماح، وحساب مبالغ الغرامات التراكمية لحظياً."
    },
    "demurrage_rules": {
        "arabic_name": "قواعد احتساب شرائح غرامات التأخير اليومية",
        "domain": "إدارة الغرامات والموانئ",
        "module": "freight_data_connector",
        "phase": "المرحلة 5: إدارة الغرامات (STEP_18)",
        "classification": "محرك قواعد حسابية (Calculation Rules)",
        "description": "قواعد حساب الغرامة المتصاعدة: الشريحة الأولى (أول 7 أيام)، الشريحة الثانية (اليوم 8-14)، الشريحة الثالثة وما بعدها."
    },
    "port_demurrage_tariff": {
        "arabic_name": "تعريفة رسوم وأرضيات الموانئ المصرية الرسمية",
        "domain": "إدارة الغرامات والموانئ",
        "module": "freight_data_connector",
        "phase": "المرحلة 5: إدارة الغرامات (STEP_18)",
        "classification": "بيانات مرجعية رسمية (Port Tariffs)",
        "description": "التعريفة الرسمية المقررة من هيئات الموانئ المصرية (الإسكندرية، الدخيلة، دمياط، بورسعيد، السخنة) لرسوم التخزين والأرضيات."
    },

    # Banking & Financial Approvals
    "banking_document_sessions": {
        "arabic_name": "جلسات توثيق واعتماد نموذج 4 البنكي وإجراءات البنك",
        "domain": "الاعتمادات البنكية والنقد الأجنبي",
        "module": "import_documentation",
        "phase": "المرحلة 4: نموذج 4 البنكي (STEP_12)",
        "classification": "تشغيلي وقانوني بنكي (Bank Form 4)",
        "description": "متابعة استخراج نموذج 4 البنكي وإجراءات فتح الاعتماد المستندي (L/C) أو التحصيل المستندي (CAD) وتدبير العملة."
    },
    "import_budget_approvals": {
        "arabic_name": "اعتمادات الميزانية التقديرية للشحنة ومراقبة الانحرافات",
        "domain": "المالية والموازنات الاستيرادية",
        "module": "financial_approval",
        "phase": "المرحلة 2: اعتمادات الميزانية (STEP_04)",
        "classification": "رقابة مالية وموازنات (Budget Approvals)",
        "description": "اعتماد الموازنة المالية التقديرية للشحنة من الإدارة المالية، وتتبع حدود الصرف المسموح بها ونسب الحيود."
    },
    "payment_request_sessions": {
        "arabic_name": "طلبات سداد دفعات الموردين ومصروفات الشحنة",
        "domain": "المالية وسداد الموردين",
        "module": "financial_approval",
        "phase": "المرحلة 2: سداد الموردين (STEP_04)",
        "classification": "تشغيلي مالي (Payment Requests)",
        "description": "دورة طلبات سداد الدفعات للموردين (مقدم، عند الشحن، عند الوصول) وسداد فواتير الشحن والجمارك ومرفقات التحويل البنكي."
    },
    "budget_variance_logs": {
        "arabic_name": "سجل فروق وانحرافات الميزانية التقديرية عن الفعلي",
        "domain": "الرقابة المالية والموازنات",
        "module": "financial_approval",
        "phase": "المرحلة 6: التسوية المالية (STEP_20)",
        "classification": "رقابي وتحليلي (Variance Logs)",
        "description": "سجل رصد أي تجاوز أو انحراف في التكاليف الفعلية عن الميزانية التقديرية للشحنة مع بيان الأسباب والمسؤوليات."
    },
    "budget_variance_settings": {
        "arabic_name": "إعدادات ونسب سماح انحرافات الميزانية المسموحة",
        "domain": "الرقابة المالية والموازنات",
        "module": "financial_approval",
        "phase": "البيانات المرجعية العامة",
        "classification": "إعدادات رقابية (Threshold Settings)",
        "description": "نسب التفاوت والانحراف المسموح بها في بنود الميزانية قبل طلب اعتماد إضافي من الإدارة العليا."
    },
    "swift_extraction_batches": {
        "arabic_name": "دفعات استخراج وقراءة رسائل السويفت البنكية بالذكاء الاصطناعي",
        "domain": "المعالجة الآلية للسويفت والوثائق",
        "module": "financial_approval",
        "phase": "المرحلة 2 و 4: العمليات البنكية",
        "classification": "أتمتة وذكاء اصطناعي (AI SWIFT OCR)",
        "description": "المعالجة الآلية الذكية لملفات السويفت البنكية (MT103 / MT700) وقراءة الحقول والأرقام آلياً ومطابقتها بالدفعات."
    },
    "swift_extraction_fields": {
        "arabic_name": "حقول وبيانات السويفت المستخرجة آلياً",
        "domain": "المعالجة الآلية للسويفت والوثائق",
        "module": "financial_approval",
        "phase": "المرحلة 2 و 4: العمليات البنكية",
        "classification": "بيانات استخراج تفصيلية (Extracted Fields)",
        "description": "الحقول الدقيقة لرسالة السويفت: المبلغ، العملة، تاريخ الاستحقاق، البنك المراسل، بيانات المستفيد، ورقم المرجع البنكي (Field 20)."
    },
    "ocr_corrections_log": {
        "arabic_name": "سجل تصحيحات القراءة الآلية لرسائل السويفت",
        "domain": "المعالجة الآلية للسويفت والوثائق",
        "module": "financial_approval",
        "phase": "المرحلة 2 و 4: العمليات البنكية",
        "classification": "سجل تعلم ذكاء اصطناعي (AI Learning Log)",
        "description": "سجل التصحيحات اليدوية التي يجريها المستخدم على الحقول المستخرجة لتحسين دقة نموذج القراءة الآلية مستقبلاً."
    },

    # Warehouse Receiving
    "warehouse_receiving_records": {
        "arabic_name": "محاضر الفحص والاستلام المخزني وإذن الإضافة (GRN)",
        "domain": "المخازن والاستلام الفعلي",
        "module": "warehouse_receiving",
        "phase": "المرحلة 6: الاستلام المخزني (STEP_19)",
        "classification": "تشغيلي مخزني نهائي (Warehouse GRN)",
        "description": "محضر الفحص والاستلام بالمستودع (41 عمود): الكميات السليمة المستلمة، العجز، التوالف، رقم إذن الإضافة المخزني، والتسكين على الرفوف."
    },

    # Financial Settlement & Landed Cost
    "financial_settlement_records": {
        "arabic_name": "سجل التسوية المالية النهائية وتكلفة الوصول (Landed Cost)",
        "domain": "التسوية المالية وتكلفة الوصول",
        "module": "financial_settlement",
        "phase": "المرحلة 6: تسوية التكلفة (STEP_20)",
        "classification": "محرك تسوية مالي شامل (Landed Cost Settlement)",
        "description": "الحساب الختامي لتكلفة البضاعة المستوردة (Landed Cost): تجميع تكلفة الشراء، النولون، التأمين، الجمارك، الضرائب، أتعاب التخليص، النقل، وحساب تكلفة الوحدة."
    },
    "tax_rates": {
        "arabic_name": "أسعار وفئات الضرائب العامة المعمول بها",
        "domain": "البيانات المرجعية المالية والضريبية",
        "module": "financial_settlement",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية ضريبية (Tax Master)",
        "description": "دليل نسب الضرائب المطبقة (ضريبة أرباح تجارية وصناعية، ضريبة الخصم والإضافة، إلخ) مع تواريخ سريان كل نسبة."
    },

    # File Closure
    "file_closure_records": {
        "arabic_name": "محاضر الإغلاق والأرشفة النهائية للملف الاستيرادي",
        "domain": "إغلاق الملفات والأرشفة القانونية",
        "module": "file_closure",
        "phase": "المرحلة 6: الإغلاق النهائي (STEP_21)",
        "classification": "إغلاق وأرشفة نظامية (Final Closure)",
        "description": "محضر التحقق الختامي قبل إغلاق الملف: مطابقة الفواتير، سداد المخلص، إذن الإضافة، تصفية العهد، والأرشفة الرقمية الكاملة."
    },

    # Master Data & Reference
    "countries": {
        "arabic_name": "دليل الدول ورموزها الدولية (ISO)",
        "domain": "البيانات المرجعية الجغرافية",
        "module": "transport_locations",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Geo Master)",
        "description": "الدول ورموزها المعيارية (ISO-2, ISO-3) وأكواد الاتصال ونطاقات الشحن الجغرافي."
    },
    "cities": {
        "arabic_name": "دليل المدن والمحافظات والمناطق اللوجستية",
        "domain": "البيانات المرجعية الجغرافية",
        "module": "transport_locations",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Geo Master)",
        "description": "المدن والمحافظات الصناعية والمناطق الحرة داخل مصر وخارجها."
    },
    "transport_locations": {
        "arabic_name": "الموانئ البحرية والجوية والمنافذ الجافة",
        "domain": "البيانات المرجعية اللوجستية",
        "module": "transport_locations",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية لوجستية (Ports Master)",
        "description": "الموانئ العالمية والمصرية (أكواد UN/LOCODE): الإسكندرية، الدخيلة، دمياط، العين السخنة، ميناء القاهرة الجوي، والموانئ الجافة."
    },
    "currencies": {
        "arabic_name": "دليل العملات الأجنبية والمحلية",
        "domain": "البيانات المرجعية المالية",
        "module": "currencies",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية مالية (Currency Master)",
        "description": "العملات المتداولة (USD, EUR, GBP, CNY, EGP) وأكوادها المعيارية وعدد الخانات العشرية."
    },
    "exchange_rates": {
        "arabic_name": "أسعار الصرف الرسمية وأسعار صرف الجمارك المعلنة",
        "domain": "البيانات المرجعية المالية",
        "module": "currencies",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مالية متغيرة (Exchange Rates)",
        "description": "أسعار الصرف اليومية وأسعار صرف الجمارك الشهرية الرسمية المعتمدة لحساب الرسوم والضرائب."
    },
    "incoterms": {
        "arabic_name": "شروط ومصطلحات التجارة الدولية (Incoterms 2020)",
        "domain": "البيانات المرجعية التجارية",
        "module": "incoterms",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية دولية (Incoterms Master)",
        "description": "شروط التجارة الدولية المعتمدة من غرفة التجارة الدولية (EXW, FOB, CFR, CIF, DDP, DAP, FCA, CPT, CIP)."
    },
    "cost_items": {
        "arabic_name": "دليل بنود التكاليف والمصروفات اللوجستية المعيارية",
        "domain": "البيانات المرجعية التجارية والمالية",
        "module": "incoterms",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية (Cost Master)",
        "description": "تصنيف كافة بنود التكاليف الممكنة في الشحن والاستيراد وربطها بمسؤولية البائع أو المشتري."
    },
    "incoterm_responsibilities": {
        "arabic_name": "مصفوفة مسؤوليات البائع والمشتري لكل شرط تجاري",
        "domain": "البيانات المرجعية التجارية",
        "module": "incoterms",
        "phase": "البيانات المرجعية العامة",
        "classification": "مصفوفة قواعد عمل (Responsibility Matrix)",
        "description": "تحديد الطرف المسؤول عن تحمل كل بند تكلفة ومخاطر (البائع أم المشتري) لكل شرط تجاري Incoterm."
    },
    "external_service_providers": {
        "arabic_name": "دليل مقدمي الخدمات الخارجية (مخلصين/خطوط/شحن)",
        "domain": "مزودو الخدمات والشركاء",
        "module": "external_service_providers",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات أساسية محورية (Service Providers)",
        "description": "سجل المخلصين الجمركيين، الخطوط الملاحية، وكلاء الشحن، شركات النقل البري، وشركات التأمين وبيانات التقييم والاعتماد."
    },
    "expense_catalog": {
        "arabic_name": "كتالوج المصروفات الاستيرادية المعياري الموحد",
        "domain": "البيانات المرجعية المالية",
        "module": "expense_catalog",
        "phase": "البيانات المرجعية العامة",
        "classification": "بيانات مرجعية مالية (Expense Catalog)",
        "description": "دليل موحد لكافة أنواع المصروفات المحتملة في العملية الاستيرادية وتصنيفها المحاسبي وشجرة الحسابات."
    },
    "formal_letters_history": {
        "arabic_name": "سجل الخطابات الرسمية والتفويضات الجمركية والبنكية",
        "domain": "المستندات والخطابات الرسمية",
        "module": "formal_letters",
        "phase": "المراحل 3-5: التنسيق الرسمي",
        "classification": "مستندي رسمي (Formal Letters)",
        "description": "سجل الخطابات الصادرة للجمارك، الموانئ، البنوك، التوكيلات الملاحية، والتفويضات الرسمية الموقعة."
    },

    # Lifecycle, Tasks & Workflow Engine
    "shipment_stage_activity": {
        "arabic_name": "سجل أنشطة وتتبع مراحل الشحنة لحظياً (Lifecycle)",
        "domain": "محرك دورة الحياة وسير العمل",
        "module": "lifecycle_board",
        "phase": "جميع المراحل (Lifecycle Engine)",
        "classification": "محرك مسار العمل (Workflow Engine)",
        "description": "السجل التشغيلي اللحظي لمراحل وخطوات الشحنة: تاريخ ووقت بدء الخطوة، تاريخ اكتمالها، المستخدم المنفذ، والملاحظات."
    },
    "step_configs": {
        "arabic_name": "إعدادات وتكوين خطوات ومراحل دورة الحياة",
        "domain": "إعدادات النظام وسير العمل",
        "module": "lifecycle_board",
        "phase": "البيانات المرجعية العامة",
        "classification": "إعدادات نظام (Step Configurations)",
        "description": "تكوين وترتيب خطوات دورة الحياة، ألوانها، أيقوناتها، شروط التحقق التلقائي، والخطوات التابعة."
    },
    "step_config_audit_logs": {
        "arabic_name": "سجل تدقيق التعديلات على تكوين خطوات النظام",
        "domain": "إعدادات النظام والرقابة",
        "module": "lifecycle_board",
        "phase": "الرقابة العامة",
        "classification": "سجل تدقيق رقابي (Audit Log)",
        "description": "سجل حركات تعديل مسارات العمل أو قواعد الانتقال بين المراحل لضمان الحوكمة البرمجية."
    },
    "pending_reference_records": {
        "arabic_name": "السجلات المرجعية المعلقة قيد المزامنة",
        "domain": "مزامنة البيانات وإدارة المراجع",
        "module": "lifecycle_board",
        "phase": "تشغيل داخلي",
        "classification": "تشغيلي مساعد (Sync Records)",
        "description": "إدارة السجلات التي تنتظر ربطها بمرجع أو اكتمال تدقيقها من فرق العمل الخارجية."
    },
    "smart_tasks": {
        "arabic_name": "المهام الذكية المؤتمتة وتكليفات فرق العمل",
        "domain": "إدارة المهام والأتمتة الذكية",
        "module": "smart_tasks",
        "phase": "جميع المراحل (Task Automation)",
        "classification": "محرك مهام ذكي (Smart Tasks)",
        "description": "توليد وإسناد المهام التشغيلية تلقائياً لأعضاء الفريق عند وصول الشحنة لمرحلة معينة وتتبع نسب الإنجاز ومواعيد الاستحقاق."
    },
    "import_file_checklist_items": {
        "arabic_name": "قوائم التحقق الذكية والتفتيش للملف الاستيرادي",
        "domain": "قوائم التحقق والمطابقة",
        "module": "smart_checklists",
        "phase": "جميع المراحل (Smart Checklists)",
        "classification": "قوائم تدقيق ذكية (Checklists)",
        "description": "قوائم الفحص الذاتية لكل خطوة ومرحلة استيرادية للتأكد من استيفاء المتطلبات الفنية والمستندية قبل الاعتماد."
    },
    "recalculation_dependency_map": {
        "arabic_name": "خريطة اعتماديات إعادة الحساب المالي الآلي",
        "domain": "المحرك الحسابي والاعتماديات",
        "module": "recalculation",
        "phase": "جميع المراحل الحسابية",
        "classification": "محرك اعتماديات (Dependency Map)",
        "description": "تحديد شبكة التأثيرات المتسلسلة: عند تعديل سعر الصرف أو قيمة النولون يتم تلقائياً تحديث الجمارك وضريبة الجدول وتكلفة الوحدة."
    },
    "recalculation_logs": {
        "arabic_name": "سجل عمليات إعادة الحساب المالي المتتالية",
        "domain": "المحرك الحسابي والاعتماديات",
        "module": "recalculation",
        "phase": "جميع المراحل الحسابية",
        "classification": "سجل عمليات (Recalculation Log)",
        "description": "توثيق عمليات إعادة الاحتساب التي تمت وتاريخها والتغيرات المالية الناتجة عنها ومقارنتها بالقيم السابقة."
    },
    "saved_simulation_scenarios": {
        "arabic_name": "سيناريوهات المحاكاة الاستيرادية المحفوظة",
        "domain": "المحاكاة والتخطيط المالي",
        "module": "simulation",
        "phase": "المرحلة 1: التخطيط المسبق",
        "classification": "أداة محاكاة (Simulation Tool)",
        "description": "حفظ سيناريوهات دراسة الجدوى الاستيرادية التقديرية لمقارنة التكاليف تحت فرضيات أسعار صرف وبنود جمركية مختلفة."
    },
    "system_parameters": {
        "arabic_name": "معاملات ومتغيرات وإعدادات النظام العامة",
        "domain": "إعدادات المنظومة العامة",
        "module": "common",
        "phase": "إعدادات النظام",
        "classification": "إعدادات نظام (System Parameters)",
        "description": "المعاملات المركزية: نسب التحذير، فترات التنبيه المسبق، عناوين الخوادم، وإعدادات الربط التقني."
    },

    # Knowledge, Integrations & Autonomous Guide
    "guide_entries": {
        "arabic_name": "مدخلات دليل الخبرة المعرفي والحلول التشغيلية",
        "domain": "قاعدة المعرفة والذكاء المكتسب",
        "module": "experience_guide",
        "phase": "قاعدة المعرفة العامة",
        "classification": "قاعدة معرفة تشغيلية (Knowledge Base)",
        "description": "مستودع الخبرات الجمركية واللوجستية المكتسبة: حلول مشاكل العرض الرقابي السابقة، استثناءات الموانئ، والبدائل المعتمدة."
    },
    "guide_entry_scopes": {
        "arabic_name": "نطاقات تطبيق مدخلات دليل الخبرة المعرفي",
        "domain": "قاعدة المعرفة والذكاء المكتسب",
        "module": "experience_guide",
        "phase": "قاعدة المعرفة العامة",
        "classification": "نطاقات تطبيق (Scopes)",
        "description": "ربط قاعدة المعرفة ببنود جمركية محددة (HS Codes) أو موانئ معينة أو جهات عرض رقابية."
    },
    "autonomous_pattern_audit_logs": {
        "arabic_name": "سجل تدقيق الأنماط الذاتية المكتشفة",
        "domain": "الذكاء الاصطناعي والتعلم الذاتي",
        "module": "experience_guide",
        "phase": "الذكاء الاصطناعي الداخلي",
        "classification": "سجل ذكاء ذاتي (AI Pattern Log)",
        "description": "رصد وتوثيق الأنماط المتكررة في زمن الإفراج أو الرسوم لاقتراح تحسينات تشغيلية ذاتية."
    },
    "inbound_email_logs": {
        "arabic_name": "سجل البريد الإلكتروني الوارد وتحليل المرفقات",
        "domain": "التكامل والبريد الذكي",
        "module": "smart_email_listener",
        "phase": "التواصل والتكامل الآلي",
        "classification": "تكامل وأتمتة (Email Listener)",
        "description": "استقبال وقراءة رسائل البريد الإلكتروني الواردة من الخطوط والوكلاء واستخراج المرفقات وتصنيفها آلياً."
    },
    "email_settings": {
        "arabic_name": "إعدادات خوادم البريد الإلكتروني والتصنيف",
        "domain": "التكامل والبريد الذكي",
        "module": "smart_email_listener",
        "phase": "إعدادات النظام",
        "classification": "إعدادات تكامل (Email Configuration)",
        "description": "تكوين خوادم البريد الوارد (IMAP/POP3) وخوادم الإرسال (SMTP) وقواعد فلترة الرسائل اللوجستية."
    },
    "production_sync_logs": {
        "arabic_name": "سجلات مزامنة البيانات بين البيئات",
        "domain": "المزامنة والبنية التحتية",
        "module": "production_sync",
        "phase": "البنية التحتية",
        "classification": "مزامنة تقنية (Sync Logs)",
        "description": "توثيق عمليات مزامنة البيانات المرجعية بين بيئات التطوير والتشغيل الفعلي والتحديثات المركزية."
    },
    "external_api_quota_logs": {
        "arabic_name": "سجل استهلاك ومراقبة حصص الـ APIs الخارجية",
        "domain": "التكامل والبنية التحتية",
        "module": "freight_data_connector",
        "phase": "البنية التحتية",
        "classification": "مراقبة تقنية (API Quotas)",
        "description": "مراقبة حدود الاستهلاك اليومي والشهر لمفاتيح الربط الخارجي مع بوابات التتبع العالمية ومصادر البيانات."
    },

    # Security, Users & Governance
    "users": {
        "arabic_name": "دليل المستخدمين وحسابات الدخول",
        "domain": "الأمان وإدارة المستخدمين (RBAC)",
        "module": "users",
        "phase": "إدارة النظام والأمان",
        "classification": "بيانات أساسية وأمان (Users Master)",
        "description": "بيانات حسابات الموظفين والمستخدمين: اسم المستخدم، البريد، كلمة المرور المشفرة (Argon2)، الدور الوظيفي، وحالة النشاط."
    },
    "roles": {
        "arabic_name": "أدوار وصلاحيات النظام (RBAC Roles)",
        "domain": "الأمان وإدارة المستخدمين (RBAC)",
        "module": "users",
        "phase": "إدارة النظام والأمان",
        "classification": "حوكمة وأمان (Roles Master)",
        "description": "هيكل الأدوار الوظيفية: مدير استيراد، أخصائي لوجستيات، مسؤول جمارك، مراجع مالي، مسؤول مخازن، ومدير نظام."
    },
    "permissions": {
        "arabic_name": "دليل الصلاحيات التشغيلية التفصيلية",
        "domain": "الأمان وإدارة المستخدمين (RBAC)",
        "module": "users",
        "phase": "إدارة النظام والأمان",
        "classification": "حوكمة وأمان (Permissions Master)",
        "description": "شجرة الصلاحيات البرمجية الدقيقة (قراءة، إنشاء، تعديل، حذف، اعتماد مالي، تجاوز ميزانية، إغلاق ملف)."
    },
    "role_permissions": {
        "arabic_name": "مصفوفة ربط الأدوار الوظيفية بالصلاحيات",
        "domain": "الأمان وإدارة المستخدمين (RBAC)",
        "module": "users",
        "phase": "إدارة النظام والأمان",
        "classification": "مصفوفة حوكمة (Role Permissions)",
        "description": "جدول الربط المعياري الذي يحدد الصلاحيات المصرح بها لكل دور وظيفي في المنظومة."
    },
    "user_permissions": {
        "arabic_name": "الصلاحيات الخاصة والاستثنائية للمستخدمين",
        "domain": "الأمان وإدارة المستخدمين (RBAC)",
        "module": "users",
        "phase": "إدارة النظام والأمان",
        "classification": "حوكمة واستثناءات (User Overrides)",
        "description": "صلاحيات مباشرة استثنائية تُمنح لمستخدم بعينه خارج صلاحيات دوره الوظيفي القياسي وتاريخ منحها ومن منحها."
    },
    "revoked_tokens": {
        "arabic_name": "قائمة رموز التوثيق الملغاة (JWT Blacklist)",
        "domain": "الأمان والحماية الجنائية",
        "module": "auth",
        "phase": "الأمان الجنائي",
        "classification": "أمان وحماية (Token Blacklist)",
        "description": "قائمة الرموز الأمنية التي تم إبطالها فور تسجيل الخروج لمنع إعادة استخدامها من قبل أطراف غير مصرح لها."
    },
    "audit_logs": {
        "arabic_name": "سجل الرقابة والتدقيق الأمني لجميع حركات النظام",
        "domain": "الحوكمة والرقابة والتدقيق (Audit)",
        "module": "audit_logs",
        "phase": "جميع المراحل (Governance & Audit)",
        "classification": "سجل تدقيق أمني (Audit Trail)",
        "description": "التسجيل الصارم غير القابل للتعديل لكل حركة في النظام: المستخدم، عنوان IP، الجدول المستهدف، نوع العملية، والقيم السابقة والجديدة."
    },
    "concurrency_conflict_logs": {
        "arabic_name": "سجل معالجة تعارض التزامن والنزاعات التحديثية",
        "domain": "تكامل البيانات وتزامن العمليات",
        "module": "common",
        "phase": "البنية التحتية والبيانات",
        "classification": "سلامة بيانات (Concurrency Logs)",
        "description": "حماية البيانات من الكتابة المتزامنة المتضاربة وتوثيق حالات التنازع عند تعديل نفس السجل من مستخدمين في ذات اللحظة."
    },
    "system_notifications": {
        "arabic_name": "الإشعارات والتنبيهات النظامية للمستخدمين",
        "domain": "الإشعارات والاتصال الداخلي",
        "module": "notifications",
        "phase": "جميع المراحل (Alerts & Notifications)",
        "classification": "إشعارات تشغيلية (Notifications)",
        "description": "التنبيهات الفورية للمستخدمين: اقتراب انتهاء صلاحية ACID، وصول سفينة، تجاوز مهلة فترات السماح، أو طلب اعتماد مالي."
    },
    "upload_sessions": {
        "arabic_name": "جلسات الرفع الذكي للمستندات والملفات",
        "domain": "المستندات والأرشيف الذكي",
        "module": "smart_document_upload",
        "phase": "جميع المراحل (Document Ingestion)",
        "classification": "مستندي مساعد (Upload Sessions)",
        "description": "إدارة عمليات رفع الملفات المتعددة، التحقق من نوع وحجم الملف وفحصه أمنياً قبل ربطه بالشحنة."
    }
}

# ════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS FOR COLUMN METADATA & DESCRIPTIONS
# ════════════════════════════════════════════════════════════════
COLUMN_ARABIC_PATTERNS = [
    (r".*_id$", "المعرف الرقمي الفريد لسجل {entity}"),
    (r"^is_active$", "حالة تفعيل السجل بالنظام (الحذف المنطقي Soft Delete)"),
    (r"^deleted_at$", "تاريخ وتوقيت الحذف المنطقي للسجل"),
    (r"^deleted_by$", "المستخدم الذي أجرى عملية الحذف المنطقي"),
    (r"^created_at$", "تاريخ وتوقيت إنشاء السجل بالنظام لأول مرة"),
    (r"^updated_at$", "تاريخ وتوقيت آخر تعديل تم على السجل"),
    (r"^created_by$", "المستخدم المنشئ لهذا السجل"),
    (r"^updated_by$", "آخر مستخدم قام بتعديل هذا السجل"),
    (r"^notes$", "ملاحظات وتعليقات تشغيلية توضيحية"),
    (r"^status$", "الحالة التشغيلية الحالية للسجل في دورة العمل"),
    (r"^priority$", "مستوى الأولوية والأهمية (عادي / عاجل / حرج)"),
    (r"^description$", "الوصف التفصيلي للبند أو الكيان"),
    (r"^name_ar$", "الاسم المعتمد باللغة العربية"),
    (r"^name_en$", "الاسم المعتمد باللغة الإنجليزية"),
    (r"^currency_code$", "كود العملة المالية المعتمدة (USD, EUR, EGP)"),
    (r"^exchange_rate$", "سعر صرف العملة المعتمد مقابل الجنيه المصري"),
    (r"^cbm$", "الحجم الإجمالي للبضاعة بالمتر المكعب (CBM)"),
    (r"^gross_weight$", "الوزن الإجمالي القائم للبضاعة شاملاً التغليف"),
    (r"^net_weight$", "الوزن الصافي الفعلي للبضاعة بدون العبوات الخارجية"),
    (r"^chargeable_weight$", "الوزن الخاضع لاحتساب الأجر (الأكبر بين الفعلي والحجمي)"),
    (r"^volumetric_weight$", "الوزن الحجمي التقديري للبضاعة (معامل الشحن الجوي)"),
    (r"^total_packages$", "إجمالي عدد الطرود أو العبوات المادية"),
    (r"^package_type.*", "نوع التعبئة والتغليف (طبالي / كراتين / حاويات)"),
    (r"^fob_.*", "القيمة وفق شرط التسليم فوب (سعر البضاعة ببلد الشحن)"),
    (r"^cif_.*", "القيمة الإجمالية سيف (سعر الشراء + النولون + التأمين)"),
    (r"^freight_.*", "تكلفة نولون الشحن البحري أو الجوي"),
    (r"^insurance_.*", "قيمة قسط وثيقة التأمين البحري على البضاعة"),
    (r"^customs_duty.*", "قيمة أو نسبة الضريبة الجمركية المقررة على البند"),
    (r"^vat_.*", "قيمة أو نسبة ضريبة القيمة المضافة المقررة على الشحنة"),
    (r"^schedule_tax.*", "قيمة أو نسبة ضريبة الجدول الاستهلاكية إن وجدت"),
    (r"^development_fee.*", "رسم تنمية الموارد المالية المقررة قانوناً"),
    (r"^clearance_fee.*", "أتعاب مكتب أو شركة التخليص الجمركي"),
    (r"^demurrage_.*", "بيانات وقيم غرامات التأخير والأرضيات بالميناء"),
    (r"^acid_.*", "بيانات ورقم القيد المبدئي للشحنة على منصة نافذة (ACID)"),
    (r"^bl_number.*", "رقم بوليصة الشحن الرسمية الصادرة من الخط الملاحي"),
    (r"^container_number.*", "الرقم التعريفي المميز للحاوية البحرية"),
    (r"^hs_code.*", "كود البند الجمركي الدولي المنسق المكون من 6 إلى 10 أرقام"),
    (r"^declaration_number.*", "رقم إقرار 46 ك.م الجمركي الصادر من المنفذ"),
]

def infer_column_arabic_description(table_name: str, col_name: str, col_type: str, is_pk: bool, fk_target: str) -> str:
    if is_pk:
        tbl_info = TABLE_METADATA.get(table_name, {})
        ar_name = tbl_info.get("arabic_name", table_name)
        return f"المفتاح الأساسي والرقم التعريفي الفريد لـ {ar_name}"
    
    if fk_target:
        target_tbl, target_col = fk_target.split(".") if "." in fk_target else (fk_target, "id")
        target_info = TABLE_METADATA.get(target_tbl, {})
        target_ar = target_info.get("arabic_name", target_tbl)
        return f"مفتاح أجنبي رابط يشير إلى {target_ar} ({target_tbl}.{target_col})"
    
    for pat, desc_template in COLUMN_ARABIC_PATTERNS:
        if re.match(pat, col_name, re.IGNORECASE):
            return desc_template
            
    # Generic intelligent fallbacks
    if "date" in col_name.lower():
        return f"تاريخ {col_name.replace('_', ' ')} المعتمد تشغيلياً"
    if "amount" in col_name.lower() or "price" in col_name.lower() or "cost" in col_name.lower():
        return f"القيمة المالية لـ {col_name.replace('_', ' ')}"
    if "code" in col_name.lower() or "number" in col_name.lower() or "no" in col_name.lower():
        return f"الكود أو الرقم التعريفي لـ {col_name.replace('_', ' ')}"
    if "rate" in col_name.lower() or "percent" in col_name.lower():
        return f"النسبة المئوية أو المعدل المطبق لـ {col_name.replace('_', ' ')}"
    
    return f"حقل بيانات {col_name.replace('_', ' ')} المستخدم في عمليات النظام"


# ════════════════════════════════════════════════════════════════
# MAIN EXCEL GENERATION SCRIPT
# ════════════════════════════════════════════════════════════════
def build_system_atlas_excel(output_file: str):
    print("Beginning generation of System Architecture & Database Atlas...")
    wb = openpyxl.Workbook()
    wb.remove(wb.active) # remove blank default sheet

    # Colors & Theme Palette
    NAVY_HEX = "1B365D"       # Corporate Dark Navy
    SLATE_HEX = "2C3E50"      # Professional Slate
    LIGHT_BLUE_HEX = "EBF3FA" # Subtle header/group fill
    ZEBRA_HEX = "F8F9FA"      # Alternating row fill
    BORDER_HEX = "D0D5DD"     # Clean subtle border

    # Styles
    navy_fill = PatternFill(start_color=NAVY_HEX, end_color=NAVY_HEX, fill_type="solid")
    slate_fill = PatternFill(start_color=SLATE_HEX, end_color=SLATE_HEX, fill_type="solid")
    light_blue_fill = PatternFill(start_color=LIGHT_BLUE_HEX, end_color=LIGHT_BLUE_HEX, fill_type="solid")
    zebra_fill = PatternFill(start_color=ZEBRA_HEX, end_color=ZEBRA_HEX, fill_type="solid")

    pk_fill = PatternFill(start_color="E8F5E9", end_color="E8F5E9", fill_type="solid") # soft green
    fk_fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid") # soft blue

    font_main_title = Font(name="Segoe UI", size=16, bold=True, color="FFFFFF")
    font_sub_title = Font(name="Segoe UI", size=11, italic=True, color="FFFFFF")
    font_sec_header = Font(name="Segoe UI", size=13, bold=True, color=NAVY_HEX)
    font_tbl_header = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
    font_kpi_num = Font(name="Segoe UI", size=20, bold=True, color=NAVY_HEX)
    font_kpi_lbl = Font(name="Segoe UI", size=10, bold=True, color="555555")

    font_data_bold = Font(name="Segoe UI", size=10, bold=True, color="1E293B")
    font_data_regular = Font(name="Segoe UI", size=10, color="334155")
    font_code = Font(name="Consolas", size=9, bold=True, color="0F172A")

    thin_side = Side(border_style="thin", color=BORDER_HEX)
    cell_border = Border(left=thin_side, right=thin_side, top=thin_side, bottom=thin_side)
    thick_bottom = Border(bottom=Side(border_style="medium", color=NAVY_HEX), left=thin_side, right=thin_side, top=thin_side)

    align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
    align_right = Alignment(horizontal="right", vertical="center", wrap_text=True)
    align_left = Alignment(horizontal="left", vertical="center", wrap_text=True)

    # ════════════════════════════════════════════════════════════════
    # SHEET 1: لوحة المعمارية والنظام (Overview & Architecture)
    # ════════════════════════════════════════════════════════════════
    print("Building Sheet 1: لوحة المعمارية والنظام...")
    ws1 = wb.create_sheet(title="لوحة المعمارية والنظام")
    ws1.views.sheetView[0].rightToLeft = True

    # Title Banner
    ws1.merge_cells("A1:G2")
    title_cell = ws1.cell(row=1, column=1, value="أطلس المعمارية ومكونات النظام الشامل — ImportFlow ERP (Sorour Logistics)")
    title_cell.font = font_main_title
    title_cell.fill = navy_fill
    title_cell.alignment = align_center

    ws1.merge_cells("A3:G3")
    sub_cell = ws1.cell(row=3, column=1, value="الدليل المرجعي الكامل: 110 جدول في قاعدة البيانات • 2,358 حقلاً • 154 علاقة تكاملية • 6 مراحل و 23 خطوة تشغيلية")
    sub_cell.font = font_sub_title
    sub_cell.fill = slate_fill
    sub_cell.alignment = align_center

    # KPI Summary Cards (Row 5 to 6)
    kpis = [
        ("إجمالي الجداول", "110", "A5:A6"),
        ("إجمالي الحقول والأعمدة", "2,358", "B5:B6"),
        ("علاقات المفاتيح الأجنبية", "154", "C5:C6"),
        ("المراحل الكبرى (Phases)", "6 مراحل", "D5:D6"),
        ("الخطوات التشغيلية (Steps)", "23 خطوة", "E5:E6"),
        ("الموديولات البرمجية", "35+ موديول", "F5:G6"),
    ]
    for lbl, val, rng in kpis:
        c1_str, c2_str = rng.split(":")
        ws1.merge_cells(rng)
        cell = ws1[c1_str]
        cell.value = f"{val}\n{lbl}"
        cell.font = font_kpi_num
        cell.fill = light_blue_fill
        cell.alignment = align_center
        cell.border = cell_border

    # Technical Stack Section
    ws1.cell(row=8, column=1, value="1. البنية التقنية والمعمارية للمنظومة (Technology Stack & Infrastructure)").font = font_sec_header
    
    stack_headers = ["المكون المعماري", "التقنية / الأداة", "الإصدار والتفاصيل", "الوظيفة والمسؤولية في النظام"]
    for col_idx, h in enumerate(stack_headers, start=1):
        c = ws1.cell(row=9, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    stack_rows = [
        ("طبقة الواجهة وتطبيق السطح المكتبي (Frontend UI)", "Flutter Desktop", "Flutter 3.x (Windows Desktop Native)", "تطبيق السطح المكتبي لشركة سرور للخدمات اللوجستية، إدارة الحالة باستخدام Riverpod، والتنقل بـ GoRouter، ودعم كامل للغة العربية والاتجاه من اليمين لليسار (RTL)."),
        ("خادم التطبيق ومحرك الخدمات (Backend API)", "FastAPI", "Python 3.12, FastAPI, Pydantic v2", "خادم RESTful API فائق السرعة، معالجة غير متزامنة (Async)، توثيق آلي عبر OpenAPI/Swagger، وتحقق صارم من البيانات بـ Pydantic v2."),
        ("طبقة النمذجة وقاعدة البيانات (ORM & DB)", "SQLAlchemy & SQLite", "SQLAlchemy 2.0, SQLite (WAL Mode)", "قاعدة بيانات محلية متينة مع تفعيل وضع WAL، فرض صارم للمفاتيح الأجنبية (PRAGMA foreign_keys = ON)، وترحيل المخططات عبر Alembic."),
        ("محرك الحساب الجمركي المصري (Customs Engine)", "Custom Engine Service", "modules/customs_tariff/service.py", "محرك حساب جمركي مصري إلزامي يطبق معادلات CIF -> ضريبة الوارد -> وعاء القيمة المضافة -> ضريبة الجدول -> الرسوم الإضافية."),
        ("محرك تكلفة الوصول الشاملة (Landed Cost Engine)", "Landed Cost Service", "modules/financial_settlement/service.py", "احتساب التكلفة الاستيرادية الشاملة بتجميع 13 عنصراً وتوزيع المصروفات المشتركة على بنود أمر الشراء بالقيمة أو الوزن/الحجم."),
        ("محرك الحجم والوزن الحجمي (CBM Engine)", "CBM Calculator", "modules/cbm_calculator/service.py", "توحيد وحدات القياس (مم، سم، م، كجم، رطل) واحتساب الوزن الحجمي الجوي (معامل 167) واختيار الوزن الأكبر للأجر."),
        ("محرك دورة حياة الشحنة (Lifecycle Board Engine)", "Lifecycle State Machine", "modules/lifecycle_board/service.py", "إدارة الانتقال التلقائي والمشروط بين 23 خطوة تشغيلية وتوثيق كل حركة ومنع التخطي إلا بمبرر معتمد."),
    ]
    for row_idx, r in enumerate(stack_rows, start=10):
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(r, start=1):
            c = ws1.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 2, 3]:
                c.alignment = align_center
                c.font = font_data_bold
            else:
                c.alignment = align_right

    # Functional Domains Breakdown Table
    start_r = 19
    ws1.cell(row=start_r, column=1, value="2. خريطة النطاقات الوظيفية الكبرى بالمنظومة (Functional Domains)").font = font_sec_header
    
    domain_headers = ["النطاق الوظيفي (Domain)", "عدد الجداول", "أبرز الجداول والكيانات", "المسؤولية الإدارية والتشغيلية"]
    for col_idx, h in enumerate(domain_headers, start=1):
        c = ws1.cell(row=start_r + 1, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    domain_rows = [
        ("إدارة الشحنات والملفات الاستيرادية (Core Hub)", "5 جداول", "import_files, import_companies, suppliers, projects, po_shipment_allocations", "الملف المحوري الحاكم لكافة العمليات وحلقة الوصل مع الموردين والشركات."),
        ("المشتريات وأوامر الشراء وقوائم التعبئة", "5 جداول", "purchase_orders, po_line_items, packing_list_items, package_types, units_of_measure", "إدارة عقود الشراء الدولية، جداول الكميات والأسعار، وتفاصيل أبعاد وأوزان الطرود."),
        ("الشحن الدولي واللوجستيات والمفاضلة", "10 جداول", "shipment_bookings, freight_rfq_requests, freight_quotation_items, shipping_scenarios...", "مفاضلة عروض النولون، حجوزات الخطوط الملاحية، تتبع الشحنات، والنقل البري الداخلي."),
        ("الحاويات والتعبئة ثلاثية الأبعاد و CBM", "4 جداول", "cbm_calculations, cbm_calculation_items, container_specs, container_loader_sessions", "الحسابات المادية للأحجام ومحاكاة التوزيع الأمثل للبضائع داخل الحاويات (3D Bin Packing)."),
        ("التأمين البحري على البضائع", "جدول واحد", "cargo_insurance_certificates", "إصدار وتوثيق شهادات التأمين البحري وتغطية المخاطر البحرية وحساب الأقساط."),
        ("التعريفة والاستشارات الجمركية والاتفاقيات", "8 جداول", "customs_tariffs, fee_codes, preferential_agreements, customs_consultation_sessions...", "إدارة بنود HS Code، الاتفاقيات التفضيلية، عروض أسعار المخلصين، وفحص الاشتراطات."),
        ("التوثيق الرقمي والـ ACID ومنظومة CargoX", "6 جداول", "acid_registration_sessions, cargox_envelopes, cargox_documents, original_documents...", "إدارة منظومة التسجيل المسبق (ACI)، صلاحية الـ ACID، وتتبع أظرف CargoX وسلاسل الكتل."),
        ("التدقيق والمطابقة المستندية المتقاطعة", "9 جداول", "po_packing_reconciliation, draft_bl_review, invoice_bl_match, certificate_of_origin...", "المطابقة الذكية بين الفواتير وقوائم التعبئة وبوالص الشحن وشهادات المنشأ وإجازة المستندات."),
        ("التخليص الجمركي وعمليات الموانئ والغرامات", "7 جداول", "customs_clearance_records, clearance_expense_invoices, demurrage_trackings, policies...", "قيد ومطابقة إقرار 46 ك.م، الكشف والتثمين، وتتبع فترات السماح وغرامات الأرضيات بالميناء."),
        ("الاعتمادات البنكية وسداد الموردين ونموذج 4", "8 جداول", "banking_document_sessions, import_budget_approvals, payment_requests, swift_extraction...", "إجراءات نموذج 4 البنكي، اعتمادات الموازنة، سداد الموردين، وتحليل رسائل السويفت بـ AI."),
        ("الاستلام المخزني وإذن الإضافة (GRN)", "جدول واحد", "warehouse_receiving_records", "محاضر الفحص والاستلام الفعلي بالمستودع وإثبات العجز والتالف والتسكين على الأرفف."),
        ("التسوية المالية الختامية وتكلفة الوصول", "2 جدول", "financial_settlement_records, tax_rates", "احتساب تكلفة الوحدة الشاملة (Landed Cost)، تسوية الفروق المالية، وإقفال العهد."),
        ("الإغلاق النهائي والأرشفة القانونية", "جدول واحد", "file_closure_records", "الاعتماد النهائي لإغلاق الملف بعد استيفاء كافة المستندات والتسويات المالية والمخزنية."),
        ("البيانات المرجعية والأساسية (Master Data)", "11 جدول", "countries, cities, transport_locations, currencies, exchange_rates, incoterms...", "الموانئ، العملات، أسعار الصرف، شروط التجارة الدولية، وكتالوج المصروفات المعياري."),
        ("محرك دورة الحياة وسير العمل والمهام الذكية", "10 جداول", "shipment_stage_activity, step_configs, smart_tasks, smart_checklists, recalculation...", "إدارة الـ 23 خطوة، توليد المهام الذكية، وتتبع اعتماديات إعادة الحساب الآلي."),
        ("قاعدة المعرفة والذكاء المكتسب والتكاملات", "7 جداول", "guide_entries, autonomous_pattern_audit_logs, inbound_email_logs, email_settings...", "دليل الخبرة التشغيلي لحلول المعوقات الجمركية السابقة وقراءة البريد الإلكتروني الذكي."),
        ("الأمان والحوكمة وسجلات التدقيق الرقابي", "10 جداول", "users, roles, permissions, role_permissions, audit_logs, concurrency_conflict_logs...", "إدارة الصلاحيات (RBAC)، سجل الرقابة الجنائي لجميع العمليات، وحماية التزامن."),
    ]
    for row_idx, r in enumerate(domain_rows, start=start_r + 2):
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(r, start=1):
            c = ws1.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 2]:
                c.alignment = align_center
                c.font = font_data_bold
            else:
                c.alignment = align_right

    # ════════════════════════════════════════════════════════════════
    # SHEET 2: مراحل دورة الحياة (23 خطوة تشغيلية)
    # ════════════════════════════════════════════════════════════════
    print("Building Sheet 2: مراحل دورة الحياة (23 خطوة)...")
    ws2 = wb.create_sheet(title="مراحل دورة الحياة (23 خطوة)")
    ws2.views.sheetView[0].rightToLeft = True

    # Title Banner
    ws2.merge_cells("A1:K2")
    t2 = ws2.cell(row=1, column=1, value="دورة حياة ملف الاستيراد الشاملة (Import File Lifecycle) — الـ 6 مراحل والـ 23 خطوة تشغيلية")
    t2.font = font_main_title
    t2.fill = navy_fill
    t2.alignment = align_center

    step_headers = [
        "المرحلة (Phase)",
        "كود الخطوة (Step Code)",
        "اسم الخطوة بالعربي",
        "اسم الخطوة بالإنجليزي",
        "الهدف والوظيفة التشغيلية",
        "المدخلات والمستندات المشروطة للبدء",
        "المخرجات والقرارات الناتجة",
        "شروط التحقق وقواعد الاكتمال",
        "الجداول المرتبطة مباشرة بقاعدة البيانات",
        "الموديول البرمجي والشاشة",
        "الأتمتة والتنبيهات الذكية"
    ]
    for col_idx, h in enumerate(step_headers, start=1):
        c = ws2.cell(row=4, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    # Detailed data for all 23 steps
    detailed_steps = [
        # Phase 1
        ("المرحلة 1: التخطيط والدراسات المسبقة", "STEP_01", "دراسات ومفاضلة نولون الشحن", "Freight Studies",
         "طلب ومفاضلة عروض أسعار الشحن البحري والجوي والبري، تقييم زمن العبور وفترات السماح المجانية واختيار السيناريو الأفضل.",
         "بيانات البضاعة المبدئية، ميناء الشحن وميناء الوصول المستهدف، الأوزان التقديرية أو الحجم CBM.",
         "عروض أسعار معتمدة، جدول مقارنة السيناريوهات، وترسية الحجز المبدئي.",
         "وجود عرض شحن واحد معتمد على الأقل وتحديد شركة الشحن أو الوكيل الملاحي.",
         "freight_rfq_requests, freight_quotation_items, shipping_evaluation_sessions, shipping_scenario_items",
         "freight_quotations / shipping_scenarios", "تنبيه بانتهاء صلاحية عروض الأسعار وحساب تلقائي للتكلفة الإجمالية."),
        
        ("المرحلة 1: التخطيط والدراسات المسبقة", "STEP_02", "الدراسات والاستشارات الجمركية", "Customs Studies",
         "تحديد وتدقيق كود البند الجمركي (HS Code)، معرفة الرسوم والضرائب، واستشارة المخلصين الجمركيين لتفادي النزاعات.",
         "فاتورة مبدئية أولية (Proforma Invoice)، مواصفات البضاعة والكتالوجات الفنية، شهادة المنشأ التقديرية.",
         "رأي جمركي معتمد، تحديد نسبة الوارد وضريبة الجدول والقيمة المضافة، وقائمة أسعار المخلص المعتمد.",
         "التحقق من وجود كود بند جمركي صالح ومسجل بجدول التعريفة الجمركية وتأكيد اشتراطاته.",
         "customs_tariffs, customs_consultation_sessions, customs_checklist_items, customs_clearance_rfqs",
         "customs_consultation / customs_tariff", "حساب تلقائي لنسب الرسوم الجمركية وفحص الاتفاقيات التجارية التفضيلية المتاحة."),

        ("المرحلة 1: التخطيط والدراسات المسبقة", "STEP_03", "متطلبات واشتراطات الاستيراد للشحنة", "Import Regulatory Requirements",
         "حصر وفحص كافة اشتراطات جهات العرض الرقابية (سلامة الغذاء NFSA، الرقابة على الصادرات GOEIC، الاتصالات NTRA...).",
         "HS Code، توصيف المنتج الدقيق، بيانات المصنع والمورد، والمواصفات الفنية القياسية.",
         "تقرير متطلبات الاستيراد، قائمة التراخيص والموافقات المسبقة الواجب استخراجها قبل الشحن.",
         "تأكيد استيفاء كافة الموافقات المسبقة وتحديد المستندات الإلزامية المطلوب تضمينها مع الشحنة.",
         "import_requirement_assessments, customs_checklist_items, guide_entries",
         "import_requirements", "التحقق الآلي من سجل الهيئة العامة للرقابة على الصادرات والمصانع المسجلة بالقرار 43."),

        # Phase 2
        ("المرحلة 2: بداية الشحنة والاعتمادات", "STEP_04", "اعتمادات الميزانية وسداد الموردين", "Finance Approvals & Budget",
         "اعتماد الموازنة المالية التقديرية للشحنة، سداد الدفعة المقدمة للمورد، وإصدار وثيقة التأمين البحري.",
         "أمر الشراء المعتمد (PO)، الفاتورة المبدئية، كشف حساب التكلفة التقديرية.",
         "طلب سداد معتمد، إيصال تحويل السويفت البنكي، ووثيقة تأمين بحري سارية المفعول.",
         "تسجيل سويفت التحويل البنكي المعتمد وتوفر وثيقة تأمين تغطي قيمة الشحنة بما لا يقل عن 110% من قيمتها.",
         "import_budget_approvals, payment_request_sessions, cargo_insurance_certificates, swift_extraction_batches",
         "financial_approval / cargo_insurance", "استخراج حقول السويفت آلياً بالذكاء الاصطناعي والربط التلقائي بمركز تكلفة المشروع."),

        ("المرحلة 2: بداية الشحنة والاعتمادات", "STEP_05", "الرقم التعريفي المبدئي للشحنة ACID", "ACID Operations",
         "تقديم طلب التسجيل المسبق للشحنات على منظومة نافذة وإصدار الرقم التعريفي المبدئي للشحنة (ACID) وإبلاغه للمورد.",
         "بيانات المصدر المسجل بـ CargoX، بيانات المستورد، الفاتورة المبدئية المعتمدة، بنود HS Codes.",
         "رقم ACID معتمد المكون من 19 رقماً وتاريخ إصداره وتاريخ انتهاء صلاحيته (3 أشهر / 90 يوماً).",
         "صحة كود ACID وخلوه من أخطاء الإدخال والتحقق من عدم انتهاء صلاحيته.",
         "acid_registration_sessions, import_files",
         "import_documentation (ACID)", "إطلاق تنبيهات ذكية تبدأ قبل 14 يوماً من انتهاء الصلاحية وحظر الإفراج التلقائي عند الانتهاء."),

        # Phase 3
        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_06", "حجز النولون وتأكيد الخط الملاحي", "Freight Booking",
         "تثبيت الحجز مع الخط الملاحي أو وكيل الشحن بناءً على رقم ACID وصدور إخطار الحجز الرسمي (Booking Confirmation).",
         "رقم الحجز المبدئي، رقم ACID المعتمد، تواريخ جاهزية البضاعة لدى المصنع المصدر.",
         "تأكيد الحجز النهائي (Booking Confirmation)، تحديد سفينة الشحن، مواعيد الإبحار ETD والوصول ETA.",
         "تسجيل رقم الحجز واسم السفينة ورقم الرحلة وتحديد موقع الشحن وموقع التفريغ بدقة.",
         "shipment_bookings, freight_rfq_requests, external_service_providers",
         "freight_booking", "تحديث مواعيد الوصول التقديرية تلقائياً وإخطار فريق التخليص الجمركي بالميناء."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_07", "تخصيص وتوزيع الحاويات والبضائع", "Freight Allocations",
         "توزيع بنود أمر الشراء والطرود على الحاويات المحجوزة والتأكد من مطابقة السعات الحجمية والأوزان القصوى.",
         "قائمة التعبئة المبدئية (Packing List)، مواصفات الحاويات المحجوزة، بيانات الطرود.",
         "خطة التحميل وتوزيع الحاويات (Container Manifest)، أرقام الحاويات، وبيانات السيل الملاحي (Seals).",
         "عدم تجاوز الحمولة القصوى للحاوية ومطابقة الحجم الكلي مع أرقام البوليصة.",
         "container_loader_sessions, po_shipment_allocations, packing_list_items",
         "container_loader / purchase_orders", "محاكاة ثلاثية الأبعاد لتوزيع الطرود داخل الحاوية واكتشاف أي زيادة في الوزن القائم."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_08_PO", "مطابقة الفاتورة والتعبئة مع أمر الشراء", "PO & Packing Reconciliation",
         "التدقيق والمطابقة الدقيقة بين الفاتورة التجارية وقائمة التعبئة الواردتين من المورد وأمر الشراء المعتمد.",
         "الفاتورة التجارية، قائمة التعبئة التفصيلية، وأمر الشراء المعتمد (PO).",
         "تقرير مطابقة البنود (Reconciliation Report)، حصر أي فروق في الكميات أو الأسعار أو الأوزان.",
         "تطابق كميات وأسعار الفاتورة بنسبة 100% مع أمر الشراء أو توثيق الفروق المصرح بها مسبقاً.",
         "po_packing_reconciliation_sessions, po_line_items, packing_list_items",
         "import_documentation", "مطابقة آلية لرمز الصنف وسعر الوحدة والكميات وإظهار نسبة الانحراف المالي فوراً."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_08_BL", "مراجعة واعتماد مسودة بوليصة الشحن", "Draft B/L Review & Approval",
         "المراجعة الفنية والقانونية لمسودة بوليصة الشحن الواردة من الخط الملاحي قبل إصدار البوليصة النهائية.",
         "مسودة بوليصة الشحن (Draft B/L)، أمر الحجز، وبيانات المستورد والشاحن.",
         "ملاحظات التعديل على المسودة أو اعتمادها النهائي، والتأكد من ذكر رقم ACID والبنك بدقة.",
         "صحة اسم المشحون له (Consignee) والإخطار (Notify) ورقم ACID وشروط الشحن والموانئ.",
         "draft_bl_review_sessions, shipment_bookings",
         "import_documentation (Draft BL)", "فحص آلي لوجود النص الإلزامي للرقم التعريفي ACID واسم المستورد الضريبي على البوليصة."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_08_MATCH", "المطابقة الذكية بين الفاتورة والبوليصة", "Smart Invoice vs B/L Match",
         "المطابقة المتقاطعة الآلية بين الفاتورة التجارية ومسودة البوليصة لمنع أي تعارض يعطل الإفراج الجمركي.",
         "الفاتورة التجارية المعتمدة، مسودة بوليصة الشحن المعتمدة.",
         "سجل المطابقة الذكية وخلو المستندات من التناقض في عدد الطرود، الأوزان الإجمالية، وشروط التسليم.",
         "تطابق الوزن القائم وعدد الطرود ووصف البضاعة العام بين الفاتورة والبوليصة بدون أي تضارب.",
         "invoice_bl_match_sessions, shipment_document_items",
         "import_documentation", "اكتشاف الفروق الحسابية في الأوزان والأرقام آلياً وتوليد تقرير بالأخطاء لتصويبها فوراً."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_08_COO", "مسودة شهادة المنشأ و EUR.1", "Draft COO & EUR.1 Review",
         "تدقيق مسودات شهادات المنشأ (Certificate of Origin) وشهادات الحركة التفضيلية (EUR.1) للتحقق من الإعفاء الجمركي.",
         "مسودة شهادة المنشأ، الفاتورة التجارية، الاتفاقية التفضيلية المطبقة.",
         "اعتماد صيغة شهادة المنشأ، التحقق من الصياغة القانونية لإعلان المصدر ومطابقة المنشأ الفعلي.",
         "استيفاء أختام الغرفة التجارية المختصة وصحة إعلان المنشأ ومطابقة أرقام الفاتورة.",
         "certificate_of_origin_review_sessions, preferential_agreements",
         "import_documentation (COO)", "تحديد نسبة الخصم الجمركي المستحقة وفق الاتفاقية التجارية التفضيلية المسجلة."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_08_COC", "شهادات الفحص والتفتيش والمطابقة", "Draft Inspection Review",
         "مراجعة شهادات الفحص قبل الشحن الصادرة من شركات التفتيش الدولية المعتمدة من الجهات الرقابية المصرية.",
         "شهادة الفحص والمطابقة (COC)، نتائج التحاليل المخبرية، بيانات جهة التفتيش.",
         "اعتماد شهادة المطابقة وربطها برقم الشحنة وتجهيزها للعرض على الرقابة على الصادرات أو سلامة الغذاء.",
         "صدور الشهادة من شركة تفتيش معتمدة ومطابقة أرقام اللوطات (Batch Numbers) وتواريخ الصلاحية.",
         "inspection_certificate_review_sessions, import_requirement_assessments",
         "import_documentation (COC)", "التحقق من اعتماد شركة التفتيش لدى الهيئة العامة للرقابة على الصادرات والواردات GOEIC."),

        ("المرحلة 3: حجز الشحن والتدقيق المستندي المبدئي", "STEP_09", "الاعتماد النهائي للمستندات الجمركية", "Docs Customs Approval",
         "المراجعة الختامية لجميع المستندات المصوبة وإصدار موافقة الشحن الرسمية للمورد وإغلاق أي تذاكر تعديل.",
         "كافة المستندات المعتمدة في الخطوات 08_PO, 08_BL, 08_COO, 08_COC.",
         "إذن الشحن النهائي الرسمي، إغلاق تذاكر التعديلات، وجاهزية المورد لرفع المستندات على منصة CargoX.",
         "اعتماد مسؤول الجمارك وإغلاق كافة تذاكر التعديل (Discrepancy Tickets) المفتوحة بنسبة 100%.",
         "docs_customs_approval_sessions, customs_document_approvals, discrepancy_rectification_tickets",
         "docs_customs_approval", "إرسال إخطار آلي للمورد بإمكانية إبحار الشحنة ورفع المستندات النهائية المشفرة على CargoX."),

        # Phase 4
        ("المرحلة 4: التوثيق الرقمي والاعتماد البنكي", "STEP_10", "رفع ومتابعة مستندات CargoX", "CargoX Follow-up / Upload",
         "متابعة قيام المورد برفع أظرف المستندات المشفرة عبر شبكة سلاسل الكتل على منصة CargoX وربطها بالـ ACID.",
         "رقم ظرف CargoX (Envelope ID)، بصمة الملفات الرقمية، رقم ACID للشحنة.",
         "توثيق استلام الظرف المكتمل على المنصة وتحويله لحالة Ready for Customs Clearance.",
         "اكتمال رفع البوليصة والفاتورة والمنشأ ونجاح التحقق من التوقيع الرقمي للبصمة المشفرة.",
         "cargox_envelopes, cargox_envelope_documents, cargox_standard_invoice_sessions",
         "cargox", "المزامنة المباشرة وتحديث حالة الظرف اللحظية وربطه بملف الاستيراد وإخطار فريق التخليص."),

        ("المرحلة 4: التوثيق الرقمي والاعتماد البنكي", "STEP_11", "تحصيل واستلام أصول المستندات", "Originals Collection",
         "متابعة وصول واستلام أصول المستندات الورقية عبر البريد السريع الدولي (DHL/FedEx) أو تسليمات البنك.",
         "رقم البوليصة السريعة (Courier Waybill No)، إشعار وصول البريد، أو إشعار استلام البنك.",
         "محضر استلام أصول المستندات، جرد الأصول (الفاتورة الأصلية، بوليصة الشحن الأصلية 3/3، شهادة المنشأ).",
         "تأكيد استلام أصول المستندات أو تحويل بوليصة الشحن الأصلية إلى Telex Release معتمد.",
         "original_documents_collection_sessions, formal_letters_history",
         "original_documents_collection", "تتبع خط سير طرد البريد السريع عبر واجهة الربط الآلي وتنبيه فريق العمل فور التسليم."),

        ("المرحلة 4: التوثيق الرقمي والاعتماد البنكي", "STEP_12", "استخراج واعتماد نموذج 4 البنكي", "Bank Form 4",
         "استخراج نموذج 4 البنكي وإرساله إلكترونياً من البنك التجاري إلى مصلحة الجمارك عبر منظومة نافذة.",
         "أصول المستندات أو نسخها المعتمدة بنكياً، طلب استخراج نموذج 4، سداد المصاريف الإدارية للبنك.",
         "رقم وتاريخ نموذج 4 البنكي المعتمد والمثبت على نافذة، وإبراء ذمة البنك لتحويل العملة.",
         "ظهور حالة نموذج 4 معتمد إلكترونياً على نافذة وربطه برقم الإقرار الجمركي للشحنة.",
         "banking_document_sessions, payment_request_sessions",
         "import_documentation (Banking)", "الربط الآلي والتنبيه فور اعتماد نموذج 4 بالجمارك للسماح بطباعة إذن الإفراج النهائي."),

        # Phase 5
        ("المرحلة 5: عمليات الميناء والتخليص الجمركي", "STEP_13", "قيد ومطابقة إقرار 46 ك.م", "Customs Declaration 46",
         "قيد البيان الجمركي الرسمي للشحنة (إقرار 46 ك.م) بالدائرة الجمركية وتحديد مسار الإفراج (أخضر/أصفر/أحمر).",
         "بيانات المانيفست الملاحي، إذن التسليم، مستندات CargoX، نموذج 4 البنكي.",
         "رقم 46 ك.م المؤرخ رسمياً، تحديد لجان الكشف، وتعيين مسار الإفراج الجمركي للشحنة.",
         "تسجيل رقم وتاريخ إقرار 46 ك.م واسم مأمور التعريفة ومثمن الجمارك المسؤول.",
         "customs_clearance_records, customs_declaration_drafts",
         "customs_clearance", "المطابقة التلقائية بين أرقام الحاويات والطرود في الإقرار والمانيفست الملاحي لمنع التضارب."),

        ("المرحلة 5: عمليات الميناء والتخليص الجمركي", "STEP_14", "متابعة الكشف والتثمين", "Clearance Follow-up",
         "متابعة أعمال الفتح والمعاينة الفعلية، الكشف والتثمين بالدائرة الجمركية وتوثيق ملاحظات مأمور الحركة.",
         "إذن فتح الحاوية، محضر الكشف المبدئي، حضور المخلص الجمركي المعتمد.",
         "محضر المعاينة الجمركية المبدئي، إثبات مطابقة المواصفات، وتقرير مثمن التعريفة.",
         "اكتمال أعمال الفحص الفعلي وتسجيل أي ملاحظات تتعلق بالمنشأ أو الأوصاف الفنية للبضاعة.",
         "customs_clearance_records, shipment_update_logs",
         "customs_clearance", "تحديث فوري للحالة التشغيلية وإخطار مسؤولي اللوجستيات بنتائج لجان الكشف والمعاينة."),

        ("المرحلة 5: عمليات الميناء والتخليص الجمركي", "STEP_15", "سحب العينات / محاضر العجز", "Drawing Samples / Shortage",
         "توثيق سحب العينات لجهات العرض الرقابي (المعامل المركزية)، وإثبات أي محاضر عجز رسمي في المحتويات.",
         "أذون سحب العينات الرسمية، إيصالات تسليم المعامل، محاضر الشرطة الجمركية إن وجد عجز.",
         "إيصال تسليم العينات للمعامل المركزية، نتائج التحاليل الرسمية، أو محضر إثبات العجز الجمركي.",
         "تسجيل بيانات سحب العينة وأرقام أختام العينات ومتابعة تاريخ صدور نتائج التحاليل المعملية.",
         "customs_clearance_records, clearance_expense_invoices",
         "customs_clearance", "تتبع زمني للمدد القانونية المتاحة لظهور نتائج الفحص المعملي وتفادي غرامات التأخير."),

        ("المرحلة 5: عمليات الميناء والتخليص الجمركي", "STEP_16", "محاضر المعاينة والأضرار", "Cargo Discrepancy / Damage",
         "توثيق أي أضرار أو كسر أو بلل بالبضاعة وتوثيق محاضر المعاينة المشتركة مع الخط الملاحي والتأمين.",
         "محضر معاينة فتح الحاوية، صور الأضرار، إخطار التوكيل الملاحي وخبير المعاينة التأميني.",
         "تقرير المعاينة المشترك، حصر قيمة التلفيات، وإخطار شركة التأمين البحري بالمطالبة الرسمية.",
         "اكتمال توقيعات محضر المعاينة المشترك من مندوب التوكيل والميناء وخبير التأمين الجمركي.",
         "customs_clearance_records, cargo_insurance_certificates",
         "customs_clearance / cargo_insurance", "إعداد ملف المطالبة التأمينية الشامل تلقائياً وتجميد الصرف للبند المتضرر لحين التسوية."),

        ("المرحلة 5: عمليات الميناء والتخليص الجمركي", "STEP_17", "الحساب والسداد الجمركي النهائي", "Final Customs Calculation",
         "المراجعة الحسابية النهائية للرسوم والضرائب، سداد القسيمة الجمركية، وصدور إذن الإفراج النهائي الرسمي.",
         "قسيمة سداد الرسوم الجمركية، الفاتورة الضريبية، إيصالات رسوم الموانئ وجهات العرض.",
         "إذن الإفراج الجمركي الأخضر المعتمد، إيصالات السداد الحكومية، وقسيمة سداد الضرائب والرسوم.",
         "تطابق المبالغ المسددة مع نواتج محرك الحساب الجمركي المصري وسداد كامل القسيمة الجمركية.",
         "customs_clearance_records, clearance_expense_invoices, recalculation_logs",
         "customs_clearance", "إعادة التحقق الحسابي الشامل من عدم وجود أي خطأ في تقدير وعاء القيمة المضافة أو بنود الرسوم."),

        ("المرحلة 5: عمليات الميناء والتخليص الجمركي", "STEP_18", "إدارة الغرامات وفترات السماح", "Demurrage & Detention",
         "مراقبة فترات السماح المجانية للحاويات، حساب غرامات التأخير والأرضيات اليومية، واسترداد التأمين.",
         "تاريخ تفريغ الحاوية (Discharge Date)، بوليصة الشحن، سياسة فترات السماح المعتمدة.",
         "حصر مبالغ غرامات التأخير والأرضيات إن وجدت، واسترداد شيكات تأمين الحاويات من الخطوط الملاحية.",
         "تسجيل تاريخ عودة الحاويات الفارغة للميناء (Empty Return Date) واسترداد إيصال التبادل (EIR).",
         "demurrage_trackings, demurrage_policies, demurrage_rules, port_demurrage_tariff",
         "demurrage_detention", "حساب تراكمي يومي لغرامات التأخير وإرسال تنبيهات حمراء قبل 48 ساعة من دخول شرائح الغرامة المرتفعة."),

        # Phase 6
        ("المرحلة 6: الاستلام المخزني والتسوية المالية", "STEP_19", "إذن الإضافة والاستلام المخزني", "Warehouse Receiving GRN",
         "نقل البضاعة للمستودعات، الفحص والاستلام الفعلي، وتحرير إذن الإضافة المخزني الرسمي (Goods Receipt Note).",
         "إذن الإفراج الجمركي، بوالص النقل البري الداخلي، قائمة التعبئة، محضر فحص الجودة المخزني.",
         "إذن الإضافة المخزني (GRN) المعتمد، تسجيل البضائع ببرنامج المستودعات، وتسكينها على الأرفف.",
         "تأكيد استلام الكميات السليمة وتوثيق أي فروق أو عجز وتوقيع أمين المستودع ومسؤول الجودة.",
         "warehouse_receiving_records, inland_transport_bookings",
         "warehouse_receiving", "تحديث الأرصدة المخزنية تلقائياً وإخطار إدارة المشتريات باكتمال الاستلام الفعلي للبضاعة."),

        ("المرحلة 6: الاستلام المخزني والتسوية المالية", "STEP_20", "تسوية التكلفة الاستيرادية الشاملة", "Landed Cost Settlement",
         "تجميع كافة المصروفات الفعلية واحتساب التكلفة النهائية للوحدة الواحدة (Final Landed Cost per Unit).",
         "فواتير الشراء، النولون، التأمين، القسيمة الجمركية، فواتير التخليص، النقل البري، والمصروفات النثرية.",
         "شيت التكلفة الاستيرادية الشاملة النهائي، تكلفة كل صنف على حدة، وتوزيع المصروفات المشتركة.",
         "اكتمال وترحيل كافة فواتير المصروفات وإبراء الذمم المالية للمخلصين وشركات النقل.",
         "financial_settlement_records, budget_variance_logs, expense_catalog",
         "financial_settlement", "محرك احتساب تكلفة الوصول وتوزيع المصروفات المشتركة آلياً بالقيمة والوزن والحجم وإعداد قيد اليومية."),

        ("المرحلة 6: الاستلام المخزني والتسوية المالية", "STEP_21", "الإغلاق النهائي للملف الاستيرادي", "Import File Final Closure",
         "المراجعة الختامية للحوكمة وإغلاق الملف الاستيرادي إلكترونياً ومنع التعديل عليه وأرشفة كافة وثائقه.",
         "إذن الإضافة المخزني، شيت التسوية المالية، إيصالات استرداد التأمينات، ومحضر الجرد النهائي.",
         "محضر الإغلاق النهائي المعتمد للملف وتحويل حالة الملف رسمياً إلى Closed / Archived.",
         "تحقق كافة شروط الإغلاق الـ 20 السابقة وعدم وجود أي مستندات أو مبالغ مالية معلقة.",
         "file_closure_records, import_files, shipment_stage_activity",
         "file_closure", "قفل سجلات الملف الاستيرادي نهائياً وجعلها للقراءة فقط (Read-Only) مع حفظ الأرشيف الرقمي الموثق."),
    ]

    for row_idx, r in enumerate(detailed_steps, start=5):
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(r, start=1):
            c = ws2.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 2, 3, 4]:
                c.alignment = align_center
                c.font = font_data_bold
            elif col_idx in [9, 10]:
                c.alignment = align_left
                c.font = font_code
            else:
                c.alignment = align_right

    # ════════════════════════════════════════════════════════════════
    # SHEET 3: فهرس كل الجداول (110 جدول)
    # ════════════════════════════════════════════════════════════════
    print("Building Sheet 3: فهرس كل الجداول (110 جدول)...")
    ws3 = wb.create_sheet(title="فهرس كل الجداول (110 جدول)")
    ws3.views.sheetView[0].rightToLeft = True

    # Title Banner
    ws3.merge_cells("A1:K2")
    t3 = ws3.cell(row=1, column=1, value="دليل وفهرس جداول قاعدة البيانات الشاملة (Database Tables Catalog) — 110 جدول")
    t3.font = font_main_title
    t3.fill = navy_fill
    t3.alignment = align_center

    tbl_headers = [
        "م",
        "اسم الجدول في قاعدة البيانات",
        "اسم الجدول بالعربي",
        "النطاق الوظيفي (Domain)",
        "الموديول البرمجي (Module)",
        "مرحلة دورة الحياة المرتبطة",
        "تصنيف الجدول (Classification)",
        "المفتاح الأساسي (PK)",
        "عدد الأعمدة",
        "عدد المفاتيح الأجنبية",
        "الجداول المرتبطة خارجياً (FK Targets)",
        "الوصف الوظيفي والدور في المنظومة"
    ]
    for col_idx, h in enumerate(tbl_headers, start=1):
        c = ws3.cell(row=4, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    sorted_tables = sorted(Base.metadata.tables.items(), key=lambda x: x[0])
    for idx, (t_name, table) in enumerate(sorted_tables, start=1):
        meta = TABLE_METADATA.get(t_name, {
            "arabic_name": t_name.replace("_", " ").title(),
            "domain": "عام / تشغيلي",
            "module": "system",
            "phase": "عام",
            "classification": "تشغيلي",
            "description": f"جدول {t_name} في قاعدة البيانات"
        })
        
        pk_cols = [c.name for c in table.columns if c.primary_key]
        pk_str = ", ".join(pk_cols) if pk_cols else "None"
        
        fk_targets = sorted(list(set([fk.target_fullname.split(".")[0] for fk in table.foreign_keys])))
        fk_targets_str = ", ".join(fk_targets) if fk_targets else "—"

        row_data = [
            idx,
            t_name,
            meta.get("arabic_name", ""),
            meta.get("domain", ""),
            meta.get("module", ""),
            meta.get("phase", ""),
            meta.get("classification", ""),
            pk_str,
            len(table.columns),
            len(table.foreign_keys),
            fk_targets_str,
            meta.get("description", "")
        ]

        row_idx = idx + 4
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(row_data, start=1):
            c = ws3.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 8, 9, 10]:
                c.alignment = align_center
                if col_idx in [1, 9, 10]:
                    c.font = font_data_bold
            elif col_idx in [2, 11]:
                c.alignment = align_left
                c.font = font_code
            else:
                c.alignment = align_right

    # ════════════════════════════════════════════════════════════════
    # SHEET 4: قاموس البيانات والأعمدة (2,358 حقل)
    # ════════════════════════════════════════════════════════════════
    print("Building Sheet 4: قاموس البيانات والأعمدة (2,358 حقل)...")
    ws4 = wb.create_sheet(title="قاموس البيانات والأعمدة (2358)")
    ws4.views.sheetView[0].rightToLeft = True

    # Title Banner
    ws4.merge_cells("A1:J2")
    t4 = ws4.cell(row=1, column=1, value="قاموس البيانات التفصيلي لكافة الحقول والأعمدة (Data Dictionary) — 2,358 حقلاً")
    t4.font = font_main_title
    t4.fill = navy_fill
    t4.alignment = align_center

    dict_headers = [
        "اسم الجدول البرمجي",
        "اسم الجدول بالعربي",
        "اسم الحقل / العمود",
        "نوع البيانات (Data Type)",
        "مفتاح أساسي (PK)",
        "مفتاح أجنبي (FK)",
        "يشير إلى جدول وحقل (FK Reference)",
        "يقبل فارغ؟ (Nullable)",
        "القيمة الافتراضية",
        "الشرح والوصف الوظيفي للحقل بالعربي"
    ]
    for col_idx, h in enumerate(dict_headers, start=1):
        c = ws4.cell(row=4, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    current_dict_row = 5
    for t_name, table in sorted_tables:
        t_meta = TABLE_METADATA.get(t_name, {})
        t_ar = t_meta.get("arabic_name", t_name)

        for col in table.columns:
            is_pk = col.primary_key
            is_fk = bool(col.foreign_keys)
            fk_target = ", ".join([fk.target_fullname for fk in col.foreign_keys]) if is_fk else ""
            default_val = str(col.default.arg) if col.default is not None and hasattr(col.default, 'arg') else ("—" if col.server_default is None else "Server Default")
            
            ar_desc = infer_column_arabic_description(t_name, col.name, str(col.type), is_pk, fk_target)

            col_row = [
                t_name,
                t_ar,
                col.name,
                str(col.type),
                "نعم (PK)" if is_pk else "لا",
                "نعم (FK)" if is_fk else "لا",
                fk_target if fk_target else "—",
                "نعم" if col.nullable else "إلزامي (Not Null)",
                default_val,
                ar_desc
            ]

            fill = None
            if is_pk:
                fill = pk_fill
            elif is_fk:
                fill = fk_fill
            elif current_dict_row % 2 == 0:
                fill = zebra_fill

            for col_idx, val in enumerate(col_row, start=1):
                c = ws4.cell(row=current_dict_row, column=col_idx, value=val)
                c.font = font_data_regular
                c.border = cell_border
                if fill:
                    c.fill = fill
                if col_idx in [4, 5, 6, 8, 9]:
                    c.alignment = align_center
                    if col_idx in [5, 6, 8]:
                        c.font = font_data_bold
                elif col_idx in [1, 3, 7]:
                    c.alignment = align_left
                    c.font = font_code
                else:
                    c.alignment = align_right

            current_dict_row += 1

    # ════════════════════════════════════════════════════════════════
    # SHEET 5: شبكة العلاقات والترابط (154 علاقة)
    # ════════════════════════════════════════════════════════════════
    print("Building Sheet 5: شبكة العلاقات والترابط (154 علاقة)...")
    ws5 = wb.create_sheet(title="شبكة العلاقات والترابط (154)")
    ws5.views.sheetView[0].rightToLeft = True

    # Title Banner
    ws5.merge_cells("A1:J2")
    t5 = ws5.cell(row=1, column=1, value="مصفوفة العلاقات والترابط بين الجداول (Entity Relationships & Foreign Keys Network)")
    t5.font = font_main_title
    t5.fill = navy_fill
    t5.alignment = align_center

    rel_headers = [
        "م",
        "الجدول التابع (Child Table)",
        "اسم الجدول التابع بالعربي",
        "حقل المفتاح الأجنبي (FK Column)",
        "الجدول الأب المشار إليه (Parent Table)",
        "اسم الجدول الأب بالعربي",
        "حقل المفتاح الأساسي (Parent PK)",
        "نوع العلاقة (Cardinality)",
        "المسار الحيوي (Business Domain)",
        "الأثر التشغيلي ومعنى الرابط في دورة العمل"
    ]
    for col_idx, h in enumerate(rel_headers, start=1):
        c = ws5.cell(row=4, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    # Extract all FK relationships dynamically from Base.metadata
    all_fks = []
    for t_name, table in sorted_tables:
        for fk in table.foreign_keys:
            child_table = t_name
            child_col = fk.parent.name
            parent_table, parent_col = fk.target_fullname.split(".") if "." in fk.target_fullname else (fk.target_fullname, "id")
            all_fks.append((child_table, child_col, parent_table, parent_col))

    def get_relationship_meaning(child_t: str, child_c: str, parent_t: str) -> tuple[str, str, str]:
        # returns (cardinality, business_domain, business_meaning)
        if parent_t == "import_files":
            return ("متعدد إلى واحد (N:1)", "إدارة الشحنات المحورية",
                    "ربط العمليات الفرعية (شحن، تدقيق مستندي، جمارك، غرامات، سداد) بملف الشحنة الاستيرادية الأساسي.")
        if parent_t == "purchase_orders":
            return ("متعدد إلى واحد (N:1)", "المشتريات والعقود",
                    "ربط بنود الشراء وتفاصيل التعبئة وجلسات التدقيق بأمر الشراء المعتمد.")
        if parent_t == "suppliers":
            return ("متعدد إلى واحد (N:1)", "الموردين والتعاقدات",
                    "ربط العمليات (أمر شراء، طلب سداد، عروض) ببيانات المورد والمصنع الدولي المعتمد.")
        if parent_t == "import_companies":
            return ("متعدد إلى واحد (N:1)", "الشركات والكيانات القانونية",
                    "ربط الشحنة أو أمر الشراء بشركة الاستيراد التابعة للمجموعة المسجلة جمركياً.")
        if parent_t == "projects":
            return ("متعدد إلى واحد (N:1)", "المشاريع ومراكز التكلفة",
                    "تحميل تكاليف الشحنة وأوامر الشراء على مركز تكلفة المشروع الاستثماري المعني.")
        if parent_t == "external_service_providers":
            return ("متعدد إلى واحد (N:1)", "مزودي الخدمات اللوجستية",
                    "ربط الشحنة بشركة الشحن أو الخط الملاحي أو مكتب التخليص الجمركي المسؤول.")
        if parent_t == "transport_locations":
            return ("متعدد إلى واحد (N:1)", "اللوجستيات والموانئ",
                    "تحديد ميناء الشحن (POL) أو ميناء الوصول (POD) المعتمد للرحلة البحرية/الجوية.")
        if parent_t == "customs_tariffs":
            return ("متعدد إلى واحد (N:1)", "التعريفة والجمارك",
                    "ربط الصنف بالبند الجمركي الصحيح لاحتساب نسب الرسوم والضرائب التلقائية.")
        if parent_t == "roles":
            return ("متعدد إلى واحد (N:1)", "الأمان والمستخدمين",
                    "تحديد الدور الوظيفي للمستخدم لتطبيق مصفوفة الصلاحيات والحوكمة (RBAC).")
        if parent_t == "permissions":
            return ("متعدد إلى واحد (N:1)", "الأمان والصلاحيات",
                    "منح أو تقييد صلاحيات تشغيلية محددة على مستوى الأدوار أو المستخدمين.")
        if parent_t == "currencies":
            return ("متعدد إلى واحد (N:1)", "المالية وأسعار الصرف",
                    "تحديد العملة الأصلية للمعاملة وربطها بسعر الصرف اليومي والجماركي.")
        if parent_t == "incoterms":
            return ("متعدد إلى واحد (N:1)", "شروط التجارة الدولية",
                    "تطبيق قواعد ومسؤوليات التسليم المعتمدة (FOB, CIF, EXW) وتوزيع التكاليف.")
        
        return ("متعدد إلى واحد (N:1)", "عمليات النظام",
                f"ربط سجلات {child_t} مع المرجع الأساسي في {parent_t} لضمان تكامل البيانات.")

    for idx, (c_tbl, c_col, p_tbl, p_col) in enumerate(all_fks, start=1):
        c_meta = TABLE_METADATA.get(c_tbl, {})
        p_meta = TABLE_METADATA.get(p_tbl, {})

        c_ar = c_meta.get("arabic_name", c_tbl)
        p_ar = p_meta.get("arabic_name", p_tbl)

        cardinality, domain, meaning = get_relationship_meaning(c_tbl, c_col, p_tbl)

        row_data = [
            idx,
            c_tbl,
            c_ar,
            c_col,
            p_tbl,
            p_ar,
            p_col,
            cardinality,
            domain,
            meaning
        ]

        row_idx = idx + 4
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(row_data, start=1):
            c = ws5.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 8]:
                c.alignment = align_center
                c.font = font_data_bold
            elif col_idx in [2, 4, 5, 7]:
                c.alignment = align_left
                c.font = font_code
            else:
                c.alignment = align_right

    # ════════════════════════════════════════════════════════════════
    # SHEET 6: محركات الحساب وقواعد البزنس (Engines & Business Rules)
    # ════════════════════════════════════════════════════════════════
    print("Building Sheet 6: محركات الحساب وقواعد البزنس...")
    ws6 = wb.create_sheet(title="محركات الحساب وقواعد العمل")
    ws6.views.sheetView[0].rightToLeft = True

    # Title Banner
    ws6.merge_cells("A1:G2")
    t6 = ws6.cell(row=1, column=1, value="محركات الحسابات وقواعد البزنس الصارمة (Domain Engines & Business Rules)")
    t6.font = font_main_title
    t6.fill = navy_fill
    t6.alignment = align_center

    # Section 1: Egyptian Customs Calculation Engine
    ws6.cell(row=4, column=1, value="1. محرك الحساب الجمركي المصري (Egyptian Customs Calculation Engine)").font = font_sec_header
    ws6.merge_cells("A5:G5")
    ws6.cell(row=5, column=1, value="المسار الحسابي الإلزامي طبقاً لقانون الجمارك ولائحته التنفيذية (من كود البند الجمركي HS Code):").font = font_sub_title
    ws6.cell(row=5, column=1).fill = slate_fill
    ws6.cell(row=5, column=1).alignment = align_right

    customs_headers = ["تسلسل الخطوة", "البند الجمركي", "المعادلة الرياضية الصارمة", "المصدر والملاحظات"]
    for col_idx, h in enumerate(customs_headers, start=1):
        c = ws6.cell(row=6, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    customs_steps = [
        ("الخطوة 1", "القيمة سيف (CIF Value)", "CIF = FOB + Freight + Insurance", "تحويل إجمالي القيمة للجنيه المصري باستخدام سعر صرف الجمارك المعلن في تاريخ قيد الإقرار."),
        ("الخطوة 2", "ضريبة الوارد (Import Duty)", "Import Duty = CIF × Duty Rate%", "تؤخذ النسبة المئوية حصراً من جدول التعريفة الجمركية للبند (HS Code) مع تطبيق الإعفاء التفضيل إن وجد."),
        ("الخطوة 3", "وعاء ضريبة القيمة المضافة (VAT Base)", "VAT Base = CIF + Import Duty", "قاعدة صارمة: النولون والتأمين مشمولان تلقائياً في CIF؛ ورسوم التنمية وأجور الخدمات لا تدخل في وعاء القيمة المضافة."),
        ("الخطوة 4", "ضريبة القيمة المضافة (VAT)", "VAT = VAT Base × VAT Rate%", "قاعدة حرجة: نسبة القيمة المضافة لا تفترض أبداً 14% بل تتحدد من واقع البند الجمركي لكل صنف (قد تكون 0% أو 5% أو 14%)."),
        ("الخطوة 5", "ضريبة الجدول (Schedule Tax)", "Schedule Tax = CIF × Schedule Rate%", "تطبق على سلع محددة بنص القانون كنسبة مئوية من القيمة سيف وتضاف للرسوم الإجمالية."),
        ("الخطوة 6", "أجور الخدمات ورسوم التنمية", "Customs Service Fees + Development Fee", "تحتسب وفق جداول الرسوم الإدارية وأجور التخزين والمناولة المقررة بنص اللائحة التنفيذية."),
        ("الخطوة 7", "إجمالي الرسوم والضرائب (Total Customs)", "Total = Duty + VAT + Schedule + Services + Dev", "المبلغ الإجمالي النهائي الواجب سداده بالقسيمة الجمركية لسحب إذن الإفراج الأخضر."),
    ]
    for row_idx, r in enumerate(customs_steps, start=7):
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(r, start=1):
            c = ws6.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 2]:
                c.alignment = align_center
                c.font = font_data_bold
            elif col_idx == 3:
                c.alignment = align_left
                c.font = font_code
            else:
                c.alignment = align_right

    # Section 2: Landed Cost Engine
    start_r2 = 16
    ws6.cell(row=start_r2, column=1, value="2. محرك تكلفة الوصول الشاملة للبضاعة (Landed Cost Engine)").font = font_sec_header
    
    cost_headers = ["عنصر التكلفة", "طبيعة البند", "طريقة التوزيع على الأصناف (Allocation)", "الأثر المحاسبي"]
    for col_idx, h in enumerate(cost_headers, start=1):
        c = ws6.cell(row=start_r2 + 1, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    cost_items_data = [
        ("سعر الشراء الفعلي (FOB / CIF)", "تكلفة مباشرة", "مباشر لكل صنف وفق الفاتورة التجارية", "تكلفة البضاعة الأصلية المسددة للمورد الخارجي."),
        ("نولون الشحن الدولي (Freight)", "تكلفة مشتركة", "حسب الوزن القائم أو الحجم CBM للبند", "نولون الخط الملاحي أو وكيل الشحن الدولي."),
        ("قسط التأمين البحري (Insurance)", "تكلفة مشتركة", "نسبة وتناسب مع قيمة كل صنف (FOB)", "تأمين المخاطر البحرية ضد الفقد والتلف."),
        ("ضريبة الوارد الجمركية (Duty)", "تكلفة مباشرة", "مباشر لكل صنف وفق بند التعريفة (HS Code)", "رسوم سيادية غير مستردة تضاف لتكلفة المخزون."),
        ("ضريبة القيمة المضافة (VAT)", "ضريبة مستردة / تكلفة", "مباشر لكل صنف", "تعد ضريبة مدخلات مستردة للمنشآت المسجلة، أو تضاف للتكلفة لغير الخاضعين."),
        ("ضريبة الجدول ورسوم التنمية", "تكاليف جمركية", "مباشر أو نسبة من القيمة سيف", "مصروفات حكومية لازمة للإفراج عن الشحنة."),
        ("أتعاب التخليص الجمركي (Brokerage)", "تكلفة خدمية مشتركة", "بالتساوي أو نسبة من قيمة البنود", "أتعاب مكتب التخليص الجمركي المعتمد."),
        ("النقل البري الداخلي (Inland)", "تكلفة لوجستية", "حسب وزن وحجم طرود كل صنف", "تكلفة نقل الحاويات والبضائع من الميناء للمستودع."),
        ("أرضيات وغرامات التأخير (D&D)", "تكاليف استثنائية", "تحميل عام أو على بنود الحاويات المعنية", "غرامات تأخير الحاويات والأرضيات بالميناء إن وجدت."),
        ("مصروفات التفريغ والمناولة المخزنية", "تكلفة عمالة ومخازن", "حسب عدد الطرود والوزن", "أجور العمالة والرافعات الشوكية لتسكين البضاعة."),
    ]
    for row_idx, r in enumerate(cost_items_data, start=start_r2 + 2):
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(r, start=1):
            c = ws6.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 2]:
                c.alignment = align_center
                c.font = font_data_bold
            else:
                c.alignment = align_right

    # Section 3: Hard Domain Rules & Governance
    start_r3 = 29
    ws6.cell(row=start_r3, column=1, value="3. قواعد العمل الصارمة والحوكمة النظامية (Strict Domain Rules)").font = font_sec_header
    
    rule_headers = ["القاعدة النظامية", "مستوى التطبيق", "التطبيق الإلزامي في الكود وقاعدة البيانات", "الأثر والمخاطر المترتبة على المخالفة"]
    for col_idx, h in enumerate(rule_headers, start=1):
        c = ws6.cell(row=start_r3 + 1, column=col_idx, value=h)
        c.font = font_tbl_header
        c.fill = slate_fill
        c.alignment = align_center
        c.border = cell_border

    strict_rules = [
        ("الحذف المنطقي الإلزامي (Soft Delete)", "قاعدة البيانات والتطبيق", "is_active = False, deleted_at = timestamp, deleted_by = user_id. يمنع منعاً باتاً الحذف الفيزيائي (Hard Delete) لأي سجل استيرادي.", "ضمان الحفظ الجنائي وسجل التدقيق لجميع المعاملات المالية والجمركية للشركات."),
        ("حظر افتراض نسب الضرائب (No Hardcoded VAT)", "المحرك الجمركي", "منع افتراض VAT = 14% نهائياً. كل بند HS Code يحدد نسبة ضريبة الوارد والقيمة المضافة بشكل ديناميكي من جدول customs_tariffs.", "تجنب التقديرات الخاطئة لمستحقات الجمارك والمساءلة القانونية لمصلحة الضرائب المصرية."),
        ("سعر صرف الجمارك الرسمي (Customs Exchange Rate)", "المالية والجمارك", "استخدام سعر صرف الجمارك الرسمي المعلن والمعمول به في تاريخ قيد البيان الجمركي وليس تاريخ الفاتورة.", "تطابق القيمة الدفترية مع الإقرار الجمركي 46 ك.م المعتمد لدى البنك والجمارك."),
        ("التحقق المزدوج للبيانات (Dual Integrity Layer)", "التطبيق والـ DB", "مستوى التطبيق: فحص التكرار برمجياً قبل الحفظ. مستوى قاعدة البيانات: UNIQUE constraints ومفاتيح أجنبية صارمة.", "حماية المنظومة من تكرار تسجيل أرقام ACID أو بوالص الشحن أو فواتير الموردين."),
        ("حظر الانتقال بين المراحل بدون استيفاء (Gateways)", "دورة الحياة", "كل خطوة في الـ 23 خطوة لها شروط تحقق إلزامية. يمنع الانتقال للخطوة التالية إلا بعد استيفاء الشروط أو تسجيل مبرر تخطي رسمي معتمد.", "منع التقدم في الشحن قبل استخراج ACID أو الإفراج قبل صدور نموذج 4 البنكي."),
        ("تتبع صلاحية ACID قبل 14 يوماً (ACID Tracking)", "نظام الإشعارات", "إطلاق تنبيهات ذكية تبدأ قبل 14 يوماً من انتهاء الـ 90 يوماً الخاصة بالـ ACID، وحظر إجازة المستندات التلقائي عند الانتهاء.", "منع شحن بضائع برقم ACID منتهي وما يترتب عليه من غرامات إعادة الشحن أو المصادرة."),
    ]
    for row_idx, r in enumerate(strict_rules, start=start_r3 + 2):
        fill = zebra_fill if row_idx % 2 == 0 else None
        for col_idx, val in enumerate(r, start=1):
            c = ws6.cell(row=row_idx, column=col_idx, value=val)
            c.font = font_data_regular
            c.border = cell_border
            if fill:
                c.fill = fill
            if col_idx in [1, 2]:
                c.alignment = align_center
                c.font = font_data_bold
            else:
                c.alignment = align_right

    # ════════════════════════════════════════════════════════════════
    # AUTO-FIT COLUMN WIDTHS & FREEZE PANES ACROSS ALL SHEETS
    # ════════════════════════════════════════════════════════════════
    print("Auto-fitting columns and formatting sheets...")
    for ws in wb.worksheets:
        ws.sheet_properties.tabColor = NAVY_HEX
        # Freeze top header rows
        if ws.title == "لوحة المعمارية والنظام":
            ws.freeze_panes = "A4"
        elif ws.title in ["مراحل دورة الحياة (23 خطوة)", "فهرس كل الجداول (110 جدول)", "شبكة العلاقات والترابط (154)", "محركات الحساب وقواعد العمل"]:
            ws.freeze_panes = "A5"
        elif ws.title == "قاموس البيانات والأعمدة (2358)":
            ws.freeze_panes = "A5"

        # Auto-fit column widths
        for col in range(1, ws.max_column + 1):
            max_len = 0
            col_letter = get_column_letter(col)
            for row in range(1, min(ws.max_row + 1, 300)): # sample top 300 rows for speed
                v = ws.cell(row=row, column=col).value
                if v is not None:
                    lines = str(v).split("\n")
                    line_len = max(len(l) for l in lines)
                    if line_len > max_len:
                        max_len = line_len
            
            # Apply reasonable bounds
            ws.column_dimensions[col_letter].width = min(max(max_len + 3, 12), 65)

    # Specific fine-tuning for column widths
    ws4.column_dimensions["A"].width = 28 # Table name
    ws4.column_dimensions["B"].width = 30 # Table AR
    ws4.column_dimensions["C"].width = 25 # Col name
    ws4.column_dimensions["D"].width = 16 # Type
    ws4.column_dimensions["G"].width = 30 # Reference
    ws4.column_dimensions["J"].width = 50 # Description

    ws5.column_dimensions["B"].width = 28
    ws5.column_dimensions["D"].width = 24
    ws5.column_dimensions["E"].width = 28
    ws5.column_dimensions["J"].width = 55

    # Save output
    wb.save(output_file)
    print(f"Successfully generated Master Excel Atlas: {output_file}")


if __name__ == "__main__":
    out_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "ImportFlow_ERP_System_Components_and_Database_Atlas.xlsx"))
    build_system_atlas_excel(out_path)
