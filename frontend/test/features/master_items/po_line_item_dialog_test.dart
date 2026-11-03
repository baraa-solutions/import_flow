import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/master_items/models/master_item_model.dart';
import 'package:frontend/features/master_items/repositories/master_items_repository.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/widgets/po_line_item_dialog.dart';

class FakeMasterItemsRepoForDialog extends MasterItemsRepository {
  FakeMasterItemsRepoForDialog() : super(Dio());

  List<MasterItemModel> items = [];

  @override
  Future<MasterItemListModel> fetchMasterItems({
    String? search,
    String? category,
    int skip = 0,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    return MasterItemListModel(
      total: items.length,
      items: items,
    );
  }
}

Widget createDialogTestApp({
  required Widget child,
  required MasterItemsRepository repository,
  Locale locale = const Locale('ar'),
}) {
  return ProviderScope(
    overrides: [
      masterItemsRepositoryProvider.overrideWithValue(repository),
    ],
    child: AppLocalizationsProvider(
      locale: locale,
      child: MaterialApp(
        locale: locale,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const ValueKey('open_dialog_btn'),
                onPressed: () {
                  showDialog(context: ctx, builder: (_) => child);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late FakeMasterItemsRepoForDialog fakeRepo;

  final sampleTariff = CustomsTariffModel(
    tariffId: 44,
    hsCode: '8415.10.00',
    hsDescription: 'وحدات تكييف هواء جدارية',
    customsDutyRate: 0.10,
    vatRate: 0.14,
    scheduleTaxRate: 0.0,
    developmentFeeRate: 0.0,
    importFeeRate: 0.0,
    customsServiceFeeRate: 0.0,
    requiresCoo: true,
    requiresInspection: false,
    requiresAcid: true,
    effectiveFrom: DateTime(2025, 1, 1),
    isActive: true,
    totalVersions: 1,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  final sampleCurrency = CurrencyModel(
    currencyId: 1,
    currencyCode: 'USD',
    currencyName: 'US Dollar',
    currencySymbol: '\$',
  );

  const catalogItem = MasterItemModel(
    itemId: 88,
    itemCode: 'AC-INVERTER-12K',
    descriptionAr: 'تكييف هواء انفرتر 1.5 حصان',
    descriptionEn: 'Air Conditioner Inverter 12000 BTU',
    tariffId: 44,
    hsCode: '8415.10.00',
    defaultUom: 'SET',
    cbmPerUnit: 0.35,
    grossWeightKg: 42.0,
    netWeightKg: 38.0,
    lastCustomsDutyPct: 0.10,
    lastVatPct: 0.14,
  );

  setUp(() {
    fakeRepo = FakeMasterItemsRepoForDialog();
    fakeRepo.items = [catalogItem];
  });

  group('POLineItemDialog Integration Tests (Task 14)', () {
    testWidgets('1. Dialog opens in Add mode with all sections and autocomplete',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createDialogTestApp(
          repository: fakeRepo,
          child: POLineItemDialog(
            tariffs: [sampleTariff],
            currencies: [sampleCurrency],
            defaultCurrencyId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Verify header and sections
      expect(find.text('إضافة بند جديد لأمر الشراء'), findsOneWidget);
      expect(find.text('استدعاء الصنف من الكاتالوج المركزي'), findsOneWidget);
      expect(find.text('الكمية *'), findsOneWidget);
      expect(find.text('سعر الوحدة (USD) *'), findsOneWidget);
      expect(find.text('الأوزان والأحجام اللوجستية (تعبئة تلقائية من الكاتالوج)'),
          findsOneWidget);
    });

    testWidgets('2. Dialog opens in Edit mode and loads existing line values',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final existingLine = POLineItemModel(
        itemId: 55,
        poId: 12,
        itemCode: 'OLD-CUSTOM-009',
        descriptionAr: 'صنف استيرادي قديم يدوي',
        descriptionEn: 'Old Manual Item',
        quantity: 10.0,
        unitOfMeasure: 'PCS',
        unitPrice: 25.50,
        cbmPerUnit: 0.12,
        grossWeightKg: 15.0,
        netWeightKg: 14.0,
      );

      await tester.pumpWidget(
        createDialogTestApp(
          repository: fakeRepo,
          child: POLineItemDialog(
            initialItem: existingLine,
            tariffs: [sampleTariff],
            currencies: [sampleCurrency],
            defaultCurrencyId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      // In edit mode
      expect(find.text('تعديل بند أمر الشراء'), findsOneWidget);
      expect(find.text('OLD-CUSTOM-009'), findsWidgets);
      expect(find.text('صنف استيرادي قديم يدوي'), findsOneWidget);
      expect(find.text('Old Manual Item'), findsOneWidget);
    });

    testWidgets('3. Catalog Fast Auto-fill: populates codes, descriptions, tariff, UOM, and dimensions',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createDialogTestApp(
          repository: fakeRepo,
          child: POLineItemDialog(
            tariffs: [sampleTariff],
            currencies: [sampleCurrency],
            defaultCurrencyId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Type in autocomplete field
      final autocompleteField = find.byType(TextFormField).first;
      await tester.enterText(autocompleteField, 'AC-INVERTER');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Tap suggestion in overlay
      final suggestion = find.text('تكييف هواء انفرتر 1.5 حصان');
      expect(suggestion, findsOneWidget);
      await tester.tap(suggestion);
      await tester.pumpAndSettle();

      // Success indicator visible
      expect(find.text('تم ملء بيانات الصنف تلقائياً من الكاتالوج'), findsOneWidget);

      // Verify fields pre-filled from catalog item
      expect(find.text('AC-INVERTER-12K'), findsWidgets);
      expect(find.text('Air Conditioner Inverter 12000 BTU'), findsOneWidget);

      // Verify logistics weights pre-filled
      expect(find.text('0.35'), findsOneWidget); // CBM
      expect(find.text('38'), findsOneWidget);   // Net Weight
      expect(find.text('42'), findsOneWidget);   // Gross Weight
    });

    testWidgets('4. Saving dialog returns valid updated POLineItemModel',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      POLineItemModel? capturedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            masterItemsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: _TestDialogHost(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap launch button
      await tester.tap(find.byKey(const ValueKey('launch_modal')));
      await tester.pumpAndSettle();

      // Enter required Arabic description
      final descField = find.widgetWithText(TextFormField, 'الوصف بالعربية *');
      expect(descField, findsOneWidget);
      await tester.enterText(descField, 'مضخة مياه غاطسة جديدة');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('إضافة البند');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify returned result from host
      final hostState = tester.state<_TestDialogHostState>(find.byType(_TestDialogHost));
      capturedResult = hostState.savedItem;

      expect(capturedResult, isNotNull);
      expect(capturedResult!.descriptionAr, equals('مضخة مياه غاطسة جديدة'));
      expect(capturedResult.quantity, equals(1.0));
    });
  });
}

class _TestDialogHost extends StatefulWidget {
  const _TestDialogHost();

  @override
  State<_TestDialogHost> createState() => _TestDialogHostState();
}

class _TestDialogHostState extends State<_TestDialogHost> {
  POLineItemModel? savedItem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        key: const ValueKey('launch_modal'),
        onPressed: () async {
          final res = await POLineItemDialog.show(context);
          setState(() {
            savedItem = res;
          });
        },
        child: const Text('Launch Modal'),
      ),
    );
  }
}
