import 'package:flutter/material.dart';

import '../../audit_logs/screens/audit_logs_screen.dart';
import '../../cargo_insurance/screens/cargo_insurance_screen.dart';
import '../../cargo_shipping/screens/cargo_shipping_screen.dart';
import '../../cbm_calculator/screens/cbm_calculator_screen.dart';
import '../../comprehensive_report/screens/import_file_comprehensive_report_screen.dart';
import '../../currencies/screens/currencies_screen.dart';
import '../../customs_clearance/screens/customs_clearance_screen.dart';
import '../../customs_consultation/screens/customs_consultation_screen.dart';
import '../../customs_tariff/screens/customs_tariff_screen.dart';
import '../../custody_release/screens/custody_release_screen.dart';
import '../../demurrage_detention/screens/demurrage_detention_screen.dart';
import '../../dynamic_reporting/screens/dynamic_report_builder_screen.dart';
import '../../expense_catalog/screens/expense_catalog_screen.dart';
import '../../external_service_providers/screens/partners_screen.dart';
import '../../file_closure/screens/file_closure_screen.dart';
import '../../financial_approval/screens/financial_approval_screen.dart';
import '../../financial_approval/screens/swift_reconciliation_screen.dart';
import '../../financial_settlement/screens/financial_settlement_screen.dart';
import '../../formal_letters/screens/formal_letters_screen.dart';
import '../../freight_booking/screens/freight_booking_screen.dart';
import '../../freight_quotations/screens/freight_quotations_screen.dart';
import '../../import_companies/screens/import_companies_screen.dart';
import '../../import_documentation/screens/bank_form4_screen.dart';
import '../../import_documentation/screens/central_docs_archive_screen.dart';
import '../../import_documentation/screens/customs_declaration46_screen.dart';
import '../../import_documentation/screens/docs_customs_approval_screen.dart';
import '../../import_documentation/screens/draft_bl_review_screen.dart';
import '../../import_documentation/screens/draft_coo_review_screen.dart';
import '../../import_documentation/screens/draft_inspection_review_screen.dart';
import '../../import_documentation/screens/nafeza_acid_screen.dart';
import '../../import_documentation/screens/original_docs_and_cargox_screen.dart';
import '../../import_documentation/screens/po_packing_reconciliation_screen.dart';
import '../../import_documentation/screens/smart_invoice_bl_match_screen.dart';
import '../../import_files/screens/import_files_screen.dart';
import '../../import_requirements/screens/import_requirements_screen.dart';
import '../../incoterms/screens/incoterms_screen.dart';
import '../../lifecycle_board/screens/lifecycle_board_screen.dart';
import '../../lifecycle_board/screens/step_config_management_screen.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';
import '../../master_items/screens/item_price_trends_screen.dart';
import '../../master_items/screens/master_items_screen.dart';
import '../../operational_dashboard/screens/operational_dashboard_screen.dart';
import '../../production_sync/screens/production_sync_screen.dart';
import '../../projects/screens/projects_screen.dart';
import '../../purchase_orders/screens/purchase_orders_screen.dart';
import '../../shipment_inquiry/screens/shipment_inquiry_screen.dart';
import '../../shipment_updates/screens/shipment_update_engine_screen.dart';
import '../../shipping_scenarios/screens/shipping_scenarios_screen.dart';
import '../../smart_document_upload/screens/smart_document_upload_hub_screen.dart';
import '../../smart_tasks/screens/smart_tasks_screen.dart';
import '../../suppliers/screens/suppliers_screen.dart';
import '../../system_observability/screens/system_observability_screen.dart';
import '../../transport_locations/screens/transport_locations_screen.dart';
import '../../auth/screens/users_management_screen.dart';
import '../../vessel_tracking/screens/vessel_tracking_radar_screen.dart';
import '../../warehouse_receiving/screens/inbound_warehouse_hub_screen.dart';
import '../../regulatory_matrix/screens/regulatory_matrix_screen.dart';
import '../../trade_finance/screens/trade_finance_screen.dart';
import '../../container_tracking/container_tracking_board_screen.dart';
import '../../split_shipments/split_shipments_screen.dart';
import '../../multimodal_freight/multimodal_freight_screen.dart';
import '../../customs_regimes/customs_regimes_screen.dart';
import '../../trade_agreements/trade_agreements_screen.dart';
import '../../logistics_exceptions/logistics_exceptions_screen.dart';
import '../../deposits_recovery/deposits_recovery_screen.dart';
import '../../vendor_quality/vendor_quality_screen.dart';

