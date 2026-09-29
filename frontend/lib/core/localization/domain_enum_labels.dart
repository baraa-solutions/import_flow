import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// Enum-like values that are picked from a fixed list and saved to the backend.
///
/// Storage rule (docs/plans/single-language-storage-plan.md, tier T3): the
/// request carries the UPPER_SNAKE code (currency uses the ISO code `EGP`),
/// never a translated or mixed ar/en label. The UI shows
/// `AppLocalizations.domainEnumLabel(type, code)` in the user's language.
///
/// Rows saved before the codes existed hold a legacy label such as
/// `'نهائي وبات (Final Green Release)'`. [legacyToCode] maps those labels to
/// their code so they display in the current language and preselect the right
/// dropdown item. Unknown values are shown as stored.
class DomainEnumType {
  DomainEnumType._();

  static const releaseType = 'release_type';
  static const paymentMethod = 'payment_method';
  static const dutyBank = 'duty_bank';
  static const clearanceExpenseCategory = 'expense_category';
  static const truckType = 'truck_type';
  static const regulatoryBody = 'regulatory_body';
  static const inspectionYard = 'inspection_yard';
  static const depot = 'depot';
  static const clearanceServiceCategory = 'service_category';
  static const currency = 'currency';
  static const brokerExpenseCategory = 'broker_expense_category';
  static const brokerUnit = 'broker_unit';
  static const holdReason = 'hold_reason';
  static const skipReasonCategory = 'skip_reason_category';
  /// Import-file stage (`current_stage_code`): PHASE_n or a special stage such as CUSTOMS_RELEASED.
  static const stage = 'stage';
  static const customsChannel = 'customs_channel';
  static const inspectionResult = 'inspection_result';
  static const requirementStatus = 'requirement_status';
  static const warehouseInspectionVerdict = 'warehouse_inspection_verdict';
  static const dbHealthVerdict = 'db_health_verdict';
  static const alertSeverity = 'alert_severity';
  static const landedCostVarianceStatus = 'landed_cost_variance_status';
  /// Tariff `customs_category` (goods classification).
  static const customsCategory = 'customs_category';
  /// Comparison-item placeholder standing where a value is missing (`structured_values`).
  static const valuePlaceholder = 'value_placeholder';
  /// Unit of a measured comparison value (`structured_values`).
  static const measureUnit = 'measure_unit';
}

class DomainEnums {
  DomainEnums._();

