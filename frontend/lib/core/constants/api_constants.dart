import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String clientVersion = '2.0.3';
  static const int clientBuildNumber = 205;

  // ── Server & Base ─────────────────────────────────────────
  static String customServerUrl = '';

  static void setCustomServerUrl(String url) {
    customServerUrl = url.trim();
    if (customServerUrl.endsWith('/')) {
      customServerUrl = customServerUrl.substring(0, customServerUrl.length - 1);
    }
  }

  static String get serverUrl {
    if (customServerUrl.isNotEmpty) {
      return customServerUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return 'http://$host:28080';
    }
    return 'http://127.0.0.1:28080';
  }

  static String get baseUrl => '$serverUrl/api/v1';

  // ── Master Data ───────────────────────────────────────────
  static String get suppliers => '$baseUrl/suppliers';
  static String get importCompanies => '$baseUrl/import-companies';
  static String get partners => '$baseUrl/partners';  // external_service_providers
  static String get currencies => '$baseUrl/currencies';
  static String get incoterms => '$baseUrl/incoterms';
  static String get transportLocations => '$baseUrl/transport-locations';
  static String get projects => '$baseUrl/projects';
  static String get customsTariff => '$baseUrl/customs-tariff';
  static String get expenseCatalog => '$baseUrl/expense-catalog';

  // ── Import Operations ─────────────────────────────────────
  static String get importFiles => '$baseUrl/import-files';
  static String get purchaseOrders => '$baseUrl/purchase-orders';
  static String get importRequirements => '$baseUrl/import-requirements';

  // ── Freight & Shipping ────────────────────────────────────
  static String get shippingScenarios => '$baseUrl/shipping-scenarios';
  static String get freightQuotations => '$baseUrl/freight-quotations';
  static String get freightBooking => '$baseUrl/freight-booking';
  static String get cargoShipping => '$baseUrl/cargo-shipping';
  static String get cargoInsurance => '$baseUrl/cargo-insurance';
  static String get demurrageDetention => '$baseUrl/demurrage-detention';

  // ── Calculations & Tools ──────────────────────────────────
  static String get cbmCalculator => '$baseUrl/cbm-calculator';
  static String get containerLoader => '$baseUrl/container-loader';

  // ── Customs ───────────────────────────────────────────────
  static String get customs => '$baseUrl/customs';
  static String get customsConsultation => '$baseUrl/customs-consultation';
  static String get customsClearance => '$baseUrl/customs-clearance';

  // ── Finance ───────────────────────────────────────────────
  static String get financialApproval => '$baseUrl/financial-approval';
  static String get financialSettlement => '$baseUrl/financial-settlement';
  static String get recalculation => '$baseUrl/recalculation';

  // ── Documentation ─────────────────────────────────────────
  static String get importDocumentation => '$baseUrl/import-documentation';
  static String get warehouseReceiving => '$baseUrl/warehouse-receiving';
  static String get fileClosure => '$baseUrl/file-closure';

  // ── System & Integrations ─────────────────────────────────
  static String get auditLogs => '$baseUrl/audit-logs';
  static String get notifications => '$baseUrl/notifications';
  static String get smartTasks => '$baseUrl/smart-tasks';
  static String get smartEmail => '$baseUrl/smart-email';
  static String get shipmentUpdates => '$baseUrl/shipment-updates';
  static String get routeIntelligence => '$baseUrl/route-intelligence';
  static String get integrations => '$baseUrl/integrations';
  static String get experienceGuide => '$baseUrl/experience-guide';

  static String get lifecycleBoard => '$baseUrl/lifecycle-board';
  static String get smartDocumentUpload => '$baseUrl/smart-upload';
  static String get productionSync => '$baseUrl/production-sync';
  static String get simulation => '$baseUrl/simulation';

  // ── In-app updates (backend verifies, downloads and installs) ──
  static String get appUpdate => '$baseUrl/app-update';
  static String get appUpdateCheck => '$appUpdate/check';
  static String get appUpdateStatus => '$appUpdate/status';
  static String get appUpdateDownload => '$appUpdate/download';
  static String get appUpdateCancel => '$appUpdate/cancel';
  static String get appUpdateApply => '$appUpdate/apply';
  static String get appUpdateStageLocal => '$appUpdate/stage-local';
  static String get appUpdateRollback => '$appUpdate/rollback';
  static String get appUpdateLastResult => '$appUpdate/last-result';
  static String get appUpdateHistory => '$appUpdate/history';


  // ── Auth ──────────────────────────────────────────────────
  static String get auth => '$baseUrl/auth';
  static String get login => '$auth/token';
  static String get currentUser => '$auth/me';
  static String get users => '$auth/users';
}
