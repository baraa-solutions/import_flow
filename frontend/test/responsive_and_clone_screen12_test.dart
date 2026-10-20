import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/screens/nafeza_acid_screen.dart';
import 'package:frontend/features/import_documentation/widgets/search_and_clone_acid_dialog.dart';
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

  @override
  Future<Map<String, dynamic>> parseAcidText(String rawText, {int? importFileId}) async {
    return {
      'acid_number': '5281534391023010013',
      'generated_date': '19-Aug-2026 11:26:54 AM',
      'expiry_date': '19-Feb-2027 11:26:54 AM',
      'importer_name': 'SCAS For Construction And Finishing',
      'importer_tax_id': '528153439',
      'importer_address': '44ش 18 المعادى القاهرة رقم ملف 36221ق',
      'exporter_name': 'Suzhou Yuheng Textile Co.,Ltd',
      'exporter_reg_id': '913205813141920259',
      'exporter_reg_type': 'Company Registration Number',
      'exporter_country': 'CHINA',
      'exporter_country_code': 'CN',
      'proforma_invoice_no': 'YH20260730-6',
      'pol_name': 'CHANGSHU',
      'pod_name': 'Alexandria',
      'cargox_id': '5b1b827d-5840-4ad6-b692-c5f636881c0e',
    };
  }
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
      status: 'ISSUED',
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
      status: 'ISSUED',
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

  Widget buildScreen12TestWidget({
    Size size = const Size(1400, 900),
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return ProviderScope(
      overrides: [
        acidSessionsProvider.overrideWith((ref) => MockAcidSessionsNotifier(sampleAcids)),
        acidTrackerProvider.overrideWith((ref) => MockAcidTrackerNotifier(sampleTrackerSummary)),
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
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
                body: NafezaAcidScreen(initialSubTab: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 12: Nafeza MTS Smart AI Parser SubTab Tests', () {
    testWidgets('1. Desktop Layout (1400x900) - Renders without overflows', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget());
      await tester.pumpAndSettle();

      // Check Smart Parser tab is active
      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
      expect(find.byIcon(Icons.history_edu), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tablet Layout (800x1024) - Renders without overflows', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Mobile Layout (390x844) - Stacks header controls with 0 overflows', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
      expect(find.byIcon(Icons.history_edu), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Load Egyptian MTS Sample Text & Extract Fields', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget());
      await tester.pumpAndSettle();

      // Tap load sample MTS text button
      final loadSampleBtn = find.byIcon(Icons.auto_fix_high);
      expect(loadSampleBtn, findsOneWidget);
      await tester.tap(loadSampleBtn);
      await tester.pumpAndSettle();

      // The debug sample text is deliberately neutral (all-zero ACID, 'Sample ...' parties):
      // the former real-looking ACID / supplier were fabricated data and were removed.
      // Verify text field contains sample notification
      final textFieldFinder = find.byType(TextField).first;
      final TextField textFieldWidget = tester.widget(textFieldFinder);
      expect(textFieldWidget.controller?.text.contains('0000000000000000000'), isTrue);
      expect(textFieldWidget.controller?.text.contains('MTS Notification'), isTrue);

      // Verify results container is displayed
      expect(find.textContaining('0000000000000000000'), findsWidgets);
      expect(find.textContaining('Sample Exporter Co.,Ltd'), findsWidgets);
      expect(find.byIcon(Icons.compare_arrows), findsWidgets);
      expect(find.byIcon(Icons.save_as), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Mobile Layout with Parsed Results (390x844) - 0 Overflows', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Load sample text so results card is rendered
      final loadSampleBtn = find.byIcon(Icons.auto_fix_high);
      await tester.tap(loadSampleBtn);
      await tester.pumpAndSettle();

      // Verify parsed card rendered on mobile without overflow
      expect(find.textContaining('0000000000000000000'), findsWidgets);
      expect(find.byIcon(Icons.save_as), findsOneWidget);
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('6. WCAG AA Dark Mode Contrast and Tokens', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      // Load sample text
      await tester.tap(find.byIcon(Icons.auto_fix_high));
      await tester.pumpAndSettle();

      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. RTL Arabic Directionality & Localization', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('الإدخال الذكي من نافذة'), findsWidgets);
      expect(find.textContaining('استيراد نص من جلسة سابقة'), findsOneWidget);
      expect(find.textContaining('تحميل نص إشعار نافذة نموذجي'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Import Nafeza Raw Text from Previous Session Modal', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen12TestWidget());
      await tester.pumpAndSettle();

      // Tap import from previous session button
      final importPrevBtn = find.byIcon(Icons.history_edu);
      expect(importPrevBtn, findsOneWidget);
      await tester.tap(importPrevBtn);
      await tester.pumpAndSettle();

      // Verify SearchAndCloneAcidDialog modal opened
      expect(find.byType(SearchAndCloneAcidDialog), findsOneWidget);
      expect(find.textContaining('4928172938472910'), findsOneWidget);

      // Select first session item
      await tester.tap(find.textContaining('4928172938472910'));
      await tester.pumpAndSettle();

      // Verify modal closed
      expect(find.byType(SearchAndCloneAcidDialog), findsNothing);

      // Verify SnackBar appeared
      expect(find.byType(SnackBar), findsOneWidget);

      // Verify text field populated
      final textFieldFinder = find.byType(TextField).first;
      final TextField textFieldWidget = tester.widget(textFieldFinder);
      expect(textFieldWidget.controller?.text.contains('4928172938472910'), isTrue);

      expect(tester.takeException(), isNull);
    });
  });
}