  /// Codes per type, in display order.
  static const Map<String, List<String>> codes = {
    DomainEnumType.releaseType: [
      'FINAL_GREEN',
      'UNDER_BOND',
      'TEMPORARY_ADMISSION',
      'POST_TESTING_CONFORMING',
    ],
    DomainEnumType.paymentMethod: [
      'SADAD_EFINANCE',
      'BANK_TRANSFER',
      'CBE_DIRECT',
      'CASHIER_DEPOSIT',
    ],
    DomainEnumType.dutyBank: [
      'NBE',
      'BM',
      'CIB',
      'BDC',
      'QNB',
      'CBE',
      'MTS_CASHIER',
      'OTHER',
    ],
    DomainEnumType.clearanceExpenseCategory: [
      'BROKER_FEES',
      'PORT_DUES_WHARFAGE',
      'STEVEDORING_HANDLING',
      'INSPECTION_WEIGHING',
      'LABORATORY_TESTING',
      'STORAGE_DEMURRAGE',
      'OTHER_CLEARANCE',
    ],
    DomainEnumType.truckType: [
      'FLATBED',
      'SIDE_DROP',
      'CURTAINSIDER',
      'CONTAINER_CHASSIS',
      'BOX_TRUCK',
      'REEFER',
      'LOW_BED',
    ],
    DomainEnumType.regulatoryBody: [
      'GOEIC',
      'NFSA',
      'NTRA',
      'CHEMISTRY_DEPT',
      'QUARANTINE',
      'AGRICULTURAL_QUARANTINE',
      'VETERINARY_QUARANTINE',
      'EDA',
      'INDUSTRIAL_CONTROL',
      'ATOMIC_ENERGY',
      'WEIGHTS_MEASURES',
    ],
    DomainEnumType.inspectionYard: [
      'ALEXANDRIA_BERTH_42',
      'DEKHEILA',
      'AIN_SOKHNA',
      'DAMIETTA',
      'WEST_PORT_SAID',
      'EAST_PORT_SAID',
      'OCTOBER_DRY_PORT',
      'TENTH_RAMADAN_DRY_PORT',
      'CAIRO_AIRPORT_CARGO',
      'ADABIYA',
    ],
    DomainEnumType.depot: [
      'ALEXANDRIA_CARRIER_DEPOT',
      'DEKHEILA_YARD',
      'SOKHNA_LOGISTICS_DEPOT',
      'PORT_SAID_WEST_DEPOT',
      'DAMIETTA_EMPTY_YARD',
      'SOKHNA_DP_WORLD_YARD',
    ],
    DomainEnumType.clearanceServiceCategory: [
      'CLEARANCE_FEE',
      'INLAND_TRANSPORT',
      'INSPECTION_FEE',
      'PORT_CHARGES',
    ],
    DomainEnumType.currency: ['EGP'],
    DomainEnumType.brokerExpenseCategory: [
      'CLEARANCE_FEES',
      'PROCEDURES_APPROVALS',
      'INLAND_TRANSPORT',
      'PORT_HANDLING',
      'OFFICIAL_RECEIPTS',
      'OTHER_FEES',
    ],
    DomainEnumType.brokerUnit: [
      'FIXED',
      'PER_INVOICE',
      'PER_TON',
      'PER_EXTRA_TON',
      'PER_CONTAINER',
      'PER_CONTAINER_20FT',
      'PER_CONTAINER_40FT',
      'PER_TRUCK',
      'PER_VEHICLE',
      'PER_TRIP',
      'PER_DAY',
      'PER_NIGHT',
      'PER_SHIPMENT',
      'PER_DECLARATION',
      'PER_BL',
      'PER_INSPECTION',
      'PER_SAMPLE',
      'PER_CASE',
      'PER_TRAILER',
      'RANGE',
    ],
    DomainEnumType.holdReason: [
      'AWAITING_SUPPLIER_APPROVAL',
      'DRAFT_BL_AMENDMENT',
      'AWAITING_BANK_FORM4',
      'PENDING_REGULATORY_APPROVAL',
      'BOOKING_DELAYED',
      'TARIFF_VALUATION_REVIEW',
      'ADDITIONAL_INSPECTION',
      'ADMIN_HOLD',
      'OTHER',
    ],
    DomainEnumType.skipReasonCategory: [
      'CLIENT_AGREEMENT',
      'NOT_APPLICABLE_TO_MODE',
      'REGULATORY_EXEMPTION',
      'OTHER',
    ],
    DomainEnumType.stage: [
      'ARCHIVED_CLOSED',
      'ARRIVED_AT_WAREHOUSE',
      'CLOSED_EARLY',
      'CLOSURE_IN_PROGRESS',
      'CUSTOMS_BROKER_AUTHORIZED',
      'CUSTOMS_DUTY_ASSESSED',
      'CUSTOMS_INSPECTION_COMPLETED',
      'CUSTOMS_RELEASED',
      'DELIVERY_ORDER_PAID',
      'DISCREPANCY_PROTOCOL_FILED',
      'DRAFT',
      'DUTY_PAID',
      'GOODS_RECEIVED',
      'INLAND_TRANSPORT_BOOKED',
      'IN_TRANSIT_TO_WAREHOUSE',
      'LAB_APPROVED_RELEASED',
      'LAB_REJECTED',
      'LANDED_COST_CALCULATED',
      'PHASE_1',
      'PHASE_2',
      'PHASE_3',
      'PHASE_4',
      'PHASE_5',
      'PHASE_6',
      'QC_PASSED',
      'QUARANTINED_UNDER_INSPECTION',
      'REOPENED',
      'UNDER_BOND_QUARANTINE',
      'UNDER_CUSTOMS_CLEARANCE',
    ],
    DomainEnumType.customsChannel: [
      'GREEN',
      'RED',
      'YELLOW',
    ],
    DomainEnumType.inspectionResult: [
      'CONFORMING',
      'DISCREPANCY',
      'SHORTAGE',
      'SURPLUS',
    ],
    DomainEnumType.requirementStatus: [
      'APPLIED',
      'APPROVED',
      'COMPLETED',
      'EXPIRED',
      'IN_PROGRESS',
      'NOT_REQUIRED',
      'OBTAINED',
      'PENDING',
      'RECEIVED',
      'REJECTED',
      'VERIFIED',
    ],
    DomainEnumType.warehouseInspectionVerdict: [
      'ACCEPTED_FULL',
      'ACCEPTED_WITH_DISCREPANCY',
      'DAMAGE_CLAIM_PENDING',
      'PENDING',
      'REJECTED_QUARANTINED',
    ],
    DomainEnumType.dbHealthVerdict: [
      'CRITICAL',
      'DEGRADED',
      'HEALTHY',
    ],
    DomainEnumType.alertSeverity: [
      'CRITICAL',
      'HIGH',
      'INFO',
      'WARNING',
    ],
    DomainEnumType.landedCostVarianceStatus: [
      'ON_BUDGET',
      'OVER_BUDGET',
      'UNDER_BUDGET',
    ],
    DomainEnumType.customsCategory: [
      'AUTOMOTIVE',
      'AUTOMOTIVE_SPARE_PARTS',
      'ELECTRONICS',
      'FOOD_AGRICULTURAL',
      'GENERAL_GOODS',
      'INDUSTRIAL_MACHINERY',
      'MACHINERY_EQUIPMENT',
      'PHARMACEUTICALS',
      'PLASTICS_POLYMERS',
      'RAW_MATERIALS_METALS',
      'TELECOMMUNICATIONS',
      'TEXTILES',
    ],
    DomainEnumType.valuePlaceholder: [
      'NOT_EXTRACTED',
      'NOT_IN_BL',
      'NOT_IN_DOCUMENT',
      'NOT_IN_INVOICE',
      'NOT_IN_PACKING_LIST',
      'NOT_SET',
      'NOT_SPECIFIED',
      'OPTIONAL_NOT_INCLUDED',
    ],
    DomainEnumType.measureUnit: [
      'CBM',
      'KG',
      'PACKAGES',
      'PACKAGES_PALLETS',
    ],
  };

