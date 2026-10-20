import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_assistant_provider.dart';
import 'workspace_tabs_provider.dart';
import '../../features/audit_logs/providers/audit_logs_provider.dart';

import '../../features/cargo_insurance/providers/cargo_insurance_provider.dart';
import '../../features/cargo_shipping/providers/cargo_shipping_provider.dart';
import '../../features/cbm_calculator/providers/cbm_calculator_provider.dart';
import '../../features/currencies/providers/currencies_provider.dart';
import '../../features/customs_clearance/providers/customs_clearance_provider.dart';
import '../../features/customs_consultation/providers/customs_consultation_provider.dart';
import '../../features/customs_tariff/providers/customs_tariff_provider.dart';
import '../../features/demurrage_detention/providers/demurrage_provider.dart';
import '../../features/external_service_providers/providers/partners_provider.dart';
import '../../features/file_closure/providers/file_closure_provider.dart';
import '../../features/financial_approval/providers/financial_approval_provider.dart';
import '../../features/financial_settlement/providers/financial_settlement_provider.dart';
import '../../features/freight_booking/providers/freight_booking_provider.dart';
import '../../features/freight_quotations/providers/freight_quotations_provider.dart';
import '../../features/import_companies/providers/import_companies_provider.dart';
import '../../features/import_documentation/providers/import_documentation_provider.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../../features/import_requirements/providers/import_requirements_provider.dart';
import '../../features/incoterms/providers/incoterms_provider.dart';
import '../../features/projects/providers/projects_provider.dart';
import '../../features/purchase_orders/providers/purchase_orders_provider.dart';
import '../../features/shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../features/smart_tasks/providers/smart_tasks_provider.dart';
import '../../features/suppliers/providers/suppliers_provider.dart';
import '../../features/transport_locations/providers/transport_locations_provider.dart';
import '../../features/warehouse_receiving/providers/warehouse_receiving_provider.dart';
import '../../features/warehouse_receiving/providers/goods_in_transit_provider.dart';
import '../../features/lifecycle_board/providers/step_config_provider.dart';
import '../../features/logistics_invoices/providers/logistics_invoices_provider.dart';
import '../../features/vessel_tracking/providers/vessel_tracking_provider.dart';

// ============================================================
// Navigation Index Provider
// ============================================================

// Screen indices (strictly matching home_screen.dart _screens list):
//  0  = OperationalDashboardScreen
//  1  = ImportFilesScreen
//  2  = PurchaseOrdersScreen
//  3  = CBMCalculatorScreen
//  4  = ShippingScenariosScreen (initialIndex: 0)
//  5  = ShippingScenariosScreen (initialIndex: 1)
//  6  = CustomsConsultationScreen (initialIndex: 0)
//  7  = CustomsConsultationScreen (initialIndex: 1)
//  8  = FinancialApprovalScreen (initialIndex: 0)
//  9  = FinancialApprovalScreen (initialIndex: 1)
//  10 = FinancialApprovalScreen (initialIndex: 2)
//  11..15 = NafezaAcidScreen (0..4)
//  16..17 = BankForm4Screen (0..1)
//  18..22 = ShipmentDraftDocsScreen (0..4)
//  23..24 = CustomsDeclaration46Screen (0..1)
//  25 = FreightBookingScreen
//  26 = CargoShippingScreen
//  27 = CustomsClearanceScreen
//  28 = WarehouseReceivingScreen
//  29 = FinancialSettlementScreen
//  30 = FileClosureScreen
//  31 = ProjectsScreen
//  32 = ImportCompaniesScreen
//  33 = SuppliersScreen
//  34 = PartnersScreen (external_service_providers)
//  35 = IncotermsScreen
//  36 = CustomsTariffScreen
//  37 = TransportLocationsScreen
//  38 = CurrenciesScreen
//  39 = AuditLogsScreen
//  40 = SmartTasksScreen
//  41 = DynamicReportBuilderScreen
//  42 = ShipmentUpdateEngineScreen
//  43 = ImportRequirementsScreen
//  44 = DemurrageDetentionScreen
//  45 = HsCodeSearchScreen
//  46 = SwiftReconciliationScreen
//  47 = ImportFileComprehensiveReportScreen
//  48 = LifecycleBoardScreen
//  49 = FreightQuotationsComparisonScreen
//  50 = LandedCostComparisonScreen
//  51 = CentralDocsArchiveScreen
//  52 = CargoShippingScreen (tracking subtab)
//  53 = ShipmentDraftDocsScreen (inspection subtab 5)
//  54 = OriginalDocsAndCargoXScreen (subTab 1 = CargoX)
//  55 = CustomsConsultationScreen (quotes subtab 3)
//  56 = CustomsConsultationScreen (tax review mode)
//  57 = OriginalDocsAndCargoXScreen (subTab 0 = Original Docs)
//  58 = OriginalDocsAndCargoXScreen (default)
//  59 = ProductionSyncScreen
//  60 = CustomsClearanceScreen (subTab 1 — Drawing Samples)
//  61 = CustomsClearanceScreen (subTab 2 — Discrepancy/Damage)
//  62 = CustomsClearanceScreen (subTab 3 — Final Customs Payment)
//  63 = GoodsInTransitScreen
//  64 = WarehouseReceivedReportScreen
//  65 = CargoInsuranceScreen
//  66 = UsersManagementScreen
//  67 = StepConfigManagementScreen (Addendum: Section 10)
//  70 = LogisticsInvoicesScreen
//  71 = VesselTrackingRadarScreen
// ============================================================