const List<Widget> kHomeScreenRegistry = [
  // 0..3: Core Workspace (Phase 1)
  OperationalDashboardScreen(),
  ImportFilesScreen(),
  PurchaseOrdersScreen(),
  CBMCalculatorScreen(),

  // 4..5: Phase 1 Freight Studies, Timeline & Scenarios (Study & Saved Records)
  ShippingScenariosScreen(key: ValueKey('shipping_scenarios_tab0'), initialIndex: 0),
  ShippingScenariosScreen(key: ValueKey('shipping_scenarios_tab1'), initialIndex: 1),

  // 6..7: Phase 1 Customs Broker Consultation
  CustomsConsultationScreen(initialIndex: 0),
  CustomsConsultationScreen(initialIndex: 1),

  // 8..10: Phase 2 Financial Approvals
  FinancialApprovalScreen(initialIndex: 0),
  FinancialApprovalScreen(initialIndex: 1),
  FinancialApprovalScreen(initialIndex: 2),

  // 11..15: Phase 3 Nafeza & ACID Engine (Dedicated Screen with Vertical Tabs)
  NafezaAcidScreen(initialSubTab: 0),
  NafezaAcidScreen(initialSubTab: 1),
  NafezaAcidScreen(initialSubTab: 2),
  NafezaAcidScreen(initialSubTab: 3),
  NafezaAcidScreen(initialSubTab: 4),

  // 16..17: Bank Form 4 & Endorsement (Dedicated Screen with Vertical Tabs)
  BankForm4Screen(initialSubTab: 0),
  BankForm4Screen(initialSubTab: 1),

  // 18..22: Phase 3 Decomposed Draft Document Review Stages (Dedicated Full-Width Screens)
  DraftBLReviewScreen(key: ValueKey('draft_bl_review_screen')),
  DraftCOOReviewScreen(key: ValueKey('draft_coo_review_screen')),
  DocsCustomsApprovalScreen(key: ValueKey('docs_customs_approval_screen')),
  POPackingReconciliationScreen(key: ValueKey('po_packing_reconciliation_screen')),
  SmartInvoiceBLMatchScreen(key: ValueKey('smart_invoice_bl_match_screen')),

  // 23..24: Phase 6 Customs Declaration 46 (Dedicated Screen with Vertical Tabs)
  CustomsDeclaration46Screen(initialSubTab: 0),
  CustomsDeclaration46Screen(initialSubTab: 1),

  // 25..30: Execution Phases (Phases 4 -> 10)
  FreightBookingScreen(),
  CargoShippingScreen(key: ValueKey('cargo_shipping_allocations_0'), initialSubTab: 0),
  CustomsClearanceScreen(),
  InboundWarehouseHubScreen(key: ValueKey('inbound_hub_grn'), initialSubTab: 1),
  FinancialSettlementScreen(key: ValueKey('settlement_tab0'), initialSubTab: 0),
  FileClosureScreen(),

  // 31..34: Master Data
  ProjectsScreen(),
  ImportCompaniesScreen(),
  SuppliersScreen(),
  PartnersScreen(),

  // 35..39: Reference Master Tables & Audit
  IncotermsScreen(),
  CustomsTariffScreen(key: ValueKey('customs_tariff_tab0'), initialTabIndex: 0),
  TransportLocationsScreen(),
  CurrenciesScreen(),
  AuditLogsScreen(),

  // 40..47: Smart Engines & Reporting
  SmartTasksScreen(),
  DynamicReportBuilderScreen(),
  ShipmentUpdateEngineScreen(),
  ImportRequirementsScreen(),
  DemurrageDetentionScreen(),
  CustomsTariffScreen(key: ValueKey('customs_tariff_tab1'), initialTabIndex: 1),
  SwiftReconciliationScreen(),
  ImportFileComprehensiveReportScreen(),

  // 48: Native 6-Phase Lifecycle Operations Board
  LifecycleBoardScreen(),

  // 49: Freight Quotations Comparison & Fast Awarding (Operational Workspace)
  FreightQuotationsScreen(key: ValueKey('freight_quotations_operational')),

  // 50: Landed Cost Comparison (Integrated in Financial Settlement Hub)
  FinancialSettlementScreen(key: ValueKey('settlement_tab1'), initialSubTab: 1),

  // 51: Central Shipment Documents Archive & Discrepancies Summary Hub
  CentralDocsArchiveScreen(),

  // 52: Cargo Shipping Tracking (48h SLA Tracking Subtab)
  CargoShippingScreen(key: ValueKey('cargo_shipping_tracking_1'), initialSubTab: 1),

  // 53: Draft Inspection Certificate (Dedicated Full-Width Screen)
  DraftInspectionReviewScreen(key: ValueKey('draft_inspection_review_screen')),

  // 54: CargoX Blockchain & ACI Dispatch Hub → Phase 4 Standalone Screen (subTab 1)
  OriginalDocsAndCargoXScreen(key: ValueKey('original_docs_cargox_1'), initialSubTab: 1),

  // 55: Landed Cost Calculation Engine (Direct Access via Route Index 55)
  FinancialSettlementScreen(key: ValueKey('settlement_tab2_direct'), initialSubTab: 2),

  // 56: Shipping Scenarios Evaluator (Route Index 56)
  ShippingScenariosScreen(key: ValueKey('shipping_scenarios_tab2'), initialIndex: 2),

  // 57: Inbound Delivery & Warehouse Hub (Direct Access via Route Index 57)
  InboundWarehouseHubScreen(key: ValueKey('inbound_hub_direct'), initialSubTab: 0),

  // 58: Customs Clearance Direct Execution Hub (Route Index 58)
  CustomsClearanceScreen(key: ValueKey('customs_clearance_direct')),

  // 59: Production Database Synchronization Hub (Route Index 59)
  ProductionSyncScreen(key: ValueKey('production_sync_screen')),

  // 60: Dynamic Report Builder Direct View (Route Index 60)
  DynamicReportBuilderScreen(key: ValueKey('dynamic_report_builder_direct')),

  // 61: Freight Quotations Comparison (Route Index 61)
  FreightQuotationsScreen(key: ValueKey('freight_quotations_direct')),

  // 62: Swift Extraction & Bank Reconciliation Hub (Route Index 62)
  SwiftReconciliationScreen(key: ValueKey('swift_reconciliation_direct')),

  // 63: Import Requirements Compliance Matrix (Route Index 63)
  ImportRequirementsScreen(key: ValueKey('import_requirements_direct')),

  // 64: Demurrage & Detention Free Time Tracking (Route Index 64)
  DemurrageDetentionScreen(key: ValueKey('demurrage_detention_direct')),

  // 65: Cargo Insurance Policies & Declarations
  CargoInsuranceScreen(key: ValueKey('cargo_insurance_screen')),

  // 66: System Users Management & Role Based Access Control (RBAC)
  UsersManagementScreen(key: ValueKey('users_management_screen')),

  // 67: Step Skip-Risk Classification & Governance Settings Screen
  StepConfigManagementScreen(key: ValueKey('step_config_management_screen')),

  // 68: Unified Shipment History, Inquiry & Intelligent Multi-Dimension Search
  ShipmentInquiryScreen(key: ValueKey('shipment_inquiry_screen')),

  // 69: System Observability, Health Metrics & Telemetry Center
  SystemObservabilityScreen(key: ValueKey('system_observability_screen')),

  // 70: Logistics Service Invoices & Accounting Center
  LogisticsInvoicesScreen(key: ValueKey('logistics_invoices_screen')),

  // 71: Live Vessel & Port Traffic Radar Tracker
  VesselTrackingRadarScreen(key: ValueKey('vessel_tracking_radar_screen')),

  // 72: Standard Customs & Logistics Expense Catalog
  ExpenseCatalogScreen(key: ValueKey('expense_catalog_screen')),

  // 73: Formal Letters Drafting & Approvals
  FormalLettersScreen(key: ValueKey('formal_letters_screen')),

  // 74: Customs Custody Release
  CustodyReleaseScreen(key: ValueKey('custody_release_screen')),

  // 75: Smart Multi-File AI Document Upload Hub
  SmartDocumentUploadHubScreen(key: ValueKey('smart_document_upload_hub_screen')),

  // 76: Master Items Catalog
  MasterItemsScreen(key: ValueKey('master_items_screen')),

  // 77: Item Price Trends Radar
  ItemPriceTrendsScreen(key: ValueKey('item_price_trends_screen')),

  // 78: Regulatory Requirements Compliance Matrix (Wave 1)
  RegulatoryMatrixScreen(key: ValueKey('regulatory_matrix_screen')),

  // 79: Trade Finance & Letters of Credit Hub (Wave 1)
  TradeFinanceScreen(key: ValueKey('trade_finance_screen')),

  // 80: Container-Level Tracking & Demurrage Board (Wave 2)
  ContainerTrackingBoardScreen(key: ValueKey('container_tracking_board_screen')),

  // 81: Split Shipments & Partial B/L Allocation Hub (Wave 2)
  SplitShipmentsScreen(key: ValueKey('split_shipments_screen')),

  // 82: Multimodal Freight Operations (Air, LCL, Ro-Ro, Bulk) (Wave 2)
  MultimodalFreightScreen(key: ValueKey('multimodal_freight_screen')),

  // 83: Complete Customs Special Regimes (Drawback, Free Zones, Under-Bond) (Wave 3)
  CustomsRegimesScreen(key: ValueKey('customs_regimes_screen')),

  // 84: Preferential Trade Agreements & Origin Verification (Wave 3)
  TradeAgreementsScreen(key: ValueKey('trade_agreements_screen')),

  // 85: Logistics Exceptions, Roll-overs & Valuation Disputes (Wave 4)
  LogisticsExceptionsScreen(key: ValueKey('logistics_exceptions_screen')),

  // 86: Refundable Container Deposits & Bank Guarantee Recovery (Wave 4)
  DepositsRecoveryScreen(key: ValueKey('deposits_recovery_screen')),

  // 87: Pre-Shipment Inspection (PSI) & Vendor Quality Scorecards (Wave 4)
  VendorQualityScreen(key: ValueKey('vendor_quality_screen')),
];
