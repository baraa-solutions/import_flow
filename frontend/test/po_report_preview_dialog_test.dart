import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/widgets/po_report_preview_dialog.dart';

void main() {
  test('packing row weights are recomputed from qty_pkg x unit weight at full precision', () {
    final row = PackingListItemModel(
      itemCode: 'ITEM-9',
      hsCode: '9403100000',
      qtyPkg: 4.0,
      qtyPcs: 40.0,
      grossWeightUnitKg: 12.3456789012345678,
      netWeightUnitKg: 10.25,
      totalGrossWeightKg: 999.0, // stale (as extracted before the user edited the row)
      totalNetWeightKg: 888.0,
    );
    expect(row.computedTotalGrossWeightKg, 4.0 * 12.3456789012345678);
    expect(row.computedTotalNetWeightKg, 41.0);
  });

  testWidgets('preview gross weight follows the current rows, not a stale stored total', (tester) async {
    final packing = [
      PackingListItemModel(
        itemCode: 'ITEM-9',
        hsCode: '9403100000',
        packageType: 'Carton',
        qtyPkg: 4.0,
        qtyPcs: 40.0,
        grossWeightUnitKg: 12.3456789012345678,
        netWeightUnitKg: 10.25,
        totalGrossWeightKg: 999.0,
        totalNetWeightKg: 888.0,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: AppLocalizationsProvider(
          locale: const Locale('en'),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => POReportPreviewDialog.show(
                  context: context,
                  poNumber: 'PO-W',
                  orderDate: DateTime(2026, 10, 5),
                  companyName: 'Co',
                  supplierName: 'Sup',
                  incoterm: 'FOB',
                  currency: 'USD',
                  exchangeRate: 1.0,
                  items: [POLineItemModel(itemCode: 'ITEM-9', descriptionAr: 'x', quantity: 40, unitPrice: 1)],
                  packingItems: packing,
                  palletItems: const [],
                  initialLocale: const Locale('en'),
                ),
                child: const Text('Open Preview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Preview'));
    await tester.pumpAndSettle();

    // 4 x 12.3456789012345678 = 49.3827... -> displayed rounded to 3 decimals.
    expect(find.textContaining('49.383'), findsWidgets);
    expect(find.textContaining('999'), findsNothing);
    expect(find.textContaining('888'), findsNothing);
  });

  testWidgets('POReportPreviewDialog calculates total amount and grand total correctly even with default totalPrice', (WidgetTester tester) async {
    final sampleItems = [
      POLineItemModel(
        itemId: 1,
        itemCode: 'ITEM-001',
        mainDescription: 'أثاث مكتبي رئيسي',
        descriptionAr: 'طاولة مكتبية',
        descriptionEn: 'Office Table',
        quantity: 100.0,
        unitOfMeasure: 'PCS',
        unitPrice: 60.70,
        // Notice totalPrice is not passed, will default to 100 * 60.70 = 6070.0
      ),
      POLineItemModel(
        itemId: 2,
        itemCode: 'ITEM-002',
        mainDescription: 'كراسي مكتبية',
        descriptionAr: 'كرسي مريح',
        descriptionEn: 'Ergonomic Chair',
        quantity: 50.0,
        unitOfMeasure: 'PCS',
        unitPrice: 20.00,
        // Notice totalPrice is not passed, will default to 50 * 20.00 = 1000.0
      ),
    ];

    final samplePacking = [
      PackingListItemModel(
        itemCode: 'ITEM-001',
        mainDescription: 'أثاث مكتبي رئيسي',
        hsCode: '9403100000',
        description: 'طاولة مكتبية',
        qtyPkg: 10.0,
        qtyPcs: 100.0,
        packageType: 'Carton',
        totalGrossWeightKg: 500.0,
        totalNetWeightKg: 450.0,
        totalCbm: 2.5,
      ),
    ];

    final samplePallets = [
      PalletPlanItemModel(
        palletType: 'Euro Pallet (120x80)',
        palletCount: 2,
        lengthCm: 120.0,
        widthCm: 80.0,
        heightCm: 150.0,
        grossWeightPerPalletKg: 250.0,
        isStackable: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AppLocalizationsProvider(
          locale: const Locale('ar'),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  POReportPreviewDialog.show(
                    context: context,
                    poNumber: 'PO-2026-TEST',
                    piNumber: 'PI-9988',
                    acidNumber: '7595528271020210010',
                    orderDate: DateTime(2026, 8, 23),
                    companyName: 'Archi Brands for Trading',
                    companyTaxId: '100200300',
                    supplierName: 'UAB Narbutas International',
                    supplierCountry: 'Lithuania',
                    incoterm: 'EXW',
                    currency: 'USD',
                    exchangeRate: 50.00,
                    items: sampleItems,
                    packingItems: samplePacking,
                    palletItems: samplePallets,
                    initialLocale: const Locale('ar'),
                  );
                },
                child: const Text('Open Preview'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap button to open report preview
    await tester.tap(find.text('Open Preview'));
    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('معاينة تقرير أمر الشراء وقائمة التعبئة المعتمدة'), findsOneWidget);
    expect(find.textContaining('PO-2026-TEST'), findsWidgets);
    expect(find.textContaining('PI-9988'), findsWidgets);
    expect(find.text('Archi Brands for Trading'), findsOneWidget);

    // Verify Multiplication & Totals:
    // Item 1: 100 * 60.70 = 6070.00 USD
    expect(find.text('6070.00 USD'), findsOneWidget);
    // Item 2: 50 * 20.00 = 1000.00 USD
    expect(find.text('1000.00 USD'), findsOneWidget);
    // Grand Total: 6070 + 1000 = 7070.00 USD
    expect(find.text('7070.00 USD'), findsNWidgets(2)); // Badge + Table Grand Total row

    // Verify Main Description in Arabic
    expect(find.text('الوصف الرئيسي'), findsWidgets);
    expect(find.text('أثاث مكتبي رئيسي'), findsWidgets);
    expect(find.text('كراسي مكتبية'), findsOneWidget);

    // Test Language Switcher button: switch to English
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Check that UI is now in English
    expect(find.text('Purchase Order & Packing List Preview'), findsOneWidget);
    expect(find.text('Main Description'), findsWidgets);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(find.text('Copy Report Text'), findsOneWidget);
    expect(find.text('Save & Approve Purchase Order'), findsOneWidget);
    expect(find.text('7070.00 USD'), findsNWidgets(2));
    // Packing total: each count printed once (was "10 10 pkgs / 100 100 pcs").
    expect(find.text('10 pkgs / 100 pcs'), findsOneWidget);
    expect(find.textContaining('10 10 pkgs'), findsNothing);

    // Switch back to Arabic
    expect(find.text('العربية'), findsOneWidget);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('معاينة تقرير أمر الشراء وقائمة التعبئة المعتمدة'), findsOneWidget);
    expect(find.text('الوصف الرئيسي'), findsWidgets);
    expect(find.text('الإجمالي الكلي'), findsOneWidget);
  });
}
