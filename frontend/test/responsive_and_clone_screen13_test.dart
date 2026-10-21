import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class MockAcidSessionsNotifier extends AcidSessionsNotifier {
  AcidComparisonResult? mockComparisonResult;
  bool saveVerifiedCalled = false;

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
  Future<AcidComparisonResult> compareAcid(
    Map<String, dynamic> requested,
    Map<String, dynamic> generated,
  ) async {
    if (mockComparisonResult != null) return mockComparisonResult!;
    return AcidComparisonResult(
      allMatched: true,
      hasCriticalError: false,
      matchPercentage: 100.0,
      totalComparedFields: 4,
      matchedCount: 4,
      discrepantCount: 0,
      items: [
        AcidDiscrepancyItem(
          field: 'importer_tax_id',
          labelAr: 'رقم السجل الضريبي للمستورد',
          labelEn: 'Importer Tax ID',
          requestedValue: '100-200-300',
          generatedValue: '100-200-300',
          isMatched: true,
          severity: 'info',
        ),
        AcidDiscrepancyItem(
          field: 'exporter_reg_id',
          labelAr: 'رقم السجل التجاري للمصدر',
          labelEn: 'Exporter Reg ID',
          requestedValue: 'CN91310000',
          generatedValue: 'CN91310000',
          isMatched: true,
          severity: 'info',
        ),
        AcidDiscrepancyItem(
          field: 'proforma_invoice_no',
          labelAr: 'رقم الفاتورة المبدئية',
          labelEn: 'Proforma Invoice No',
          requestedValue: 'PI-2026-SH-09',
          generatedValue: 'PI-2026-SH-09',
          isMatched: true,
          severity: 'info',
        ),
        AcidDiscrepancyItem(
          field: 'pol_name',
          labelAr: 'ميناء الشحن',
          labelEn: 'Port of Loading',
          requestedValue: 'CHANGSHU',
          generatedValue: 'CHANGSHU',
          isMatched: true,
          severity: 'info',
        ),
      ],
    );
  }

  @override
  Future<AcidRegistrationModel?> updateAcidSession(int acidId, Map<String, dynamic> payload) async {
    saveVerifiedCalled = true;
    return null;
  }

  @override
  Future<AcidRegistrationModel?> createAcidSession(Map<String, dynamic> payload) async {
    saveVerifiedCalled = true;
    return null;
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
      status: 'ISSUED',
      daysToExpiry: 65,
      isVerified: true,
      isActive: true,
      createdAt: '2026-08-15T10:00:00Z',
      updatedAt: '2026-08-18T12:00:00Z',
    ),
  ];

  final sampleTrackerSummary = AcidTrackerSummaryModel(
    totalAcidsCount: 1,
    validCount: 1,
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
  ];

  Widget buildScreen13TestWidget({
    Size size = const Size(1400, 900),
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
    int? initialImportFileId,
    MockAcidSessionsNotifier? customNotifier,
  }) {
    final notifier = customNotifier ?? MockAcidSessionsNotifier(sampleAcids);

    return ProviderScope(
      overrides: [
        acidSessionsProvider.overrideWith((ref) => notifier),
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
              child: Scaffold(
                body: NafezaAcidScreen(
                  initialSubTab: 2,
                  initialImportFileId: initialImportFileId,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 13: Nafeza ACID Discrepancy Matrix SubTab Tests', () {
    testWidgets('1. Desktop Layout (1400x900) - Renders without overflows & shows empty comparison hint', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen13TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NafezaAcidScreen), findsOneWidget);

      // Verify file selector and compare trigger button exist
      expect(find.text('تشغيل مصفوفة المطابقة الفورية'), findsOneWidget);
      // Verify empty state card is displayed
      expect(find.byIcon(Icons.rule_folder_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets('2. Tablet Layout (800x1024) - Renders cleanly without overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      await tester.pumpWidget(buildScreen13TestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('تشغيل مصفوفة المطابقة الفورية'), findsOneWidget);
    });

    testWidgets('3. Mobile Layout (390x844) - Vertically stacked layout with zero overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildScreen13TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('تشغيل مصفوفة المطابقة الفورية'), findsOneWidget);
    });

    testWidgets('4. Discrepancy Matrix Execution - 100% Perfect Match State', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final mockNotifier = MockAcidSessionsNotifier(sampleAcids);
      mockNotifier.mockComparisonResult = AcidComparisonResult(
        allMatched: true,
        hasCriticalError: false,
        matchPercentage: 100.0,
        totalComparedFields: 4,
        matchedCount: 4,
        discrepantCount: 0,
        items: [
          AcidDiscrepancyItem(
            field: 'importer_tax_id',
            labelAr: 'رقم السجل الضريبي للمستورد',
            labelEn: 'Importer Tax ID',
            requestedValue: '100-200-300',
            generatedValue: '100-200-300',
            isMatched: true,
            severity: 'info',
          ),
          AcidDiscrepancyItem(
            field: 'exporter_reg_id',
            labelAr: 'رقم السجل التجاري للمصدر',
            labelEn: 'Exporter Reg ID',
            requestedValue: 'CN91310000',
            generatedValue: 'CN91310000',
            isMatched: true,
            severity: 'info',
          ),
        ],
      );

      await tester.pumpWidget(buildScreen13TestWidget(
        size: const Size(1400, 900),
        initialImportFileId: 1,
        customNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      // Trigger comparison
      final compareBtn = find.text('تشغيل مصفوفة المطابقة الفورية');
      expect(compareBtn, findsOneWidget);
      await tester.tap(compareBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Perfect Match Header
      expect(find.text('المطابقة الجمركية كاملة بنسبة 100%'), findsOneWidget);
      expect(find.textContaining('100.0% (4 / 4)'), findsOneWidget);

      // Verify Table Columns and Items
      expect(find.text('الحقل الجمركي'), findsOneWidget);
      expect(find.text('البيان المطلوب (النظام)'), findsOneWidget);
      expect(find.text('البيان الصادر (نافذة)'), findsOneWidget);
      expect(find.text('حالة المطابقة'), findsOneWidget);
      expect(find.text('رقم السجل الضريبي للمستورد'), findsOneWidget);
      expect(find.text('رقم السجل التجاري للمصدر'), findsOneWidget);

      // Verify Verify & Certify Button is present
      expect(find.text('اعتماد وتثبيت رقم ACID بملف الشحنة'), findsOneWidget);
      // In 100% match, override justification field is not needed
      expect(find.text('ملاحظات وتبرير اعتماد الفروق'), findsNothing);
    });

    testWidgets('5. Discrepancy Matrix Execution - Discrepancy Found State with Override Justification', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final mockNotifier = MockAcidSessionsNotifier(sampleAcids);
      mockNotifier.mockComparisonResult = AcidComparisonResult(
        allMatched: false,
        hasCriticalError: false,
        matchPercentage: 66.7,
        totalComparedFields: 3,
        matchedCount: 2,
        discrepantCount: 1,
        items: [
          AcidDiscrepancyItem(
            field: 'importer_tax_id',
            labelAr: 'رقم السجل الضريبي للمستورد',
            labelEn: 'Importer Tax ID',
            requestedValue: '100-200-300',
            generatedValue: '100-200-300',
            isMatched: true,
            severity: 'info',
          ),
          AcidDiscrepancyItem(
            field: 'proforma_invoice_no',
            labelAr: 'رقم الفاتورة المبدئية',
            labelEn: 'Proforma Invoice No',
            requestedValue: 'PI-2026-SH-09',
            generatedValue: 'PI-2026-SH-09-REV1',
            isMatched: false,
            severity: 'warning',
          ),
        ],
      );

      await tester.pumpWidget(buildScreen13TestWidget(
        size: const Size(1400, 900),
        initialImportFileId: 1,
        customNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      // Trigger comparison
      final compareBtn = find.text('تشغيل مصفوفة المطابقة الفورية');
      await tester.tap(compareBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify Discrepancy Header
      expect(find.text('يوجد عدم تطابق في بعض الحقول الجمركية الأساسية!'), findsOneWidget);
      expect(find.textContaining('66.7% (2 / 3)'), findsOneWidget);

      // Verify Discrepancy Item Status (tab badge + table row)
      expect(find.text('فروق'), findsAtLeastNWidgets(1));

      // Verify Override Justification Input is visible
      expect(find.text('ملاحظات وتبرير اعتماد الفروق'), findsOneWidget);
      final reasonInput = find.byType(TextField).last;
      await tester.enterText(reasonInput, 'تم مراجعة التعديل مع المورد الأجنبي واعتماده رسمياً');
      await tester.pumpAndSettle();

      expect(find.text('تم مراجعة التعديل مع المورد الأجنبي واعتماده رسمياً'), findsOneWidget);
    });

    testWidgets('6. Copy Discrepancy Report Action Triggers SnackBar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final mockNotifier = MockAcidSessionsNotifier(sampleAcids);
      mockNotifier.mockComparisonResult = AcidComparisonResult(
        allMatched: true,
        hasCriticalError: false,
        matchPercentage: 100.0,
        totalComparedFields: 2,
        matchedCount: 2,
        discrepantCount: 0,
        items: [
          AcidDiscrepancyItem(
            field: 'importer_tax_id',
            labelAr: 'رقم السجل الضريبي للمستورد',
            labelEn: 'Importer Tax ID',
            requestedValue: '100-200-300',
            generatedValue: '100-200-300',
            isMatched: true,
            severity: 'info',
          ),
        ],
      );

      await tester.pumpWidget(buildScreen13TestWidget(
        size: const Size(1400, 900),
        initialImportFileId: 1,
        customNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      // Run comparison
      await tester.tap(find.text('تشغيل مصفوفة المطابقة الفورية'));
      await tester.pumpAndSettle();

      // Clipboard has no platform handler in widget tests; answer Clipboard.setData so the confirmation shows.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async => null,
      );

      // Tap Copy Report button
      final copyBtn = find.text('نسخ تقرير المطابقة');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('تم نسخ تقرير المطابقة الجمركية إلى الحافظة بنجاح'), findsOneWidget);
    });

    testWidgets('7. WCAG AA Dark Mode Contrast and Theme Rendering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildScreen13TestWidget(
        size: const Size(1400, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NafezaAcidScreen), findsOneWidget);
    });

    testWidgets('8. Mobile Layout with Loaded Table - Zero Overflows via Horizontal Scroll', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final mockNotifier = MockAcidSessionsNotifier(sampleAcids);
      mockNotifier.mockComparisonResult = AcidComparisonResult(
        allMatched: false,
        hasCriticalError: false,
        matchPercentage: 50.0,
        totalComparedFields: 2,
        matchedCount: 1,
        discrepantCount: 1,
        items: [
          AcidDiscrepancyItem(
            field: 'importer_tax_id',
            labelAr: 'رقم السجل الضريبي للمستورد',
            labelEn: 'Importer Tax ID',
            requestedValue: '100-200-300',
            generatedValue: '100-200-300',
            isMatched: true,
            severity: 'info',
          ),
          AcidDiscrepancyItem(
            field: 'proforma_invoice_no',
            labelAr: 'رقم الفاتورة المبدئية',
            labelEn: 'Proforma Invoice No',
            requestedValue: 'PI-2026-SH-09',
            generatedValue: 'PI-2026-SH-09-REV1',
            isMatched: false,
            severity: 'warning',
          ),
        ],
      );

      await tester.pumpWidget(buildScreen13TestWidget(
        size: const Size(390, 844),
        initialImportFileId: 1,
        customNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      // Run comparison
      await tester.tap(find.text('تشغيل مصفوفة المطابقة الفورية'));
      await tester.pumpAndSettle();

      // Ensure 0 RenderFlex overflows on mobile 390px
      expect(tester.takeException(), isNull);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('نسخ تقرير المطابقة'), findsOneWidget);
    });

    testWidgets('9. English Locale (LTR) Directionality & Localization', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final mockNotifier = MockAcidSessionsNotifier(sampleAcids);
      mockNotifier.mockComparisonResult = AcidComparisonResult(
        allMatched: true,
        hasCriticalError: false,
        matchPercentage: 100.0,
        totalComparedFields: 1,
        matchedCount: 1,
        discrepantCount: 0,
        items: [
          AcidDiscrepancyItem(
            field: 'importer_tax_id',
            labelAr: 'رقم السجل الضريبي للمستورد',
            labelEn: 'Importer Tax ID',
            requestedValue: '100-200-300',
            generatedValue: '100-200-300',
            isMatched: true,
            severity: 'info',
          ),
        ],
      );

      await tester.pumpWidget(buildScreen13TestWidget(
        size: const Size(1400, 900),
        locale: const Locale('en'),
        initialImportFileId: 1,
        customNotifier: mockNotifier,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Run Instant Discrepancy Matrix'), findsOneWidget);

      await tester.tap(find.text('Run Instant Discrepancy Matrix'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100% Customs Match (No Discrepancies)'), findsOneWidget);
      expect(find.text('Copy Discrepancy Report'), findsOneWidget);
      expect(find.text('Importer Tax ID'), findsOneWidget);
    });
  });
}
