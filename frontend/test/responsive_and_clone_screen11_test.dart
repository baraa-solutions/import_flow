import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:frontend/features/import_documentation/widgets/search_and_clone_acid_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
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
      acidNumber: '5829104829184729',
      importFileId: 2,
      importFileCode: 'IMP-2026-002',
      poId: 2,
      poNumber: 'PO-2026-102',
      importerId: 2,
      importerName: 'العالمية للاستيراد والتصدير',
      importerTaxId: '200-300-400',
      supplierId: 2,
      exporterName: 'Hamburg Valve & Machinery GmbH',
      exporterRegType: 'Company Registration Number',
      exporterRegId: 'DE811122334',
      exporterCountry: 'Germany',
      exporterCountryCode: 'DE',
      proformaInvoiceNo: 'PI-DE-2026-04',
      polName: 'HAMBURG',
      podName: 'Dekheila',
      status: 'REQUESTED',
      daysToExpiry: 90,
      isVerified: false,
      isActive: true,
      createdAt: '2026-09-01T10:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    ),
  ];

  final sampleTrackerSummary = AcidTrackerSummaryModel(
    totalAcidsCount: 2,
    validCount: 1,
    expiringSoonCount: 0,
    expiredCount: 0,
    customsReleasedCount: 1,
    pendingIssueCount: 0,
    items: [
      AcidTrackerItemModel(
        acidSessionId: 101,
        acidCode: 'ACID-REG-2026-001',
        acidNumber: '4928172938472910',
        importFileId: 1,
        importFileCode: 'IMP-2026-001',
        importerName: 'الشركة الهندسية للتوريدات',
        supplierName: 'Shanghai Petrochem Industrial Co.',
        acidIssueDate: '2026-08-18',
        acidExpiryDate: '2026-11-18',
        daysRemaining: 65,
        validityPercentage: 72.2,
        status: 'Valid',
        statusLabelAr: 'ساري',
        alertRequired: false,
        isCustomsReleased: false,
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
    ),
  ];

  Widget buildScreen11TestWidget({
    Size size = const Size(1400, 900),
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
    MockAcidSessionsNotifier? customAcidNotifier,
  }) {
    final acidNotifier = customAcidNotifier ?? MockAcidSessionsNotifier(sampleAcids);

    return ProviderScope(
      overrides: [
        acidSessionsProvider.overrideWith((ref) => acidNotifier),
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
                body: NafezaAcidScreen(initialSubTab: 0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 11: NafezaAcidScreen (SubTab 0: ACID Request Form) 5-Task Protocol', () {
    testWidgets('1. Desktop Viewport (1400x900) layout renders with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(find.byKey(const Key('searchAndCloneAcidBtn')), findsOneWidget);
      expect(find.byKey(const Key('saveAcidRequestSubmitBtn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Tablet Viewport (800x1024) layout renders with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(find.byKey(const Key('saveAcidRequestSubmitBtn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Mobile Viewport (390x844) layout stacks into single column with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.byType(NafezaAcidScreen), findsOneWidget);
      expect(find.byKey(const Key('saveAcidRequestSubmitBtn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Dark Mode Color & Contrast tokens properly applied', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(
        size: const Size(1200, 900),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == AppTheme.darkCardBackground;
        }
        return false;
      });
      expect(containerFinder, findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. RTL Arabic mirroring verified under Locale(ar)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(
        size: const Size(1200, 900),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(NafezaAcidScreen));
      expect(Directionality.of(context), equals(TextDirection.rtl));
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Screen-Level Clone via searchAndCloneAcidBtn opens dialog, reviews invariants, and populates form', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      final cloneBtnFinder = find.byKey(const Key('searchAndCloneAcidBtn'));
      expect(cloneBtnFinder, findsOneWidget);
      await tester.tap(cloneBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneAcidDialog), findsOneWidget);

      final sessionTile = find.byKey(const Key('cloneAcidSessionTile_101'));
      expect(sessionTile, findsOneWidget);
      await tester.tap(sessionTile);
      await tester.pumpAndSettle();

      expect(find.byType(CloneEntityReviewDialog), findsOneWidget);
      expect(find.textContaining('4928172938472910'), findsWidgets);

      final confirmBtn = find.byIcon(Icons.control_point_duplicate_rounded);
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify populated cloned values in form
      expect(find.textContaining('الشركة الهندسية للتوريدات'), findsWidgets);
      expect(find.textContaining('Shanghai Petrochem Industrial Co.'), findsWidgets);
      // Suffix language follows Localizations.localeOf (en_US without supportedLocales), hence ' (Copy)'.
      expect(find.text('PI-2026-SH-09 (Copy)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Search and Filter inside SearchAndCloneAcidDialog filters records correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('searchAndCloneAcidBtn')));
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneAcidDialog), findsOneWidget);
      expect(find.textContaining('4928172938472910'), findsWidgets);
      expect(find.textContaining('5829104829184729'), findsWidgets);

      // Enter search query
      final inputFinder = find.byKey(const Key('searchAndCloneAcidQueryInput'));
      await tester.enterText(inputFinder, 'Hamburg');
      await tester.pumpAndSettle();

      // Verify filtered
      expect(find.textContaining('Hamburg Valve & Machinery GmbH'), findsOneWidget);
      expect(find.textContaining('Shanghai Petrochem Industrial Co.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Keyboard Shortcut Ctrl + D triggers Search and Clone ACID dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen11TestWidget(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(SearchAndCloneAcidDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