  /// Labels written by older clients (and by older backend defaults/seeds),
  /// mapped to their code. Keys are compared after whitespace normalisation.
  static const Map<String, Map<String, String>> _legacy = {
    DomainEnumType.releaseType: {
      'نهائي وبات (Final Green Release)': 'FINAL_GREEN',
      'نهائي وبات': 'FINAL_GREEN',
      'إفراج مؤقت تحت التحفظ (Under-Bond Release)': 'UNDER_BOND',
      'إفراج برسم السماح المؤقت (Temporary Admission)': 'TEMPORARY_ADMISSION',
      'إفراج قطعي بعد استيفاء العينات (Post-Testing Conforming Release)': 'POST_TESTING_CONFORMING',
      'Final Green Release': 'FINAL_GREEN',
      'Under-Bond Release': 'UNDER_BOND',
      'Temporary Admission': 'TEMPORARY_ADMISSION',
      'Post-Testing Conforming Release': 'POST_TESTING_CONFORMING',
    },
    DomainEnumType.paymentMethod: {
      'E-Finance / Sadad': 'SADAD_EFINANCE',
      'Sadad / E-Finance': 'SADAD_EFINANCE',
      'Sadad': 'SADAD_EFINANCE',
      'E-Finance': 'SADAD_EFINANCE',
      'Bank Transfer / تحويل بنكي': 'BANK_TRANSFER',
      'CBE Direct / خصم البنك المركزي': 'CBE_DIRECT',
      'Cashier Deposit / إيداع خزينة الجمرك': 'CASHIER_DEPOSIT',
      'Bank Transfer': 'BANK_TRANSFER',
      'CBE Direct': 'CBE_DIRECT',
      'Cashier Deposit': 'CASHIER_DEPOSIT',
    },
    DomainEnumType.dutyBank: {
      'البنك الأهلي المصري (NBE)': 'NBE',
      'بنك مصر (BM)': 'BM',
      'البنك التجاري الدولي (CIB)': 'CIB',
      'بنك القاهرة (BDC)': 'BDC',
      'بنك قطر الوطني الأهلي (QNB)': 'QNB',
      'البنك المركزي المصري (CBE)': 'CBE',
      'خزينة مصلحة الجمارك (MTS Cashier)': 'MTS_CASHIER',
      'أخرى': 'OTHER',
    },
    DomainEnumType.clearanceExpenseCategory: {
      'Customs Broker Fees (أتعاب التخليص الجمركي)': 'BROKER_FEES',
      'Port Dues & Wharfage (نولون ورسوم الميناء والرصيف)': 'PORT_DUES_WHARFAGE',
      'Stevedoring & Handling (مصاريف العتالة والشحن والتفريغ)': 'STEVEDORING_HANDLING',
      'Inspection & Weighing (رسوم الفحص والوزن والمعاينة)': 'INSPECTION_WEIGHING',
      'Laboratory & Testing Fees (مصاريف التحاليل والمعامل)': 'LABORATORY_TESTING',
      'Storage & Demurrage (رسوم الأرضيات وغرامات التأخير)': 'STORAGE_DEMURRAGE',
      'Other Clearance Expenses (مصاريف تخليص أخرى)': 'OTHER_CLEARANCE',
    },
    DomainEnumType.truckType: {
      'Flatbed Trailer (تريلا مسطح)': 'FLATBED',
      'Side-Drop Trailer (تريلا جوانب)': 'SIDE_DROP',
      'Curtainsider (تريلا ستارة)': 'CURTAINSIDER',
      'Container Chassis (شاسية حاوية 40/20 قدم)': 'CONTAINER_CHASSIS',
      'Box Truck (جامبو مغلق)': 'BOX_TRUCK',
      'Reefer Truck (شاحنة مبردة)': 'REEFER',
      'Heavy Low-bed (لوبد ثقيل للطرود الضخمة)': 'LOW_BED',
      'Flatbed Trailer': 'FLATBED',
    },
    DomainEnumType.regulatoryBody: {
      'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)': 'GOEIC',
      'الهيئة القومية لسلامة الغذاء (NFSA)': 'NFSA',
      'Food Safety Authority': 'NFSA',
      'Food Safety': 'NFSA',
      'Radiation': 'ATOMIC_ENERGY',
      'Chemistry': 'CHEMISTRY_DEPT',
      'الجهاز القومي لتنظيم الاتصالات (NTRA)': 'NTRA',
      'مصلحة الكيمياء (Chemistry Dept)': 'CHEMISTRY_DEPT',
      'مصلحة الكيمياء المصرية (Chemistry Dept)': 'CHEMISTRY_DEPT',
      'الحجر الزراعي / البيطري (Quarantine)': 'QUARANTINE',
      'الحجر الزراعي المصري': 'AGRICULTURAL_QUARANTINE',
      'الحجر البيطري': 'VETERINARY_QUARANTINE',
      'هيئة الدواء المصرية (EDA)': 'EDA',
      'مصلحة الرقابة الصناعية': 'INDUSTRIAL_CONTROL',
      'إدارة الوقاية الإشعاعية وهيئة الطاقة الذرية': 'ATOMIC_ENERGY',
      'مصلحة الموازين والدمغة': 'WEIGHTS_MEASURES',
    },
    DomainEnumType.inspectionYard: {
      'ساحة الفحص المشترك - ميناء الإسكندرية (رصيف 42)': 'ALEXANDRIA_BERTH_42',
      'ساحة الفحص المشترك - ميناء الدخيلة': 'DEKHEILA',
      'ساحة الفحص والكشف المشترك - ميناء العين السخنة': 'AIN_SOKHNA',
      'ساحة المعاينة والكشف - ميناء دمياط البحري': 'DAMIETTA',
      'ساحة المعاينة والفحص - ميناء غرب بورسعيد': 'WEST_PORT_SAID',
      'ساحة الفحص الجمركي - ميناء شرق بورسعيد': 'EAST_PORT_SAID',
      'ساحة الفحص المشترك بالميناء الجاف بمدينة 6 أكتوبر': 'OCTOBER_DRY_PORT',
      'ساحة الفحص بالميناء الجاف بمدينة العاشر من رمضان': 'TENTH_RAMADAN_DRY_PORT',
      'قرية البضائع - مطار القاهرة الدولي': 'CAIRO_AIRPORT_CARGO',
      'ساحة الفحص المشترك - ميناء الأدبية بالسويس': 'ADABIYA',
    },
    DomainEnumType.depot: {
      'Alexandria Port Carrier Depot (مستودع الإسكندرية الفارغ)': 'ALEXANDRIA_CARRIER_DEPOT',
      'Dekheila Yard (ساحة حاويات الدخيلة)': 'DEKHEILA_YARD',
      'Sokhna Logistics Depot (مستودع السخنة اللوجستي)': 'SOKHNA_LOGISTICS_DEPOT',
      'Port Said West Depot (مستودع غرب بورسعيد)': 'PORT_SAID_WEST_DEPOT',
      'Damietta Port Empty Yard (ساحة دمياط الفارغ)': 'DAMIETTA_EMPTY_YARD',
      'Ain Sokhna DP World Yard (ساحة موانئ دبي السخنة)': 'SOKHNA_DP_WORLD_YARD',
    },
    DomainEnumType.clearanceServiceCategory: {
      'Clearance Fee': 'CLEARANCE_FEE',
      'Clearance Agency Fee': 'CLEARANCE_FEE',
      'أتعاب التخليص الجمركي': 'CLEARANCE_FEE',
      'Inland Transport': 'INLAND_TRANSPORT',
      'النقل الداخلي': 'INLAND_TRANSPORT',
      'Inspection & Examination Fee': 'INSPECTION_FEE',
      'مصاريف الفحص والعرض': 'INSPECTION_FEE',
      'Port & Demurrage Charges': 'PORT_CHARGES',
      'رسوم ومصاريف الموانئ': 'PORT_CHARGES',
    },
    DomainEnumType.currency: {
      'جنيه': 'EGP',
      'ج.م': 'EGP',
      'جنيه مصري': 'EGP',
    },
    DomainEnumType.brokerExpenseCategory: {
      'Clearance Fees (أتعاب ومصاريف تخليص)': 'CLEARANCE_FEES',
      'Procedures & Approvals (إجراءات وموافقات وفحص)': 'PROCEDURES_APPROVALS',
      'Inland Transport (نقل بري وشاحنات)': 'INLAND_TRANSPORT',
      'Port & Handling (موانئ وتعتيق وتفريغ)': 'PORT_HANDLING',
      'Other Fees (مصاريف أخرى)': 'OTHER_FEES',
      'Official Port & Shipping Line Receipts': 'OFFICIAL_RECEIPTS',
      'Port Handling & Storage': 'PORT_HANDLING',
      'أتعاب ومصاريف تخليص': 'CLEARANCE_FEES',
      'Clearance Fees': 'CLEARANCE_FEES',
      'Procedures & Approvals': 'PROCEDURES_APPROVALS',
      'Inland Transport': 'INLAND_TRANSPORT',
      'Port & Handling': 'PORT_HANDLING',
      'Other Fees': 'OTHER_FEES',
    },
    DomainEnumType.brokerUnit: {
      'Fixed (مبلغ ثابت)': 'FIXED',
      'Fixed': 'FIXED',
      'Fixed Amount': 'FIXED',
      'Per Container (لكل حاوية)': 'PER_CONTAINER',
      'Per Container (لكل حاوية إضافية)': 'PER_CONTAINER',
      'Per Shipment (لكل إقرار)': 'PER_SHIPMENT',
      'Per Container': 'PER_CONTAINER',
      'Per Invoice (لكل فاتورة)': 'PER_INVOICE',
      'Per Invoice': 'PER_INVOICE',
      'Per Case (لكل حالة)': 'PER_CASE',
      'Per Case (لكل عرض)': 'PER_CASE',
      'Per Case': 'PER_CASE',
      'Per Container (لكل نقلة وزن)': 'PER_CONTAINER',
      'Per Inspection (لكل كشف)': 'PER_INSPECTION',
      'Per Sample (لكل إجراء)': 'PER_SAMPLE',
      'Per Sample (لكل عينة)': 'PER_SAMPLE',
      'Per Sample': 'PER_SAMPLE',
      'Per Shipment (لكل تعتيق)': 'PER_SHIPMENT',
      'Per Shipment (لكل وزن)': 'PER_SHIPMENT',
      'Per Trailer (لكل تريلا)': 'PER_TRAILER',
      'Per Trailer': 'PER_TRAILER',
      'Per B/L (لكل بوليصة)': 'PER_BL',
      'Per B/L': 'PER_BL',
      'Per Shipment (لكل شحنة)': 'PER_SHIPMENT',
      'Per Shipment': 'PER_SHIPMENT',
      'Per Ton (لكل طن)': 'PER_TON',
      'Per Ton (لكل طن إضافي)': 'PER_EXTRA_TON',
      'Per Ton': 'PER_TON',
      'Per Vehicle (لكل سيارة)': 'PER_VEHICLE',
      'Per Vehicle': 'PER_VEHICLE',
      'Per Night (لكل ليلة)': 'PER_NIGHT',
      'Per Night': 'PER_NIGHT',
      'Per Day': 'PER_DAY',
      'Per Inspection (لكل عرض)': 'PER_INSPECTION',
      'Per Inspection': 'PER_INSPECTION',
    },
    DomainEnumType.holdReason: {
      'في انتظار رد وموافقة المورد الخارجي': 'AWAITING_SUPPLIER_APPROVAL',
      'طلب تعديل على مسودة بوليصة الشحن': 'DRAFT_BL_AMENDMENT',
      'في انتظار موافقة البنك وإصدار نموذج 4': 'AWAITING_BANK_FORM4',
      'استيفاء موافقة جهة العرض والرقابة': 'PENDING_REGULATORY_APPROVAL',
      'تأخير الحجز وتأكيد الخط الملاحي': 'BOOKING_DELAYED',
      'مراجعة وتدقيق أسعار بنود التعريفة الجمركية': 'TARIFF_VALUATION_REVIEW',
      'طلب فحص ومعاينة إضافية للبضاعة': 'ADDITIONAL_INSPECTION',
      'تعليق إداري مؤقت للشحنة': 'ADMIN_HOLD',
      'Awaiting foreign supplier approval': 'AWAITING_SUPPLIER_APPROVAL',
      'Requested amendment on draft B/L': 'DRAFT_BL_AMENDMENT',
      'Awaiting bank Form 4 issuance': 'AWAITING_BANK_FORM4',
      'Pending regulatory authority approval': 'PENDING_REGULATORY_APPROVAL',
      'Shipping line booking delayed': 'BOOKING_DELAYED',
      'Customs tariff valuation review': 'TARIFF_VALUATION_REVIEW',
      'Additional physical inspection required': 'ADDITIONAL_INSPECTION',
      'Temporary administrative hold': 'ADMIN_HOLD',
    },
    DomainEnumType.skipReasonCategory: {
      'Client Agreement / العميل يتولى الإجراء حسب الاتفاقية': 'CLIENT_AGREEMENT',
      'Not Applicable to Mode / لا تنطبق على نمط الشحن': 'NOT_APPLICABLE_TO_MODE',
      'Regulatory Exemption / إعفاء رسمي أو رقابي': 'REGULATORY_EXEMPTION',
      'Other / أخرى': 'OTHER',
    },
    DomainEnumType.stage: {
      'Customs Broker Authorized (تفويض المخلص الجمركي)': 'CUSTOMS_BROKER_AUTHORIZED',
      'Customs Duty Assessed (احتساب الرسوم الجمركية والمطالبة)': 'CUSTOMS_DUTY_ASSESSED',
      'Customs Inspection & Sampling Completed (تم الكشف وسحب العينات)': 'CUSTOMS_INSPECTION_COMPLETED',
      'Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)': 'CUSTOMS_RELEASED',
      'Delivery Order Paid & Received (سداد إذن التسليم الملاحي)': 'DELIVERY_ORDER_PAID',
      'Duty Paid (تم سداد الرسوم الجمركية بسداد)': 'DUTY_PAID',
      'In Transit to Warehouse (الشحنة في الطريق للمخزن)': 'IN_TRANSIT_TO_WAREHOUSE',
      'Lab Rejected (مرفوض معملياً)': 'LAB_REJECTED',
      'Phase 1: Pre-Planning & Studies': 'PHASE_1',
      'Phase 2: Approvals & ACID': 'PHASE_2',
      'Phase 3: Booking & Doc Prep': 'PHASE_3',
      'Phase 4: Digital & Banking': 'PHASE_4',
      'Phase 5: Port Operations & Clearance': 'PHASE_5',
      'Phase 6: Inbound & Final Closure': 'PHASE_6',
      'Under Customs Clearance (تحت التخليص والكشف 46)': 'UNDER_CUSTOMS_CLEARANCE',
      'Under-Bond Quarantine (سحب على عهدة)': 'UNDER_BOND_QUARANTINE',
      'المرحلة الأولى: التخطيط والدراسات المسبقة': 'PHASE_1',
      'المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي': 'PHASE_3',
      'المرحلة الثانية: بداية الشحنة': 'PHASE_2',
      'المرحلة الخامسة: عمليات الميناء والتخليص الجمركي': 'PHASE_5',
      'المرحلة الرابعة: التوثيق الرقمي والاعتماد البنكي': 'PHASE_4',
      'المرحلة السادسة: الاستلام المخزني والتسوية المالية': 'PHASE_6',
    },
    DomainEnumType.customsCategory: {
      'General': 'GENERAL_GOODS',
      'آلات وأجهزة وتجهيزات': 'MACHINERY_EQUIPMENT',
      'أصناف عامة': 'GENERAL_GOODS',
    },
    DomainEnumType.valuePlaceholder: {
      'اختياري / غير مدرج': 'OPTIONAL_NOT_INCLUDED',
      'غير متوفر': 'NOT_IN_DOCUMENT',
      'غير متوفر بالباكينج': 'NOT_IN_PACKING_LIST',
      'غير متوفر بالبوليصة': 'NOT_IN_BL',
      'غير متوفر بالسستم': 'NOT_SET',
      'غير متوفر بالفاتورة': 'NOT_IN_INVOICE',
      'غير متوفر بالمستند': 'NOT_IN_DOCUMENT',
      'غير محدد': 'NOT_SPECIFIED',
      'غير محدد بالباكينج': 'NOT_IN_PACKING_LIST',
      'غير محدد بالبوليصة': 'NOT_IN_BL',
      'غير محدد بالسستم': 'NOT_SET',
      'غير محدد بالفاتورة': 'NOT_IN_INVOICE',
      'غير مذكور بالفاتورة': 'NOT_IN_INVOICE',
      'غير مسجل': 'NOT_SET',
      'غير مسجل بالباكينج': 'NOT_IN_PACKING_LIST',
      'غير مسجل بالسستم': 'NOT_SET',
      'غير موجود بالباكينج': 'NOT_IN_PACKING_LIST',
      'غير موجود بالبوليصة': 'NOT_IN_BL',
      'غير موجود بالفاتورة': 'NOT_IN_INVOICE',
      'لم يتم الاستخراج': 'NOT_EXTRACTED',
      '— (غير مدرج بالباكينج)': 'NOT_IN_PACKING_LIST',
      '— (غير مدرج بالفاتورة)': 'NOT_IN_INVOICE',
    },
    DomainEnumType.measureUnit: {
      'طرد': 'PACKAGES',
      'طرد/بالتة': 'PACKAGES_PALLETS',
      'كجم': 'KG',
      'م³': 'CBM',
    },
  };

