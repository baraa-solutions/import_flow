import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/action_toolbar.dart';
import 'package:frontend/core/widgets/app_status_badge.dart';
import 'package:frontend/core/widgets/back_to_dashboard_button.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/core/widgets/enterprise_data_table/enterprise_data_table.dart';
import 'package:frontend/core/widgets/page_header.dart';
import 'package:frontend/core/widgets/row_actions_pill.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/master_items/models/item_supplier_catalog_model.dart';
import 'package:frontend/features/master_items/models/master_item_model.dart';
import 'package:frontend/features/master_items/providers/master_items_provider.dart';
import 'package:frontend/features/master_items/screens/master_items_screen.dart';
import 'package:frontend/features/master_items/widgets/item_supplier_mapping_dialog.dart';
import 'package:frontend/features/master_items/widgets/master_item_form_dialog.dart';
import 'package:frontend/features/master_items/widgets/master_items_filter_bar.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

Widget _buildTestWrapper({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocales.localizationsDelegates,
      supportedLocales: AppLocales.supportedLocales,
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}

final _testItems = [
  const MasterItemModel(
    itemId: 1,
    itemCode: 'RAW-ALUM-6063',
    descriptionAr: 'سبائك ألومنيوم 6063 نقاء عالي',
    descriptionEn: 'Aluminum Ingot 6063 High Purity',
    tariffId: 10,
    hsCode: '7601.10.00',
    lastCustomsDutyPct: 5.0,
    lastVatPct: 14.0,
    defaultUom: 'TON',
    defaultPkgType: 'Bundle',
    cbmPerUnit: 1.2,
    grossWeightKg: 1000.0,
    netWeightKg: 995.0,
    productCategory: 'Raw Materials',
    isActive: true,
  ),
  const MasterItemModel(
    itemId: 2,
    itemCode: 'SP-BEARING-6205',
    descriptionAr: 'رولمان بلي 6205 لمعدات الدرفلة',
    descriptionEn: 'Deep Groove Ball Bearing 6205',
    tariffId: 11,
    hsCode: '8482.10.00',
    lastCustomsDutyPct: 2.0,
    lastVatPct: 14.0,
    defaultUom: 'PCS',
    defaultPkgType: 'Carton',
    cbmPerUnit: 0.002,
    grossWeightKg: 0.35,
    netWeightKg: 0.32,
    productCategory: 'Spare Parts',
    isActive: false,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MasterItemsScreen (Type B Standards Verification)', () {
    testWidgets('Renders Type B PageHeader with exactly 2 top actions and NO stage badges', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestWrapper(
          overrides: [
            masterItemsProvider.overrideWith(() => _MockMasterItemsNotifier(items: _testItems)),
          ],
          child: const MasterItemsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify PageHeader exists
      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.text('دليل الأصناف والكتالوج المرجعي'), findsOneWidget);

      // 2. Strict Type B rule: Exactly 2 top actions
      // Action 1: Add New Item AppButton with primary variant
      final addBtnFinder = find.widgetWithText(AppButton, 'إضافة صنف جديد');
      expect(addBtnFinder, findsOneWidget);
      final addBtn = tester.widget<AppButton>(addBtnFinder);
      expect(addBtn.variant, equals(AppButtonVariant.primary));

      // Action 2: Back to Dashboard button
      expect(find.byType(BackToDashboardButton), findsOneWidget);

      // 3. Strict Type B rule: NO stage badges, NO skip step, NO stop shipment
      expect(find.textContaining('PHASE-'), findsNothing);
      expect(find.textContaining('STAGE_'), findsNothing);
      expect(find.text('تخطي المرحلة'), findsNothing);
      expect(find.text('إيقاف الشحنة'), findsNothing);
      expect(find.text('Skip Step'), findsNothing);
      expect(find.text('Stop Shipment'), findsNothing);
    });

    testWidgets('Renders single Compact ActionToolbar with search, category filter, 🔄 and 📗', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestWrapper(
          overrides: [
            masterItemsProvider.overrideWith(() => _MockMasterItemsNotifier(items: _testItems)),
          ],
          child: const MasterItemsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. ActionToolbar exists
      expect(find.byType(ActionToolbar), findsOneWidget);

      // 2. Search Field exists with correct hint
      expect(find.widgetWithText(TextField, 'بحث بكود الصنف أو التوصيف...'), findsOneWidget);

      // 3. Category Filter exists
      expect(find.byType(MasterItemsCategoryFilter), findsOneWidget);

      // 4. Quick Actions: Refresh and Excel Export buttons
      expect(find.byTooltip('تحديث فوري'), findsOneWidget);
      expect(find.byTooltip('تصدير إكسل 📗'), findsOneWidget);
    });

    testWidgets('Renders EnterpriseDataTable with AppStatusBadge and RowActionsPill', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestWrapper(
          overrides: [
            masterItemsProvider.overrideWith(() => _MockMasterItemsNotifier(items: _testItems)),
          ],
          child: const MasterItemsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. EnterpriseDataTable exists
      expect(find.byType(EnterpriseDataTable<MasterItemModel>), findsOneWidget);

      // 2. Items data visible
      expect(find.text('RAW-ALUM-6063'), findsOneWidget);
      expect(find.text('SP-BEARING-6205'), findsOneWidget);
      expect(find.text('سبائك ألومنيوم 6063 نقاء عالي'), findsOneWidget);

      // 3. Status Badges
      expect(find.byType(AppStatusBadge), findsAtLeastNWidgets(2));
      expect(find.text('نشط'), findsOneWidget);
      expect(find.text('معطل'), findsOneWidget);

      // 4. RowActionsPill
      expect(find.byType(RowActionsPill), findsAtLeastNWidgets(2));
    });
  });

  group('MasterItemFormDialog (Lazy Modal Verification)', () {
    testWidgets('Renders form fields and SearchableDropdownField for tariffs and units', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tariffMock = CustomsTariffModel(
        tariffId: 10,
        hsCode: '7601.10.00',
        hsDescription: 'سبائك ألومنيوم خام غير مشغولة',
        customsDutyRate: 5.0,
        vatRate: 14.0,
        scheduleTaxRate: 0.0,
        developmentFeeRate: 0.0,
        importFeeRate: 0.0,
        requiresCoo: true,
        requiresInspection: true,
        requiresAcid: true,
        effectiveFrom: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isActive: true,
      );

      await tester.pumpWidget(
        _buildTestWrapper(
          overrides: [
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier(ref, [tariffMock])),
          ],
          child: const MasterItemFormDialog(),
        ),
      );
      await tester.pumpAndSettle();

      // Title
      expect(find.text('إضافة صنف مرجعي جديد للكتالوج'), findsOneWidget);

      // CustomTextFields
      expect(find.text('كود الصنف الداخلي (Item SKU)'), findsOneWidget);
      expect(find.text('الوصف العربي المعتمد (Description AR)'), findsOneWidget);
      expect(find.text('الوصف الإنجليزي (Description EN)'), findsOneWidget);
      expect(find.text('الحجم للوحدة (CBM)'), findsOneWidget);

      // SearchableDropdownFields for Tariff, UOM, and Package Type
      expect(find.byType(SearchableDropdownField<int>), findsOneWidget);
      expect(find.byType(SearchableDropdownField<String>), findsAtLeastNWidgets(2));

      // Buttons
      expect(find.widgetWithText(AppButton, 'إضافة الصنف للكتالوج'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'إلغاء'), findsOneWidget);
    });
  });

  group('ItemSupplierMappingDialog (Supplier Linkage Verification)', () {
    testWidgets('Renders linked suppliers table and linkage form toggling', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final item = _testItems.first;
      final supplierMock = SupplierModel(
        supplierId: 10,
        supplierCode: 'SUP-001',
        companyName: 'Shanghai Aluminum Corp',
        supplierType: 'Manufacturer',
        registrationType: 'Company',
        foreignExporterId: 'EXP-9921',
        foreignExporterCountry: 'China',
        foreignExporterCountryCode: 'CN',
        address: 'Industrial Zone, Shanghai',
      );

      await tester.pumpWidget(
        _buildTestWrapper(
          overrides: [
            suppliersProvider.overrideWith((ref) => _MockSuppliersNotifier([supplierMock])),
            itemSuppliersProvider(item.itemId).overrideWith((ref) => Future.value([
                  const ItemSupplierCatalogModel(
                    catalogId: 1,
                    itemId: 1,
                    supplierId: 10,
                    supplierName: 'Shanghai Aluminum Corp',
                    supplierItemCode: 'SH-6063-INGOT',
                    lastConfirmedPrice: 2350.0,
                    lastConfirmedCurrency: 'USD',
                    isPreferredSupplier: true,
                    leadTimeDays: 20,
                  ),
                ])),
          ],
          child: ItemSupplierMappingDialog(item: item),
        ),
      );
      await tester.pumpAndSettle();

      // Header and info
      expect(find.textContaining('ربط أكواد الموردين وكتالوج الأسعار: RAW-ALUM-6063'), findsOneWidget);
      expect(find.text('Shanghai Aluminum Corp'), findsOneWidget);
      expect(find.text('SH-6063-INGOT'), findsOneWidget);
      expect(find.text('2350.00 USD'), findsOneWidget);
      expect(find.text('المفضل'), findsOneWidget);

      // Click "ربط مورد جديد" to reveal form
      final addSupplierBtn = find.widgetWithText(AppButton, 'ربط مورد جديد');
      expect(addSupplierBtn, findsOneWidget);
      await tester.tap(addSupplierBtn);
      await tester.pumpAndSettle();

      expect(find.text('ربط مورد جديد وتثبيت كود الصنف وسعر العرض'), findsOneWidget);
      expect(find.text('المورد الأجنبي (Foreign Supplier)'), findsOneWidget);
      expect(find.text('كود الصنف لدى المورد (Supplier Part #)'), findsOneWidget);
    });
  });
}

// ── Mock Notifiers for Tests ────────────────────────────────────

class _MockMasterItemsNotifier extends MasterItemsNotifier {
  final List<MasterItemModel> _mockItems;

  _MockMasterItemsNotifier({required List<MasterItemModel> items})
      : _mockItems = items;

  @override
  Future<MasterItemsState> build() async {
    return MasterItemsState(
      items: _mockItems,
      total: _mockItems.length,
    );
  }
}

class _MockCustomsTariffNotifier extends CustomsTariffNotifier {
  _MockCustomsTariffNotifier(Ref ref, List<CustomsTariffModel> items)
      : super(ref: ref, showInactive: true, search: '', dio: Dio()) {
    state = AsyncValue.data(items);
  }

  @override
  Future<void> fetchTariffs() async {}
}

class _MockSuppliersNotifier extends SuppliersNotifier {
  _MockSuppliersNotifier(List<SupplierModel> items)
      : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(items);
  }

  @override
  Future<void> fetchSuppliers() async {}
}