const int _totalScreens = 72; // indices 0–71


final navigationIndexProvider = StateProvider<int>((ref) => 0);
final selectedComprehensiveReportFileIdProvider = StateProvider<int?>((ref) => null);

class _ScreenTabInfo {
  final String title;
  final IconData icon;
  const _ScreenTabInfo(this.title, this.icon);
}

_ScreenTabInfo _getScreenTabInfo(int index) {
  switch (index) {
    case 0: return const _ScreenTabInfo('لوحة التحكم', Icons.dashboard_customize_outlined);
    case 1: return const _ScreenTabInfo('ملفات الشحنات', Icons.folder_special_outlined);
    case 2: return const _ScreenTabInfo('أوامر الشراء', Icons.shopping_cart_outlined);
    case 3: return const _ScreenTabInfo('حاسبة الحجم CBM', Icons.calculate_outlined);
    case 4:
    case 5: return const _ScreenTabInfo('دراسات النولون والجدول الزمني', Icons.analytics_outlined);
    case 49: return const _ScreenTabInfo('طلب ومقارنة عروض النولون', Icons.request_quote_outlined);
    case 6:
    case 7:
    case 55:
    case 56: return const _ScreenTabInfo('الدراسات الجمركية وعروض التخليص', Icons.gavel_outlined);
    case 8:
    case 9:
    case 10: return const _ScreenTabInfo('الموافقات المالية', Icons.monetization_on_outlined);
    case 11:
    case 12:
    case 13:
    case 14:
    case 15: return const _ScreenTabInfo('منظومة نافذة ACID', Icons.cloud_done_outlined);
    case 16:
    case 17: return const _ScreenTabInfo('نموذج 4 البنكي', Icons.account_balance_outlined);
    case 21: return const _ScreenTabInfo('مطابقة الفاتورة وقائمة التعبئة', Icons.fact_check_outlined);
    case 18: return const _ScreenTabInfo('مسودة بوليصة الشحن (B/L)', Icons.assignment_turned_in_outlined);
    case 22: return const _ScreenTabInfo('المطابقة الذكية بين الفاتورة والبوليصة', Icons.auto_awesome);
    case 19: return const _ScreenTabInfo('مسودة شهادة المنشأ و EUR.1', Icons.flag_circle_outlined);
    case 53: return const _ScreenTabInfo('شهادات الفحص والمطابقة (COC)', Icons.security_outlined);
    case 20: return const _ScreenTabInfo('مركز اعتماد المستندات وتعديلات المورد', Icons.verified_user_outlined);
    case 23:
    case 24: return const _ScreenTabInfo('شهادة الإجراء 46', Icons.verified_outlined);
    case 25: return const _ScreenTabInfo('حجز الشحن الملاحي', Icons.directions_boat_outlined);
    case 26:
    case 52: return const _ScreenTabInfo('حركة وتتبع الشحن', Icons.directions_boat_outlined);
    case 27:
    case 60:
    case 61:
    case 62: return const _ScreenTabInfo('التخليص الجمركي والكشف', Icons.fact_check_outlined);
    case 28:
    case 63:
    case 64: return const _ScreenTabInfo('مركز المخازن والاستلام', Icons.warehouse_outlined);
    case 29:
    case 50: return const _ScreenTabInfo('التسوية وتكلفة الوصول', Icons.price_check_outlined);
    case 30: return const _ScreenTabInfo('إغلاق الملف الاستيرادي', Icons.task_alt_outlined);
    case 31: return const _ScreenTabInfo('المشاريع', Icons.business_outlined);
    case 32: return const _ScreenTabInfo('الشركات المستوردة', Icons.domain_outlined);
    case 33: return const _ScreenTabInfo('الموردون الأجانب', Icons.apartment_outlined);
    case 34: return const _ScreenTabInfo('الشركاء والبنوك', Icons.handshake_outlined);
    case 35: return const _ScreenTabInfo('الشروط التجارية الدولية', Icons.handshake_outlined);
    case 36:
    case 45: return const _ScreenTabInfo('جدول ومستكشف التعريفة', Icons.description_outlined);
    case 37: return const _ScreenTabInfo('الموانئ والمنافذ الجمركية', Icons.location_on_outlined);
    case 38: return const _ScreenTabInfo('العملات وأسعار الصرف', Icons.currency_exchange_outlined);
    case 39: return const _ScreenTabInfo('سجل التدقيق والرقابة', Icons.history_edu_outlined);
    case 40: return const _ScreenTabInfo('المهام الذكية', Icons.checklist_outlined);
    case 41: return const _ScreenTabInfo('منشئ التقارير', Icons.bar_chart_outlined);
    case 42: return const _ScreenTabInfo('محرك التحديث السريع', Icons.published_with_changes_outlined);
    case 43: return const _ScreenTabInfo('اشتراطات الاستيراد', Icons.verified_outlined);
    case 44: return const _ScreenTabInfo('رادار الغرامات والأرضيات', Icons.timer_outlined);
    case 46: return const _ScreenTabInfo('مطابقة سويفت والتحويلات', Icons.sync_alt_rounded);
    case 47: return const _ScreenTabInfo('تقرير الشحنة الشامل', Icons.summarize_outlined);
    case 48: return const _ScreenTabInfo('مخطط دورة الحياة', Icons.view_kanban_outlined);
    case 51: return const _ScreenTabInfo('الأرشيف المركزي للمستندات', Icons.inventory_2_outlined);
    case 54:
    case 57:
    case 58: return const _ScreenTabInfo('منظومة CargoX وأصول المستندات', Icons.cloud_upload_outlined);
    case 59: return const _ScreenTabInfo('Production Sync', Icons.sync_alt_rounded);
    case 65: return const _ScreenTabInfo('تأمين الشحن البحري', Icons.shield_outlined);
    case 66: return const _ScreenTabInfo('إدارة المستخدمين', Icons.manage_accounts_rounded);
    case 67: return const _ScreenTabInfo('إعدادات تصنيف المراحل', Icons.admin_panel_settings_rounded);
    case 70: return const _ScreenTabInfo('فواتير ومدفوعات الخدمات اللوجستية', Icons.receipt_long_outlined);
    case 71: return const _ScreenTabInfo('رادار تتبع السفن', Icons.radar_outlined);
    default: return _ScreenTabInfo('شاشة $index', Icons.tab_outlined);
  }
}

