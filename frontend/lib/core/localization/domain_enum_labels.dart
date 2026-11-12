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
  /// Draft B/L comparison-matrix field (blocking-reason params).
  static const draftBlField = 'draft_bl_field';
  /// CBM recommendation method (`recommended_shipping_method`): AIR / LCL / FCL.
  static const shippingMethod = 'shipping_method';
  /// CBM recommended container (`recommended_container_type`).
  static const containerType = 'container_type';
  /// Purchase-order status (PO_STATUS): DRAFT ... CANCELLED.
  static const poStatus = 'po_status';
  /// CBM study shipment mode (SHIPMENT_MODE): AIR / SEA.
  static const shipmentMode = 'shipment_mode';
  // Review wave types (docs/enum_codes.json).
  static const paymentType = 'payment_type';
  /// Exclusive payment pathway of a shipment (import_files.payment_term).
  static const paymentTerm = 'payment_term';
  static const legalDocKind = 'legal_doc_kind';
  static const labTestResult = 'lab_test_result';
  static const odcStatus = 'odc_status';
  static const originalDocStatus = 'original_doc_status';
  static const originalDocRequired = 'original_doc_required';
  static const courierStatus = 'courier_status';
  static const docReviewStatus = 'doc_review_status';
  static const docApprovalStatus = 'doc_approval_status';
  static const ticketStatus = 'ticket_status';
  static const ticketSeverity = 'ticket_severity';
  static const allocationRule = 'allocation_rule';
  static const settlementStatus = 'settlement_status';
  static const actualCostBucket = 'actual_cost_bucket';
  static const dutyComponent = 'duty_component';
  static const warehouseReceivingStatus = 'warehouse_receiving_status';
  static const grnDiscrepancyType = 'grn_discrepancy_type';
  static const inlandTransportStatus = 'inland_transport_status';
  static const fileClosureStatus = 'file_closure_status';
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
    DomainEnumType.draftBlField: [
      'SHIPPER',
      'CONSIGNEE',
      'NOTIFY_PARTY',
      'VESSEL_NAME',
      'VOYAGE_NUMBER',
      'POL',
      'POD',
      'FREIGHT_TERMS',
      'PLACE_OF_DELIVERY',
      'BOOKING_NO',
      'ACID_NUMBER',
      'IMPORTER_TAX_ID',
      'SHIPPER_REG_ID',
      'SHIPPING_MODE',
      'CONTAINER_SUMMARY',
      'GOODS_DESCRIPTION',
      'TOTAL_GROSS_WEIGHT_KG',
      'TOTAL_NET_WEIGHT_KG',
      'CBM',
      'QTY_PKG',
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
      'GRM',
      'KG',
      'PACKAGES',
      'PACKAGES_PALLETS',
      'SET',
      'STN',
    ],
    DomainEnumType.shippingMethod: ['AIR', 'FCL', 'LCL'],
    DomainEnumType.containerType: ['C20_ST', 'C40_HC', 'C40_ST', 'LCL'],
    DomainEnumType.poStatus: ['DRAFT', 'APPROVED', 'PARTIALLY_SHIPPED', 'FULLY_SHIPPED', 'CLOSED', 'CANCELLED'],
    DomainEnumType.shipmentMode: ['AIR', 'SEA'],
    DomainEnumType.paymentType: [
      'ADVANCE_PAYMENT',
      'AGAINST_BL',
      'DOCUMENTARY_COLLECTION',
      'FINAL_SETTLEMENT',
      'LETTER_OF_CREDIT',
    ],
    DomainEnumType.paymentTerm: ['ADVANCE_PAYMENT', 'LC', 'CAD', 'OPEN_ACCOUNT'],
    DomainEnumType.legalDocKind: [
      'ACID',
      'COMMERCIAL_REGISTRY',
      'IMPORT_CARD',
      'TAX_CARD',
    ],
    DomainEnumType.labTestResult: [
      'CONFORMING',
      'NONE',
      'NON_CONFORMING',
      'PENDING',
    ],
    DomainEnumType.odcStatus: [
      'DRAFT',
      'IN_TRANSIT',
      'PARTIALLY_RECEIVED',
      'FULLY_RECEIVED',
      'FULLY_VERIFIED',
      'DISCREPANCY_NOTED',
    ],
    DomainEnumType.originalDocStatus: [
      'PENDING',
      'IN_TRANSIT',
      'RECEIVED',
      'VERIFIED',
      'DISCREPANT',
      'NOT_REQUIRED',
    ],
    DomainEnumType.originalDocRequired: [
      'YES',
      'NO',
      'CONDITIONAL',
    ],
    DomainEnumType.courierStatus: [
      'DISPATCHED',
      'IN_TRANSIT',
      'DELIVERED',
      'DELAYED',
    ],
    DomainEnumType.docReviewStatus: [
      'PENDING',
      'UNDER_REVIEW',
      'APPROVED',
      'CONDITIONALLY_APPROVED',
      'REJECTED',
    ],
    DomainEnumType.docApprovalStatus: [
      'DRAFT',
      'PENDING_REVIEW',
      'UNDER_REVIEW',
      'RECTIFICATION_REQUIRED',
      'CONDITIONALLY_APPROVED',
      'APPROVED_FOR_CLEARANCE',
      'REJECTED',
    ],
    DomainEnumType.ticketStatus: [
      'OPEN',
      'SENT_TO_SUPPLIER',
      'RESOLVED',
      'CLOSED',
      'WAIVED',
    ],
    DomainEnumType.ticketSeverity: [
      'MINOR',
      'MAJOR',
      'CRITICAL',
    ],
    DomainEnumType.allocationRule: [
      'EQUAL',
      'VALUE',
      'VOLUME',
      'WEIGHT',
    ],
    DomainEnumType.settlementStatus: [
      'DRAFT',
      'CALCULATED',
      'APPROVED',
      'CLOSED',
    ],
    DomainEnumType.actualCostBucket: [
      'CLEARANCE_PORT',
      'CUSTOMS_DUTY',
      'DEMURRAGE_STORAGE',
      'FREIGHT',
      'INLAND_TRANSPORT',
      'INSURANCE',
      'OTHER_ADMIN',
      'VAT_TAXES',
    ],
    DomainEnumType.dutyComponent: [
      'CUSTOMS_SERVICE_FEES',
      'DEVELOPMENT_FEE',
      'DUTY_TOTAL_OVERRIDE',
      'IMPORT_DUTY',
      'LAB_SERVICE_FEES',
      'SCHEDULE_TAX',
      'VAT',
      'WHT',
    ],
    DomainEnumType.warehouseReceivingStatus: [
      'PENDING_COUNT',
      'GOODS_RECEIVED',
      'INSPECTION_PASSED',
      'DISCREPANCY_REPORTED',
      'UNDER_QUARANTINE_INSPECTION',
      'UNDER_BOND_QUARANTINE',
      'GRN_AUDITED',
      'CLOSED',
    ],
    DomainEnumType.grnDiscrepancyType: [
      'BROKEN_SEAL',
      'DAMAGE',
      'EXCESS',
      'NONE',
      'QUARANTINE_REJECTION',
      'SHORTAGE',
      'SHORTAGE_AND_DAMAGE',
      'WRONG_ITEM',
    ],
    DomainEnumType.inlandTransportStatus: [
      'BOOKING_CONFIRMED',
      'DISPATCHED',
      'IN_TRANSIT',
      'ARRIVED_AT_WAREHOUSE',
      'DELIVERED',
    ],
    DomainEnumType.fileClosureStatus: [
      'DRAFT',
      'CLOSED',
      'ARCHIVED',
      'REOPENED',
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
      'Per Day (لكل يوم)': 'PER_DAY',
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
    DomainEnumType.shippingMethod: {
      'Air Freight (شحن جوي)': 'AIR',
      'FCL Container (حاوية كاملة بحرية)': 'FCL',
      'LCL Ocean Freight (شحن بحري تجميعي)': 'LCL',
    },
    DomainEnumType.poStatus: {
      'Canceled': 'CANCELLED',
      'In Transit': 'PARTIALLY_SHIPPED',
      'مسودة': 'DRAFT',
      'معتمد': 'APPROVED',
      'مغلق': 'CLOSED',
      'ملغي': 'CANCELLED',
    },
    DomainEnumType.shipmentMode: {},
    DomainEnumType.containerType: {
      "40FT High Cube Containers (40' HC)": 'C40_HC',
      'LCL Consolidation': 'LCL',
    },
    DomainEnumType.measureUnit: {
      'GRAM': 'GRM',
      'KGM': 'KG',
      'KGS': 'KG',
      'KILOGRAM': 'KG',
      'TON': 'STN',
      'TONS': 'STN',
      'طرد': 'PACKAGES',
      'طرد/بالتة': 'PACKAGES_PALLETS',
      'كجم': 'KG',
      'م³': 'CBM',
    },
    DomainEnumType.paymentType: {
      'Advance': 'ADVANCE_PAYMENT',
      'Against BL': 'AGAINST_BL',
      'CAD': 'DOCUMENTARY_COLLECTION',
      'Documentary Collection': 'DOCUMENTARY_COLLECTION',
      'L/C': 'LETTER_OF_CREDIT',
      'LC': 'LETTER_OF_CREDIT',
      'Letter of Credit': 'LETTER_OF_CREDIT',
    },
    DomainEnumType.paymentTerm: {
      'Cash Against Documents (تحصيل مستندي)': 'CAD',
      'Cash in Advance (دفعة مقدمة / سويفت)': 'ADVANCE_PAYMENT',
      'Letter of Credit (اعتماد مستندي)': 'LC',
      'Open Account (حساب مفتوح / دفع آجل)': 'OPEN_ACCOUNT',
      'SWIFT': 'ADVANCE_PAYMENT',
    },
    DomainEnumType.legalDocKind: {
      'البطاقة الاستيرادية (Import Card)': 'IMPORT_CARD',
      'البطاقة الضريبية / ملف القيمة المضافة (Tax Card)': 'TAX_CARD',
      'السجل التجاري (Commercial Registry)': 'COMMERCIAL_REGISTRY',
    },
    DomainEnumType.labTestResult: {
      'Approved': 'CONFORMING',
      'Non Conforming': 'NON_CONFORMING',
      'Nonconforming': 'NON_CONFORMING',
      'Rejected': 'NON_CONFORMING',
      'غير مطابق': 'NON_CONFORMING',
      'مرفوض': 'NON_CONFORMING',
      'مطابق': 'CONFORMING',
      'مقبول': 'CONFORMING',
    },
    DomainEnumType.odcStatus: {},
    DomainEnumType.originalDocStatus: {},
    DomainEnumType.originalDocRequired: {},
    DomainEnumType.courierStatus: {},
    DomainEnumType.docReviewStatus: {},
    DomainEnumType.docApprovalStatus: {},
    DomainEnumType.ticketStatus: {},
    DomainEnumType.ticketSeverity: {},
    DomainEnumType.allocationRule: {
      'Value Based': 'VALUE',
      'Volume Based': 'VOLUME',
      'Weight Based': 'WEIGHT',
    },
    DomainEnumType.settlementStatus: {},
    DomainEnumType.actualCostBucket: {},
    DomainEnumType.dutyComponent: {
      'actual_duty_total': 'DUTY_TOTAL_OVERRIDE',
      'customs_service_fees': 'CUSTOMS_SERVICE_FEES',
      'development_fee_amount': 'DEVELOPMENT_FEE',
      'import_duty_amount': 'IMPORT_DUTY',
      'lab_service_fees': 'LAB_SERVICE_FEES',
      'schedule_tax_amount': 'SCHEDULE_TAX',
      'vat_amount': 'VAT',
      'wht_amount': 'WHT',
    },
    DomainEnumType.warehouseReceivingStatus: {
      'Draft / Pending Warehouse Count': 'PENDING_COUNT',
      'Inspection Passed / Clean Receipt': 'INSPECTION_PASSED',
    },
    DomainEnumType.grnDiscrepancyType: {
      'Damage & Shortage': 'SHORTAGE_AND_DAMAGE',
      'Damage Only': 'DAMAGE',
      'Shortage Only': 'SHORTAGE',
      'Shortage and Damage': 'SHORTAGE_AND_DAMAGE',
    },
    DomainEnumType.inlandTransportStatus: {
      'BOOKED': 'BOOKING_CONFIRMED',
      'ARRIVED': 'ARRIVED_AT_WAREHOUSE',
      'In Transit (Gate-Out)': 'IN_TRANSIT',
      'Arrived Warehouse': 'ARRIVED_AT_WAREHOUSE',
      'Booking Confirmed': 'BOOKING_CONFIRMED',
      'Dispatched': 'DISPATCHED',
      'In Transit': 'IN_TRANSIT',
      'Arrived at Warehouse': 'ARRIVED_AT_WAREHOUSE',
      'Delivered': 'DELIVERED',
      'Cancelled': 'CANCELLED',
    },
    DomainEnumType.fileClosureStatus: {},
  };

  /// Labels of the review-wave types as [English, Arabic]. They are not in the
  /// `_domainEnumLabels` maps of the localization files yet; [label],
  /// [labelIfKnown] and [englishLabel] fall back to this table, so a label added
  /// to the localization files later wins.
  static const Map<String, List<String>> _supplementalLabels = {
    'inland_transport_status.BOOKING_CONFIRMED': ['Booking Confirmed', 'تم تأكيد الحجز'],
    'inland_transport_status.DISPATCHED': ['Dispatched', 'تم الإرسال'],
    'inland_transport_status.IN_TRANSIT': ['In Transit', 'في الطريق'],
    'inland_transport_status.ARRIVED_AT_WAREHOUSE': ['Arrived at Warehouse', 'وصل إلى المخزن'],
    'inland_transport_status.DELIVERED': ['Delivered', 'تم التسليم'],
    'inland_transport_status.CANCELLED': ['Cancelled', 'ملغي'],
    'payment_type.ADVANCE_PAYMENT': ['Advance Payment', 'دفعة مقدمة'],
    'payment_type.AGAINST_BL': ['Against B/L', 'مقابل بوليصة الشحن'],
    'payment_type.DOCUMENTARY_COLLECTION': ['Documentary Collection (CAD)', 'تحصيل مستندي (CAD)'],
    'payment_type.FINAL_SETTLEMENT': ['Final Settlement', 'تسوية نهائية'],
    'payment_type.LETTER_OF_CREDIT': ['Letter of Credit (L/C)', 'اعتماد مستندي (L/C)'],
    'payment_term.ADVANCE_PAYMENT': ['Cash in Advance / SWIFT', 'دفعة مقدمة / سويفت'],
    'payment_term.LC': ['Letter of Credit / LC', 'اعتماد مستندي'],
    'payment_term.CAD': ['CAD / Cash Against Documents', 'تحصيل مستندي'],
    'payment_term.OPEN_ACCOUNT': ['Open Account / Deferred Payment', 'حساب مفتوح / دفع آجل'],
    'legal_doc_kind.ACID': ['ACID', 'رقم ACID'],
    'legal_doc_kind.COMMERCIAL_REGISTRY': ['Commercial Registry', 'السجل التجاري'],
    'legal_doc_kind.IMPORT_CARD': ['Import Card', 'البطاقة الاستيرادية'],
    'legal_doc_kind.TAX_CARD': ['Tax Card', 'البطاقة الضريبية'],
    'lab_test_result.CONFORMING': ['Conforming', 'مطابق'],
    'lab_test_result.NONE': ['None', 'لا يوجد'],
    'lab_test_result.NON_CONFORMING': ['Non-Conforming', 'غير مطابق'],
    'lab_test_result.PENDING': ['Pending', 'قيد الانتظار'],
    'odc_status.DRAFT': ['Draft', 'مسودة'],
    'odc_status.IN_TRANSIT': ['In Transit', 'في الطريق'],
    'odc_status.PARTIALLY_RECEIVED': ['Partially Received', 'تم الاستلام جزئياً'],
    'odc_status.FULLY_RECEIVED': ['Fully Received', 'تم الاستلام بالكامل'],
    'odc_status.FULLY_VERIFIED': ['Fully Verified', 'تم التحقق بالكامل'],
    'odc_status.DISCREPANCY_NOTED': ['Discrepancy Noted', 'تم رصد فروقات'],
    'original_doc_status.PENDING': ['Pending', 'قيد الانتظار'],
    'original_doc_status.IN_TRANSIT': ['In Transit', 'في الطريق'],
    'original_doc_status.RECEIVED': ['Received', 'تم الاستلام'],
    'original_doc_status.VERIFIED': ['Verified', 'تم التحقق'],
    'original_doc_status.DISCREPANT': ['Discrepant', 'به فروقات'],
    'original_doc_status.NOT_REQUIRED': ['Not Required', 'غير مطلوب'],
    'original_doc_required.YES': ['Yes', 'نعم'],
    'original_doc_required.NO': ['No', 'لا'],
    'original_doc_required.CONDITIONAL': ['Conditional', 'حسب الحالة'],
    'courier_status.DISPATCHED': ['Dispatched', 'تم الإرسال'],
    'courier_status.IN_TRANSIT': ['In Transit', 'في الطريق'],
    'courier_status.DELIVERED': ['Delivered', 'تم التسليم'],
    'courier_status.DELAYED': ['Delayed', 'متأخر'],
    'doc_review_status.PENDING': ['Pending', 'قيد الانتظار'],
    'doc_review_status.UNDER_REVIEW': ['Under Review', 'قيد المراجعة'],
    'doc_review_status.APPROVED': ['Approved', 'معتمد'],
    'doc_review_status.CONDITIONALLY_APPROVED': ['Conditionally Approved', 'معتمد بشروط'],
    'doc_review_status.REJECTED': ['Rejected', 'مرفوض'],
    'doc_approval_status.DRAFT': ['Draft', 'مسودة'],
    'doc_approval_status.PENDING_REVIEW': ['Pending Review', 'بانتظار المراجعة'],
    'doc_approval_status.UNDER_REVIEW': ['Under Review', 'قيد المراجعة'],
    'doc_approval_status.RECTIFICATION_REQUIRED': ['Rectification Required', 'يتطلب تصحيحاً'],
    'doc_approval_status.CONDITIONALLY_APPROVED': ['Conditionally Approved', 'معتمد بشروط'],
    'doc_approval_status.APPROVED_FOR_CLEARANCE': ['Approved for Clearance', 'معتمد للتخليص'],
    'doc_approval_status.REJECTED': ['Rejected', 'مرفوض'],
    'ticket_status.OPEN': ['Open', 'مفتوحة'],
    'ticket_status.SENT_TO_SUPPLIER': ['Sent to Supplier', 'أُرسلت إلى المورد'],
    'ticket_status.RESOLVED': ['Resolved', 'تم الحل'],
    'ticket_status.CLOSED': ['Closed', 'مغلقة'],
    'ticket_status.WAIVED': ['Waived', 'تم التنازل'],
    'ticket_severity.MINOR': ['Minor', 'بسيطة'],
    'ticket_severity.MAJOR': ['Major', 'كبيرة'],
    'ticket_severity.CRITICAL': ['Critical', 'حرجة'],
    'allocation_rule.EQUAL': ['Equal', 'بالتساوي'],
    'allocation_rule.VALUE': ['Value-Based', 'حسب القيمة'],
    'allocation_rule.VOLUME': ['Volume-Based', 'حسب الحجم'],
    'allocation_rule.WEIGHT': ['Weight-Based', 'حسب الوزن'],
    'settlement_status.DRAFT': ['Draft', 'مسودة'],
    'settlement_status.CALCULATED': ['Calculated', 'تم الاحتساب'],
    'settlement_status.APPROVED': ['Approved', 'معتمدة'],
    'settlement_status.CLOSED': ['Closed', 'مغلقة'],
    'actual_cost_bucket.CLEARANCE_PORT': ['Clearance & Port', 'التخليص والميناء'],
    'actual_cost_bucket.CUSTOMS_DUTY': ['Customs Duty', 'الرسوم الجمركية'],
    'actual_cost_bucket.DEMURRAGE_STORAGE': ['Demurrage & Storage', 'غرامات التأخير والتخزين'],
    'actual_cost_bucket.FREIGHT': ['Freight', 'النولون'],
    'actual_cost_bucket.INLAND_TRANSPORT': ['Inland Transport', 'النقل الداخلي'],
    'actual_cost_bucket.INSURANCE': ['Insurance', 'التأمين'],
    'actual_cost_bucket.OTHER_ADMIN': ['Other & Admin', 'أخرى ومصروفات إدارية'],
    'actual_cost_bucket.VAT_TAXES': ['VAT & Taxes', 'القيمة المضافة والضرائب'],
    'duty_component.CUSTOMS_SERVICE_FEES': ['Customs Service Fees', 'رسوم الخدمات الجمركية'],
    'duty_component.DEVELOPMENT_FEE': ['Development Fee', 'رسم التنمية'],
    'duty_component.DUTY_TOTAL_OVERRIDE': ['Assessed Duty Total (override)', 'إجمالي الرسوم المقدرة (تعديل يدوي)'],
    'duty_component.IMPORT_DUTY': ['Import Duty', 'رسوم الاستيراد'],
    'duty_component.LAB_SERVICE_FEES': ['Laboratory Service Fees', 'رسوم خدمات المعامل'],
    'duty_component.SCHEDULE_TAX': ['Schedule Tax', 'ضريبة الجدول'],
    'duty_component.VAT': ['VAT', 'ضريبة القيمة المضافة'],
    'duty_component.WHT': ['Withholding Tax', 'ضريبة الخصم من المنبع'],
    'warehouse_receiving_status.PENDING_COUNT': ['Pending Warehouse Count', 'بانتظار الجرد المخزني'],
    'warehouse_receiving_status.GOODS_RECEIVED': ['Goods Received', 'تم استلام البضاعة'],
    'warehouse_receiving_status.INSPECTION_PASSED': ['Inspection Passed', 'اجتاز الفحص'],
    'warehouse_receiving_status.DISCREPANCY_REPORTED': ['Discrepancy Reported', 'تم الإبلاغ عن فروقات'],
    'warehouse_receiving_status.UNDER_QUARANTINE_INSPECTION': ['Under Quarantine Inspection', 'قيد فحص الحجر'],
    'warehouse_receiving_status.UNDER_BOND_QUARANTINE': ['Under Bond Quarantine', 'حجر تحت الضمان'],
    'warehouse_receiving_status.GRN_AUDITED': ['GRN Audited', 'تمت مراجعة إذن الإضافة'],
    'warehouse_receiving_status.CLOSED': ['Closed', 'مغلق'],
    'grn_discrepancy_type.BROKEN_SEAL': ['Broken Seal Discrepancy', 'فرق كسر الختم'],
    'grn_discrepancy_type.DAMAGE': ['Damage', 'تلف'],
    'grn_discrepancy_type.EXCESS': ['Excess', 'زيادة'],
    'grn_discrepancy_type.NONE': ['None', 'لا يوجد'],
    'grn_discrepancy_type.QUARANTINE_REJECTION': ['Quarantine Rejection', 'رفض الحجر'],
    'grn_discrepancy_type.SHORTAGE': ['Shortage', 'عجز'],
    'grn_discrepancy_type.SHORTAGE_AND_DAMAGE': ['Shortage & Damaged', 'عجز وتلف'],
    'grn_discrepancy_type.WRONG_ITEM': ['Wrong Item', 'صنف خاطئ'],
    'file_closure_status.DRAFT': ['Draft', 'مسودة'],
    'file_closure_status.CLOSED': ['Closed', 'مغلق'],
    'file_closure_status.ARCHIVED': ['Archived', 'مؤرشف'],
    'file_closure_status.REOPENED': ['Reopened', 'أعيد فتحه'],
  };

  /// Supplemental (review-wave) label of `type.code`, or `null`. Used as the
  /// fallback of `AppLocalizations.domainEnumLabel` in both languages.
  static String? supplementalLabel(String type, String code, {required bool arabic}) {
    final pair = _supplementalLabels['$type.$code'];
    return pair == null ? null : pair[arabic ? 1 : 0];
  }

  // `domainEnumLabel` already falls back to [supplementalLabel].
  static String? _labelOf(AppLocalizations l10n, String type, String code) =>
      l10n.domainEnumLabel(type, code);

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
      final text = _labelOf(l10n, type, resolved);
      if (text != null) return text;
    }
    final raw = value?.trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  /// The localized label when [value] is a known code or legacy label, else null
  /// (lets callers keep their own fallback for other vocabularies).
  static String? labelIfKnown(AppLocalizations l10n, String type, String? value) {
    final code = legacyToCode(type, value);
    return code == null ? null : _labelOf(l10n, type, code);
  }

  /// The English label of [code]; used where the backend needs a readable
  /// English text next to the code (e.g. `hold_reason`).
  static String englishLabel(String type, String code) =>
      _labelOf(const AppLocalizationsEn(), type, code) ?? code;

  /// The code to preselect in a dropdown for a stored value, or [fallback]
  /// when the value is empty or not a known code/legacy label.
  static String initialCode(String type, String? value, String fallback) =>
      legacyToCode(type, value) ?? fallback;
}
