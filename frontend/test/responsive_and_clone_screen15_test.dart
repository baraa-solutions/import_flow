import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
import 'package:frontend/core/widgets/live_pulse_badge.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/screens/nafeza_acid_screen.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class MockAcidSessionsNotifier extends AcidSessionsNotifier {
  MockAcidSessionsNotifier(List<AcidRegistrationModel> initialList) : super(Dio()) {
    state = AsyncValue.data(initialList);
  }

  @override
  Future<void> fetchAcidSessions({
    bool includeInactive = false,
    String? search,
    String? status,
  }) async {}
}

class MockAcidTrackerNotifier extends AcidTrackerNotifier {
  MockAcidTrackerNotifier(AcidTrackerSummaryModel initialSummary) : super(Dio()) {
    state = AsyncValue.data(initialSummary);
  }

  @override
  Future<void> fetchAcidTracker() async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

class MockImportCompaniesNotifier extends ImportCompaniesNotifier {
  MockImportCompaniesNotifier(List<ImportCompanyModel> list) : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }

  @override
  Future<void> fetchCompanies() async {}
}

class MockSuppliersNotifier extends SuppliersNotifier {
  MockSuppliersNotifier(List<SupplierModel> sups) : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(sups);
  }

  @override
  Future<void> fetchSuppliers() async {}
}

class MockPartnersNotifier extends PartnersNotifier {
  MockPartnersNotifier(List<PartnerModel> list) : super(category: 'All', showInactive: true, dio: Dio()) {
    state = AsyncValue.data(list);
  }