  static final Map<String, Map<String, String>> _normalizedLegacy = {
    for (final e in _legacy.entries)
      e.key: {for (final l in e.value.entries) _normalize(l.key): l.value},
  };

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// The codes of [type] in display order (empty for an unknown type).
  static List<String> codesOf(String type) => codes[type] ?? const [];

  static bool isCode(String type, String? value) =>
      value != null && codesOf(type).contains(value);

  /// Maps a stored value to its code: a code is returned as is (also when it
  /// was stored in lower case, e.g. `per_invoice`), a known legacy label maps
  /// to its code, anything else returns `null`.
  static String? legacyToCode(String type, String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final known = codesOf(type);
    if (known.contains(trimmed)) return trimmed;
    final upper = trimmed.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    if (known.contains(upper)) return upper;
    return _normalizedLegacy[type]?[_normalize(trimmed)];
  }

  /// The label to show for a stored [value] in the language of [l10n].
  /// [code] (e.g. `hold_reason_code`) wins over [value] when it is known.
  /// Unknown values are returned as stored; null/empty returns [fallback].
  static String label(
    AppLocalizations l10n,
    String type,
    String? value, {
    String? code,
    String fallback = '',
  }) {
    final resolved = isCode(type, code) ? code : legacyToCode(type, value);
    if (resolved != null) {
      final text = l10n.domainEnumLabel(type, resolved);
      if (text != null) return text;
    }
    final raw = value?.trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  /// The localized label when [value] is a known code or legacy label, else null
  /// (lets callers keep their own fallback for other vocabularies).
  static String? labelIfKnown(AppLocalizations l10n, String type, String? value) {
    final code = legacyToCode(type, value);
    return code == null ? null : l10n.domainEnumLabel(type, code);
  }

  /// The English label of [code]; used where the backend needs a readable
  /// English text next to the code (e.g. `hold_reason`).
  static String englishLabel(String type, String code) =>
      const AppLocalizationsEn().domainEnumLabel(type, code) ?? code;

  /// The code to preselect in a dropdown for a stored value, or [fallback]
  /// when the value is empty or not a known code/legacy label.
  static String initialCode(String type, String? value, String fallback) =>
      legacyToCode(type, value) ?? fallback;
}
