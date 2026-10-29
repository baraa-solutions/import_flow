import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/cbm_calculator/models/cbm_calculator_model.dart';
import 'package:frontend/features/cbm_calculator/providers/cbm_calculator_provider.dart';
import 'package:frontend/features/cbm_calculator/screens/cbm_calculator_screen.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

class MockCBMCalculatorNotifier extends CBMCalculatorNotifier {
  MockCBMCalculatorNotifier(List<CBMCalculationModel> calculations) : super(Dio()) {
    state = CBMCalculatorState(
      calculations: calculations,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchCalculations() async {}
}

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier(List<ProjectModel> projects) : super(Dio()) {
    state = AsyncValue.data(projects);
  }

  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {}
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(Ref ref, List<PurchaseOrderModel> orders) : super(Dio(), ref) {
    state = PurchaseOrdersState(
      purchaseOrders: orders,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    String? search,
    String? status,
    int? companyId,
    int? supplierId,
    String? owner,
    bool includeInactive = true,
  }) async {}
}

void main() {
  final sampleCalcs = [
    CBMCalculationModel(
      calcId: 1,
      calcCode: 'CBM-2026-0001',
      title: 'Medical Devices Shipment Calculation',
      isStackable: true,
      totalCbm: 12.5,
      totalGrossWeightKg: 3500.0,
      recommendedShippingMethod: 'Sea Freight (LCL)',
      recommendedContainerType: 'LCL Consolidated',
      isActive: true,
      createdAt: '2026-08-23T12:00:00',
      items: [
        CBMItemModel(
          itemId: 101,
          calcId: 1,
          packageType: 'Carton',
          quantity: 20,
          length: 80,
          width: 60,
          height: 50,
          unit: 'cm',
          grossWeightPerUnitKg: 25,
          isStackable: true,
        ),
      ],
    ),
  ];

  group('CBM Calculator Localization & Anti-Stacked Tests (Screen 3)', () {
    test('Arabic AppLocalizationsAr returns pure Arabic for CBM Calculator keys', () {
      const lAr = AppLocalizationsAr();
      expect(lAr.cbmCalculatorTitle, equals('حاسبة الأحجام والوزن الجوي'));
      expect(lAr.cbmCalculatorSubtitle, equals('احتساب الأحجام CBM، الوزن الجوي المحاسبي، وتوصيات الحاويات ووسيلة الشحن'));
      expect(lAr.quickOperationalCalculatorTab, equals('حاسبة القياسات التشغيلية السريعة'));
      expect(lAr.savedCalculationsRegistryTab, equals('سجل دراسة وحسابات الشحن المحفوظة'));
      expect(lAr.totalCbmVolumeMetric, equals('إجمالي الحجم بالمتر المكعب'));
      expect(lAr.airChargeableWtMetric, equals('الوزن الجوي المحاسبي'));
      expect(lAr.volumetricWeight, equals('الوزن الحجمي'));
      expect(lAr.recommendedShippingMetric, equals('وسيلة الشحن المقترحة'));
      expect(lAr.cargoStackingInstructions, equals('تعليمات التحميل والرص:'));
      expect(lAr.stackableOption, equals('قابل للرص'));
      expect(lAr.nonStackableOption, equals('غير قابل للرص'));
      expect(lAr.compareContainersMatrix, equals('مقارنة خيارات الحاويات'));
      expect(lAr.visualLoadPlanSimulator, equals('مخطط ومحاكاة رص الحاويات'));
      expect(lAr.addPackageLine, equals('إضافة سطر طرد'));
      expect(lAr.saveCalculationSession, equals('حفظ الجلسة التشغيلية'));

      // Check anti-stacked: zero English text in Arabic getters
      expect(lAr.cbmCalculatorTitle.contains('Cargo Measurement Engine'), isFalse);
      expect(lAr.quickOperationalCalculatorTab.contains('Quick Operational'), isFalse);
      expect(lAr.stackableOption.contains('Stackable'), isFalse);
      expect(lAr.compareContainersMatrix.contains('Matrix'), isFalse);
    });

    test('English AppLocalizationsEn returns pure English for CBM Calculator keys', () {
      const lEn = AppLocalizationsEn();
      expect(lEn.cbmCalculatorTitle, equals('Cargo Measurement Engine'));
      expect(lEn.cbmCalculatorSubtitle, equals('Calculate CBM volume, air chargeable weight, and container load recommendations'));
      expect(lEn.quickOperationalCalculatorTab, equals('Quick Operational Calculator'));
      expect(lEn.savedCalculationsRegistryTab, equals('Saved Calculations History Log'));
      expect(lEn.totalCbmVolumeMetric, equals('Total CBM Volume'));
      expect(lEn.airChargeableWtMetric, equals('Air Chargeable Wt'));
      expect(lEn.volumetricWeight, equals('Volumetric Weight'));
      expect(lEn.recommendedShippingMetric, equals('Recommended Shipping'));
      expect(lEn.cargoStackingInstructions, equals('Cargo Stacking Instructions:'));
      expect(lEn.stackableOption, equals('Stackable'));
      expect(lEn.nonStackableOption, equals('Non-Stackable'));
      expect(lEn.compareContainersMatrix, equals('Compare Containers Matrix'));
      expect(lEn.visualLoadPlanSimulator, equals('Visual Container Load Plan'));
      expect(lEn.addPackageLine, equals('Add Package Line'));
      expect(lEn.saveCalculationSession, equals('Save Calculation Session'));

      // Check anti-stacked: zero Arabic letters
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(lEn.cbmCalculatorTitle), isFalse);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(lEn.quickOperationalCalculatorTab), isFalse);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(lEn.stackableOption), isFalse);
    });

