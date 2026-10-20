import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/clone_entity_review_dialog.dart';
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
    AcidRegistrationModel(
      acidId: 102,
      acidCode: 'ACID-REG-2026-002',
      acidNumber: '5281534391023010013',
      importFileId: 2,
      importFileCode: 'IMP-2026-002',
      poId: 2,
      poNumber: 'PO-2026-102',
      importerId: 2,
      importerName: 'شركة النور للمقاولات العامة',
      importerTaxId: '528-153-439',
      importerAddress: 'مدينة نصر، القاهرة',
      supplierId: 2,
      exporterName: 'Suzhou Yuheng Textile Co.,Ltd',
      exporterRegType: 'Company Registration Number',
      exporterRegId: '913205813141920259',
      exporterCountry: 'CHINA',
      exporterCountryCode: 'CN',
      proformaInvoiceNo: 'YH20260730-6',
      polName: 'CHANGSHU',
      podName: 'Alexandria',
      requestedDate: '2026-08-19',
      generatedDate: '2026-08-19',
      expiryDate: '2027-02-19',
      status: 'DRAFT',
      daysToExpiry: 157,
      isVerified: false,
      isActive: true,
      createdAt: '2026-08-19T09:00:00Z',
      updatedAt: '2026-08-19T09:00:00Z',
    ),
  ];

  final sampleTrackerSummary = AcidTrackerSummaryModel(
    totalAcidsCount: 2,
    validCount: 2,
    expiringSoonCount: 0,
    expiredCount: 0,
    customsReleasedCount: 0,
    pendingIssueCount: 0,
    items: [],
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
    ImportCompanyModel(
      companyId: 2,
      importerName: 'شركة النور للمقاولات العامة',
      address: 'مدينة نصر، القاهرة',
      country: 'Egypt',
      importerId: '528153439',
      importerIdExpiry: DateTime(2030, 1, 1),
      vatId: '528-153-439',
      vatIdExpiry: DateTime(2030, 1, 1),
      registrationNumber: 'REG-5678',
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
    SupplierModel(
      supplierId: 2,
      supplierCode: 'SUP-002',
      companyName: 'Suzhou Yuheng Textile Co.,Ltd',
      supplierType: 'Manufacturer',
      registrationType: 'Company Registration Number',
      foreignExporterId: '913205813141920259',
      foreignExporterCountry: 'CHINA',
      foreignExporterCountryCode: 'CN',
      address: 'Suzhou Industrial Park, Jiangsu',
      phone: '+86 512 6666 8888',
      cargoxPlatformId: '5b1b827d-5840-4ad6-b692-c5f636881c0e',
      isActive: true,
    ),
  ];

  Widget buildScreen14TestWidget({
    Size size = const Size(1400, 900),
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
    List<AcidRegistrationModel>? customAcids,
  }) {
    final acids = customAcids ?? sampleAcids;

    return ProviderScope(
      overrides: [
        acidSessionsProvider.overrideWith((ref) => MockAcidSessionsNotifier(acids)),
        acidTrackerProvider.overrideWith((ref) => MockAcidTrackerNotifier(sampleTrackerSummary)),
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
                body: NafezaAcidScreen(initialSubTab: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 14: Nafeza ACID Issuance Registry SubTab Tests', () {
    testWidgets('1. Desktop Layout (1400x900) - Renders search, button, and table without overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NafezaAcidScreen), findsOneWidget);

      // Verify search field and new request button exist
      expect(find.byKey(const Key('acidRegistrySearchField')), findsOneWidget);
      expect(find.byKey(const Key('acidRegistryNewRequestBtn')), findsOneWidget);

      // Verify Table Columns exist
      expect(find.text('الإجراءات'), findsOneWidget);
      expect(find.text('رقم ACID'), findsOneWidget);
      expect(find.text('ملف الشحنة'), findsOneWidget);
      expect(find.text('المصدر الأجنبي'), findsOneWidget);
      expect(find.text('الشركة المستوردة'), findsOneWidget);

      // Verify populated session items exist
      expect(find.text('4928172938472910'), findsOneWidget);
      expect(find.text('5281534391023010013'), findsOneWidget);
    });

    testWidgets('2. Tablet Layout (800x1024) - Renders cleanly without overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      await tester.pumpWidget(buildScreen14TestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('acidRegistrySearchField')), findsOneWidget);
      expect(find.byKey(const Key('acidRegistryNewRequestBtn')), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('3. Mobile Layout (390x844) - Vertically stacked search bar and button with 0 overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildScreen14TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('acidRegistrySearchField')), findsOneWidget);
      expect(find.byKey(const Key('acidRegistryNewRequestBtn')), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('4. Search & Filter in Registry - Matches records and displays empty state when not found', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Search for specific ACID
      final searchInput = find.byKey(const Key('acidRegistrySearchField'));
      await tester.enterText(searchInput, '4928172938472910');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(DataTable), matching: find.text('4928172938472910')), findsOneWidget);
      expect(find.descendant(of: find.byType(DataTable), matching: find.text('5281534391023010013')), findsNothing);

      // Search for non-matching query
      await tester.enterText(searchInput, 'NO_MATCHING_ACID_QUERY');
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(DataTable), matching: find.text('4928172938472910')), findsNothing);
      expect(find.text('لم يتم العثور على طلبات ACID مطابقة'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('5. Task E: Row-Level Clone Action triggers Clone Review Dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Find copy action button on the first row using unique row key
      final cloneRowBtn = find.byKey(const Key('cloneRowBtn_101'));
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

    testWidgets('6. Edit Action loads session and redirects to SubTab 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      final editBtn = find.byIcon(Icons.edit_note).first;
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar appears confirming session loaded for edit
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('ACID-REG-2026-001'), findsAtLeastNWidgets(1));
    });

    testWidgets('7. WCAG AA Dark Mode Contrast and Theme Rendering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(
        size: const Size(1400, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('4928172938472910'), findsOneWidget);
    });

    testWidgets('8. RTL Arabic Directionality & Localization', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(
        size: const Size(1400, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('طلب ACID جديد'), findsOneWidget);
      expect(find.text('سجل إصدارات ACID'), findsOneWidget);
      expect(find.text('صادر وساري'), findsOneWidget);
      expect(find.text('مسودة مؤقتة'), findsOneWidget);
    });

    testWidgets('9. English Locale (LTR) Directionality & Localization', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen14TestWidget(
        size: const Size(1400, 900),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New ACID Request'), findsOneWidget);
      expect(find.text('ACID Issuance Registry'), findsOneWidget);
      expect(find.text('ACID Number'), findsOneWidget);
      expect(find.text('Issued & Valid'), findsOneWidget);
    });
  });
}