void selectNavigationIndex(WidgetRef ref, int index, {String? tabTitle, IconData? tabIcon}) {
  if (index < 0 || index >= _totalScreens) return;

  // 1. Update navigation state
  ref.read(navigationIndexProvider.notifier).state = index;

  // 2. Open / switch workspace tab
  final tabInfo = _getScreenTabInfo(index);
  ref.read(workspaceTabsProvider.notifier).openTab(
    id: 'tab_$index',
    title: tabTitle ?? tabInfo.title,
    icon: tabIcon ?? tabInfo.icon,
    routeIndex: index,
  );

  // 3. Live-refresh the target screen's data from the server
  _liveRefreshScreenData(ref, index);

  // 4. Update AI assistant screen context
  ref.read(aiAssistantProvider.notifier).updateScreenContext(tabTitle ?? tabInfo.title);
}


void _liveRefreshScreenData(WidgetRef ref, int index) {
  switch (index) {
    // --- Core Operations & Sourcing ---
    case 1:
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      break;
    case 2:
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      break;
    case 3:
      ref.read(cbmCalculatorProvider.notifier).fetchCalculations();
      break;
    case 4:
    case 5:
      ref.read(shippingScenariosProvider.notifier).fetchSessions();
      break;
    case 6:
    case 7:
    case 55:
    case 56:
      ref.read(customsConsultationsProvider.notifier).fetchConsultations();
      ref.read(customsTariffProvider.notifier).fetchTariffs();
      break;

    // --- Financial Approvals ---
    case 8:
    case 9:
    case 10:
    case 46:
      ref.read(importBudgetsProvider.notifier).fetchImportBudgets();
      ref.read(paymentRequestsProvider.notifier).fetchPaymentRequests();
      break;

    // --- Import Documentation, ACID & Banking ---
    case 11:
    case 12:
    case 13:
    case 14:
    case 15:
    case 16:
    case 17:
    case 18:
    case 19:
    case 20:
    case 21:
    case 22:
    case 23:
    case 24:
    case 51:
    case 53:
    case 54:
    case 57:
    case 58:
      ref.read(acidSessionsProvider.notifier).fetchAcidSessions();
      ref.read(draftBLReviewsProvider.notifier).fetchReviews();
      ref.read(cooReviewsProvider.notifier).fetchReviews();
      ref.read(inspectionReviewsProvider.notifier).fetchReviews();
      break;

    // --- Operational Phases ---
    case 25:
      ref.read(freightBookingProvider.notifier).fetchBookings();
      break;
    case 26:
      ref.read(cargoShippingProvider.notifier).fetchRecords();
      break;
    case 27:
      ref.read(customsClearanceProvider.notifier).fetchRecords();
      break;
    case 28:
    case 63:
    case 64:
      ref.read(warehouseReceivingProvider.notifier).fetchRecords();
      ref.read(goodsInTransitProvider.notifier).initLedger();
      break;
    case 29:
    case 50:
      ref.read(financialSettlementProvider.notifier).fetchSettlements();
      break;
    case 30:
      ref.read(fileClosureProvider.notifier).fetchClosures();
      break;

    // --- Master Data ---
    case 31:
      ref.read(projectsProvider.notifier).fetchProjects();
      break;
    case 32:
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
      break;
    case 33:
      ref.read(suppliersProvider.notifier).fetchSuppliers();
      break;
    case 34:
      ref.read(partnersProvider.notifier).fetchPartners();
      break;
    case 35:
      ref.read(incotermsProvider.notifier).fetchIncoterms();
      break;
    case 36:
    case 45:
      ref.read(customsTariffProvider.notifier).fetchTariffs();
      break;
    case 37:
      ref.read(transportLocationsProvider.notifier).fetchLocations();
      break;
    case 38:
      ref.read(currenciesProvider.notifier).fetchCurrencies();
      break;
    case 39:
      ref.invalidate(systemAuditLogsProvider);
      break;

    // --- Smart Engines & Reporting ---
    case 40:
      ref.read(smartTasksProvider.notifier).fetchTasks();
      break;
    case 43:
      ref.read(importRequirementsProvider.notifier).refreshData();
      break;
    case 44:
      ref.read(demurrageProvider.notifier).loadInitialData();
      break;
    case 47:
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      break;
    case 49:
      ref.read(freightQuotationsProvider.notifier).fetchRFQs();
      break;
    case 65:
      ref.read(cargoInsuranceProvider.notifier).fetchCertificates();
      break;
    case 67:
      ref.read(stepConfigProvider.notifier).fetchConfigs();
      break;
    case 70:
      ref.invalidate(logisticsInvoicesListProvider);
      ref.invalidate(paymentVouchersListProvider);
      ref.invalidate(clearanceAdvancesListProvider);
      ref.invalidate(insurancePoliciesListProvider);
      break;
    case 71:
      ref.read(vesselTrackingRadarProvider.notifier).fetchRadarOverview();
      break;

    default:
      break;
  }
}