    testWidgets('CBMCalculatorScreen renders purely in Arabic without stacked English text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
            cbmCalculatorProvider.overrideWith((ref) => MockCBMCalculatorNotifier(sampleCalcs)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, [])),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: CBMCalculatorScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify pure Arabic title and tab
      expect(find.text('حاسبة الأحجام والوزن الجوي'), findsOneWidget);
      expect(find.text('حاسبة القياسات التشغيلية السريعة'), findsOneWidget);
      expect(find.text('سجل دراسة وحسابات الشحن المحفوظة'), findsOneWidget);
      expect(find.text('إجمالي الحجم بالمتر المكعب'), findsOneWidget);
      expect(find.text('مقارنة خيارات الحاويات'), findsOneWidget);
      expect(find.text('مخطط ومحاكاة رص الحاويات'), findsOneWidget);

      // Verify no stacked bilingual strings exist on screen
      expect(find.text('Cargo Measurement Engine (حاسبة الأحجام والوزن الجوي)'), findsNothing);
      expect(find.text('Quick Operational Calculator'), findsNothing);
      expect(find.text('📦 قابل للرص (Stackable)'), findsNothing);
      expect(find.text('Cargo Package Measurements & Dimensions (أبعاد ووزن الطرود)'), findsNothing);
    });

    testWidgets('CBMCalculatorScreen renders purely in English without stacked Arabic text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('en'));
              return n;
            }),
            cbmCalculatorProvider.overrideWith((ref) => MockCBMCalculatorNotifier(sampleCalcs)),
            projectsProvider.overrideWith((ref) => MockProjectsNotifier([])),
            purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, [])),
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier([])),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: CBMCalculatorScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify pure English title and tab
      expect(find.text('Cargo Measurement Engine'), findsOneWidget);
      expect(find.text('Quick Operational Calculator'), findsOneWidget);
      expect(find.text('Saved Calculations History Log'), findsOneWidget);
      expect(find.text('Total CBM Volume'), findsOneWidget);
      expect(find.text('Compare Containers Matrix'), findsOneWidget);
      expect(find.text('Visual Container Load Plan'), findsOneWidget);

      // Verify no Arabic text is shown on English UI
      expect(find.text('حاسبة الأحجام والوزن الجوي'), findsNothing);
      expect(find.text('حاسبة القياسات التشغيلية السريعة'), findsNothing);
      expect(find.text('📦 قابل للرص (Stackable)'), findsNothing);
    });
  });
}