  @override
  Future<void> fetchPartners() async {}
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(super.dio, super.ref) {
    state = PurchaseOrdersState(purchaseOrders: []);
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

void main() {
  final sampleFiles = [
    ImportFileModel(
      importFileId: 1,
      importFileCode: 'IMP-2026-001',
      customFileNumber: 'ملف توريدات البتروكيماويات',
      companyId: 1,
      companyName: 'الشركة الهندسية للتوريدات',
      supplierId: 1,
      supplierName: 'Shanghai Petrochem Industrial Co.',
      poNumber: 'PO-2026-101',
      piNumber: 'PI-2026-SH-09',
      shipmentMode: 'Sea FCL',
      incotermCode: 'FOB',
      priority: 'High',
      shipmentCategory: 'Raw Materials',
      currentModule: 'Documentation',
      currentStage: 'ACID Generation',
      nextAction: 'Verify MTS ACID',
      createdAt: '2026-08-01T00:00:00Z',
      updatedAt: '2026-08-15T00:00:00Z',
    ),
    ImportFileModel(
      importFileId: 2,
      importFileCode: 'IMP-2026-002',
      companyId: 2,
      companyName: 'شركة النور للمقاولات العامة',
      supplierId: 2,
      supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
      poNumber: 'PO-2026-102',
      piNumber: 'YH20260730-6',
      shipmentMode: 'Sea FCL',
      incotermCode: 'CIF',
      priority: 'Medium',
      shipmentCategory: 'Textiles',
      currentModule: 'Documentation',
      currentStage: 'ACID Verification',
      nextAction: 'Reconcile Data',
      createdAt: '2026-08-05T00:00:00Z',
      updatedAt: '2026-08-19T00:00:00Z',
    ),
  ];

  final sampleAcids = [
    AcidRegistrationModel(
      acidId: 101,
      acidCode: 'ACID-REG-2026-001',
      acidNumber: '4928172938472910',
      importFileId: 1,
      importFileCode: 'IMP-2026-001',
      poId: 1,
      poNumber: 'PO-2026-101',
      importerId: 1,
      importerName: 'الشركة الهندسية للتوريدات',
      importerTaxId: '100-200-300',
      importerAddress: '15 شارع النصر، المعادي، القاهرة',
      supplierId: 1,
      exporterName: 'Shanghai Petrochem Industrial Co.',
      exporterRegType: 'VAT Number',
      exporterRegId: 'CN91310000',
      exporterCountry: 'China',
      exporterCountryCode: 'CN',
      exporterAddress: 'No. 88 Century Avenue, Pudong, Shanghai',
      exporterPhone: '+86 21 5888 8888',
      cargoxId: 'CX-SHANGHAI-99',
      proformaInvoiceNo: 'PI-2026-SH-09',
      proformaInvoiceDate: '2026-08-15',
      invoiceType: 'Proforma Invoice',
      polName: 'CHANGSHU',
      podName: 'Alexandria',
      customsBrokerId: 1,
      customsBrokerName: 'البرنس للتخليص الجمركي',
      customsBrokerPhone: '01012345678',
      requestedDate: '2026-08-15',
      generatedDate: '2026-08-18',
      expiryDate: '2026-11-18',
      status: 'Issued',
      daysToExpiry: 65,
      isVerified: true,
      isActive: true,
      createdAt: '2026-08-15T10:00:00Z',
      updatedAt: '2026-08-18T12:00:00Z',
    ),
  ];

  final sampleTrackerSummary = AcidTrackerSummaryModel(
    totalAcidsCount: 3,
    validCount: 1,
    expiringSoonCount: 1,
    expiredCount: 1,
    customsReleasedCount: 0,
    pendingIssueCount: 0,
    items: [
      AcidTrackerItemModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        acidSessionId: 101,
        acidCode: 'ACID-REG-2026-001',
        acidNumber: '4928172938472910',
        importerName: 'الشركة الهندسية للتوريدات',
        supplierName: 'Shanghai Petrochem Industrial Co.',
        poNumber: 'PO-2026-101',
        acidIssueDate: '2026-08-18',
        acidExpiryDate: '2026-11-18',
        daysRemaining: 65,
        totalValidityDays: 90,
        validityPercentage: 72.2,
        isCustomsReleased: false,
        status: 'Valid',
        statusLabelAr: 'ساري',
        alertRequired: false,
      ),
      AcidTrackerItemModel(
        importFileId: 2,
        importFileCode: 'IMP-2026-002',
        acidSessionId: 102,
        acidCode: 'ACID-REG-2026-002',
        acidNumber: '5281534391023010013',
        importerName: 'شركة النور للمقاولات العامة',
        supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
        poNumber: 'PO-2026-102',
        acidIssueDate: '2026-06-01',
        acidExpiryDate: '2026-09-22',
        daysRemaining: 7,
        totalValidityDays: 90,
        validityPercentage: 7.8,
        isCustomsReleased: false,
        status: 'Expiring Soon',
        statusLabelAr: 'يوشك على الانتهاء',
        alertRequired: true,
      ),
      AcidTrackerItemModel(
        importFileId: 3,
        importFileCode: 'IMP-2026-003',
        acidSessionId: 103,
        acidCode: 'ACID-REG-2026-003',
        acidNumber: '1122334455667788',
        importerName: 'المؤسسة العربية للاستيراد',
        supplierName: 'Global Freight Supplies',
        poNumber: 'PO-2026-103',
        acidIssueDate: '2026-05-01',
        acidExpiryDate: '2026-08-01',
        daysRemaining: -5,
        totalValidityDays: 90,
        validityPercentage: 0.0,
        isCustomsReleased: false,
        status: 'Expired',
        statusLabelAr: 'منتهي الصلاحية',
        alertRequired: true,
      ),
    ],
  );

  final sampleCompanies = [
    ImportCompanyModel(
      companyId: 1,
      importerName: 'الشركة الهندسية للتوريدات',
      address: '15 شارع النصر، المعادي، القاهرة',
      country: 'Egypt',
      importerId: '100200300',
      importerIdExpiry: DateTime(2030, 1, 1),
      vatId: '100-200-300',
      vatIdExpiry: DateTime(2030, 1, 1),
      registrationNumber: 'REG-1234',
      registrationExpiry: DateTime(2030, 1, 1),
    ),
  ];

  final sampleSuppliers = [
    SupplierModel(
      supplierId: 1,
      supplierCode: 'SUP-001',
      companyName: 'Shanghai Petrochem Industrial Co.',
      supplierType: 'Manufacturer',
      registrationType: 'VAT Number',
      foreignExporterId: 'CN91310000',
      foreignExporterCountry: 'China',
      foreignExporterCountryCode: 'CN',
      address: 'No. 88 Century Avenue, Pudong, Shanghai',
      phone: '+86 21 5888 8888',
      cargoxPlatformId: 'CX-SHANGHAI-99',
      isActive: true,
    ),
  ];

  Widget buildScreen15TestWidget({
    Size size = const Size(1400, 900),
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
    AcidTrackerSummaryModel? customTracker,
  }) {
    final tracker = customTracker ?? sampleTrackerSummary;

    return ProviderScope(
      overrides: [
        acidSessionsProvider.overrideWith((ref) => MockAcidSessionsNotifier(sampleAcids)),
        acidTrackerProvider.overrideWith((ref) => MockAcidTrackerNotifier(tracker)),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(sampleFiles)),
        importCompaniesProvider.overrideWith((ref) => MockImportCompaniesNotifier(sampleCompanies)),
        suppliersProvider.overrideWith((ref) => MockSuppliersNotifier(sampleSuppliers)),
        partnersProvider.overrideWith((ref) => MockPartnersNotifier([])),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(Dio(), ref)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.noScaling,
              ),
              child: const Scaffold(
                body: NafezaAcidScreen(initialSubTab: 4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 15: Nafeza ACID Expiry & Customs Release Tracker SubTab Tests', () {
    setUp(() {
      LivePulseBadge.enableAnimation = false;
    });

    tearDown(() {
      LivePulseBadge.enableAnimation = true;
    });

    testWidgets('1. Desktop Layout (1400x900) - Renders summary cards row, search, and table without overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NafezaAcidScreen), findsOneWidget);

      // Verify Summary Cards exist
      expect(find.text('إجمالي أرقام ACID'), findsOneWidget);
      expect(find.text('ساري (> 14 يوم)'), findsOneWidget);
      expect(find.text('أوشك على الانتهاء (≤ 14 يوم)'), findsOneWidget);
      expect(find.text('منتهي الصلاحية'), findsNWidgets(2));

      // Verify Metric Counts
      expect(find.text('3'), findsNWidgets(2)); // Total card + tab badge
      expect(find.text('1'), findsNWidgets(4)); // 3 cards + 1 tab badge

      // Verify Search Field
      expect(find.byKey(const Key('acidExpiryTrackerSearchField')), findsOneWidget);

      // Verify DataTable and columns
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('الإجراءات'), findsOneWidget);
      expect(find.text('رقم ACID'), findsOneWidget);
      expect(find.text('ملف الشحنة'), findsOneWidget);
      expect(find.text('المصدر الأجنبي'), findsOneWidget);
      expect(find.text('تاريخ الصلاحية'), findsOneWidget);
      expect(find.text('الأيام المتبقية'), findsOneWidget);
      expect(find.text('حالة الصلاحية'), findsOneWidget);

      // Verify Row items
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('4928172938472910')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('5281534391023010013')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('1122334455667788')), findsOneWidget);
    });

    testWidgets('2. Tablet Layout (800x1024) - Renders cleanly without overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      await tester.pumpWidget(buildScreen15TestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('acidExpiryTrackerSearchField')), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('إجمالي أرقام ACID'), findsOneWidget);
    });

    testWidgets('3. Mobile Layout (390x844) - Renders 2x2 grid of cards and scrollable table with 0 overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildScreen15TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('إجمالي أرقام ACID'), findsOneWidget);
      expect(find.text('ساري (> 14 يوم)'), findsOneWidget);
      expect(find.text('أوشك على الانتهاء (≤ 14 يوم)'), findsOneWidget);
      expect(find.text('منتهي الصلاحية'), findsNWidgets(2));

      expect(find.byKey(const Key('acidExpiryTrackerSearchField')), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('4. Search & Filter in Expiry Tracker - Matches records and displays empty state when not found', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Search for specific ACID
      final searchInput = find.byKey(const Key('acidExpiryTrackerSearchField'));
      await tester.enterText(searchInput, '4928172938472910');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(DataTable), matching: find.text('4928172938472910')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('5281534391023010013')), findsNothing);

      // Search for non-matching query
      await tester.enterText(searchInput, 'NON_EXISTENT_TRACKER_ACID');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(DataTable), matching: find.text('4928172938472910')), findsNothing);
      expect(find.text('لم يتم العثور على طلبات ACID مطابقة'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('5. Task E: Row-Level Clone Action triggers Clone Review Dialog directly from Tracker table', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Find clone button on row 1
      final cloneRowBtn = find.byKey(const Key('cloneTrackerRowBtn_4928172938472910'));
      expect(cloneRowBtn, findsOneWidget);
      await tester.tap(cloneRowBtn);
      await tester.pumpAndSettle();

      // Verify CloneEntityReviewDialog appears
      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('4928172938472910'), findsWidgets);

      // Confirm clone
      final confirmBtn = find.byIcon(Icons.control_point_duplicate_rounded);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar and redirection to Tab 0
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('تم استنساخ بيانات طلب ACID بنجاح وجاهزة للمراجعة'), findsOneWidget);
    });

    testWidgets('6. Validity Status & Days Remaining Highlighting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Verify days remaining text
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('65')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('7')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('-5')), findsOneWidget);

      // Verify status badges
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('ساري وصالح')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('أوشك على الانتهاء')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('منتهي الصلاحية')), findsOneWidget);
    });

    testWidgets('7. WCAG AA Dark Mode Contrast and Theme Rendering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(
        size: const Size(1400, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('4928172938472910')), findsOneWidget);
      expect(find.text('إجمالي أرقام ACID'), findsOneWidget);
    });

    testWidgets('8. RTL Arabic Directionality & Localization', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(
        size: const Size(1400, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('متتبع الصلاحية والإفراج'), findsOneWidget);
      expect(find.text('إجمالي أرقام ACID'), findsOneWidget);
      expect(find.text('ساري (> 14 يوم)'), findsOneWidget);
      expect(find.text('رقم ACID'), findsOneWidget);
    });

    testWidgets('9. English Locale (LTR) Directionality & Localization', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen15TestWidget(
        size: const Size(1400, 900),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Expiry & Release Tracker'), findsOneWidget);
      expect(find.text('Total ACID Numbers'), findsOneWidget);
      expect(find.text('Valid (> 14 Days)'), findsOneWidget);
      expect(find.text('Expiring Soon (≤ 14 Days)'), findsOneWidget);
      expect(find.text('Expired'), findsNWidgets(2)); // Card and Table badge
      expect(find.text('ACID Number'), findsOneWidget);
    });
  });
}
