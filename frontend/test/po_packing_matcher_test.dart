import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/utils/po_packing_matcher.dart';

void main() {
  group('PoPackingMatcher Tests', () {
    test('User Real Scenario: Resolves CYK4R6018210001 and QCR12026802R without duplicating row 1 into row 2', () {
      final List<POLineItemModel> poItems = [
        POLineItemModel(
          itemCode: 'CYK4R6018210001',
          mainDescription: 'RTAXT/K/EC/MS 182-1830KW',
          descriptionAr: 'جهاز تكييف مركزي مبرد',
          hsCode: '8415820010',
          quantity: 1.0,
          unitOfMeasure: 'PCS',
          unitPrice: 50000.0,
          totalPrice: 50000.0,
        ),
        POLineItemModel(
          itemCode: 'QCR12026802R',
          mainDescription: 'QCR12026802R Spare Module',
          descriptionAr: 'وحدة كارت الكتروني قطع غيار',
          hsCode: '8415820010',
          quantity: 1.0,
          unitOfMeasure: 'PCS',
          unitPrice: 200.0,
          totalPrice: 200.0,
        ),
      ];

      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: 'CYK4R6018210001',
          mainDescription: 'RTAXT/K/EC/MS 182-1830KW',
          hsCode: '8415820010',
          qtyPkg: 2.0,
          lengthCm: 395.0,
          widthCm: 225.0,
          heightCm: 225.0,
          unit: 'cm',
          netWeightUnitKg: 1125.0,
          grossWeightUnitKg: 1135.0,
          totalNetWeightKg: 2250.0,
          totalGrossWeightKg: 2270.0,
          totalCbm: 39.994,
        ),
        PackingListItemModel(
          itemCode: 'QCR12026802R',
          mainDescription: 'QCR12026802R',
          hsCode: '8415820010',
          qtyPkg: 2.0,
          lengthCm: 27.5,
          widthCm: 26.5,
          heightCm: 16.0,
          unit: 'cm',
          netWeightUnitKg: 2.0,
          grossWeightUnitKg: 2.0,
          totalNetWeightKg: 4.0,
          totalGrossWeightKg: 4.0,
          totalCbm: 0.023,
        ),
      ];

      final resolved = PoPackingMatcher.resolvePoItemMetrics(
        items: poItems,
        packingListItems: packingItems,
        isPalletized: false,
      );

      expect(resolved.length, 2);

      // Item 1 (CYK4R6018210001)
      final r1 = resolved[0];
      expect(r1.item.itemCode, 'CYK4R6018210001');
      expect(r1.hasMatchedPacking, isTrue);
      expect(r1.cbm, closeTo(39.994, 0.001));
      expect(r1.netWeightKg, 2250.0);
      expect(r1.grossWeightKg, 2270.0);
      expect(r1.qtyPkg, 2);

      // Item 2 (QCR12026802R) - MUST NOT duplicate Item 1
      final r2 = resolved[1];
      expect(r2.item.itemCode, 'QCR12026802R');
      expect(r2.hasMatchedPacking, isTrue);
      expect(r2.cbm, closeTo(0.023, 0.001));
      expect(r2.netWeightKg, 4.0);
      expect(r2.grossWeightKg, 4.0);
      expect(r2.qtyPkg, 2);

      // Summary By HS Code must match exact real totals (40.017 m³, 2254 kg, 2274 kg)
      final summaryMap = PoPackingMatcher.buildPoHsSummaryMap(resolved);
      expect(summaryMap.containsKey('8415820010'), isTrue);
      final hsSummary = summaryMap['8415820010']!;

      expect(hsSummary['total_cbm'], closeTo(40.017, 0.002));
      expect(hsSummary['total_net'], 2254.0);
      expect(hsSummary['total_gross'], 2274.0);
      expect(hsSummary['qty_pkg'], 4);
    });

    test('Palletized shipments set qtyPkg to 0 for items and summary', () {
      final List<POLineItemModel> poItems = [
        POLineItemModel(
          itemCode: 'ITEM-A',
          descriptionAr: 'صنف أ',
          hsCode: '8415820010',
          quantity: 10.0,
          totalPrice: 1000.0,
        ),
      ];
      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: 'ITEM-A',
          hsCode: '8415820010',
          qtyPkg: 5.0,
          totalNetWeightKg: 100.0,
          totalGrossWeightKg: 120.0,
          totalCbm: 1.5,
        ),
      ];

      final resolved = PoPackingMatcher.resolvePoItemMetrics(
        items: poItems,
        packingListItems: packingItems,
        isPalletized: true,
      );

      expect(resolved[0].qtyPkg, 0);
      final summary = PoPackingMatcher.buildPoHsSummaryMap(resolved);
      expect(summary['8415820010']!['qty_pkg'], 0);
    });

    test('Multiple packing packages for a single PO item are aggregated correctly', () {
      final List<POLineItemModel> poItems = [
        POLineItemModel(
          itemCode: 'BIG-MACHINE',
          descriptionAr: 'ماكينة كبيرة',
          hsCode: '8418690000',
          quantity: 1.0,
          totalPrice: 90000.0,
        ),
      ];
      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: 'BIG-MACHINE',
          mainDescription: 'Crate 1: Frame',
          hsCode: '8418690000',
          qtyPkg: 1.0,
          totalNetWeightKg: 1000.0,
          totalGrossWeightKg: 1050.0,
          totalCbm: 10.0,
        ),
        PackingListItemModel(
          itemCode: 'BIG-MACHINE',
          mainDescription: 'Crate 2: Compressor',
          hsCode: '8418690000',
          qtyPkg: 1.0,
          totalNetWeightKg: 500.0,
          totalGrossWeightKg: 520.0,
          totalCbm: 5.0,
        ),
      ];

      final resolved = PoPackingMatcher.resolvePoItemMetrics(
        items: poItems,
        packingListItems: packingItems,
        isPalletized: false,
      );

      expect(resolved.length, 1);
      expect(resolved[0].qtyPkg, 2);
      expect(resolved[0].netWeightKg, 1500.0);
      expect(resolved[0].grossWeightKg, 1570.0);
      expect(resolved[0].cbm, 15.0);
    });

    test('Sequential 1-to-1 match for remaining items without code match prevents duplicate attribution', () {
      final List<POLineItemModel> poItems = [
        POLineItemModel(
          itemCode: 'UNKNOWN-1',
          descriptionAr: 'عنصر غير معروف 1',
          hsCode: '8415820010',
          quantity: 1.0,
          totalPrice: 100.0,
        ),
        POLineItemModel(
          itemCode: 'UNKNOWN-2',
          descriptionAr: 'عنصر غير معروف 2',
          hsCode: '8415820010',
          quantity: 1.0,
          totalPrice: 200.0,
        ),
      ];
      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: 'PKG-A',
          hsCode: '8415820010',
          qtyPkg: 1.0,
          totalNetWeightKg: 50.0,
          totalGrossWeightKg: 60.0,
          totalCbm: 1.0,
        ),
        PackingListItemModel(
          itemCode: 'PKG-B',
          hsCode: '8415820010',
          qtyPkg: 1.0,
          totalNetWeightKg: 80.0,
          totalGrossWeightKg: 90.0,
          totalCbm: 2.0,
        ),
      ];

      final resolved = PoPackingMatcher.resolvePoItemMetrics(
        items: poItems,
        packingListItems: packingItems,
        isPalletized: false,
      );

      expect(resolved[0].netWeightKg, 50.0);
      expect(resolved[0].cbm, 1.0);
      expect(resolved[1].netWeightKg, 80.0);
      expect(resolved[1].cbm, 2.0);

      final summary = PoPackingMatcher.buildPoHsSummaryMap(resolved);
      expect(summary['8415820010']!['total_net'], 130.0);
      expect(summary['8415820010']!['total_gross'], 150.0);
      expect(summary['8415820010']!['total_cbm'], 3.0);
    });

    test('User Case with PLT - Pallet (بالتة) resolves packageType and formatPackagingSummary without hardcoding cartons', () {
      final List<POLineItemModel> poItems = [
        POLineItemModel(
          itemCode: '334441',
          descriptionAr: 'BATT COND 3/8 4200X1770X3R PA2.1',
          hsCode: '8419500000',
          quantity: 1.0,
          totalPrice: 4609.0,
        ),
      ];
      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: '334441',
          hsCode: '8419500000',
          packageType: 'PLT - Pallet (بالتة)',
          qtyPkg: 1.0,
          totalNetWeightKg: 208.0,
          totalGrossWeightKg: 498.0,
          totalCbm: 8.354,
        ),
      ];

      final resolved = PoPackingMatcher.resolvePoItemMetrics(
        items: poItems,
        packingListItems: packingItems,
      );

      expect(resolved[0].packageType, 'PLT - Pallet (بالتة)');

      // Header summary must be "1 x PLT - Pallet (بالتة)" and never mention cartons
      final headerSummary = PoPackingMatcher.formatPackagingSummary(
        packingListItems: packingItems,
        isArabic: false,
      );
      expect(headerSummary, '1 x PLT - Pallet (بالتة)');
      expect(headerSummary.toLowerCase().contains('carton'), isFalse);
    });

    test('Mixed Packaging header format: "1 x Pallet, 10 x CTN, 2 x Box (Total: 13 Pkgs)"', () {
      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: 'A',
          hsCode: '1111',
          packageType: 'Pallet',
          qtyPkg: 1.0,
        ),
        PackingListItemModel(
          itemCode: 'B',
          hsCode: '2222',
          packageType: 'CTN',
          qtyPkg: 10.0,
        ),
        PackingListItemModel(
          itemCode: 'C',
          hsCode: '3333',
          packageType: 'Box',
          qtyPkg: 2.0,
        ),
      ];

      final headerSummaryEn = PoPackingMatcher.formatPackagingSummary(
        packingListItems: packingItems,
        isArabic: false,
      );
      expect(headerSummaryEn, '1 x Pallet, 10 x CTN, 2 x Box (Total: 13 Pkgs)');

      final headerSummaryAr = PoPackingMatcher.formatPackagingSummary(
        packingListItems: packingItems,
        isArabic: true,
      );
      expect(headerSummaryAr, '1 x Pallet, 10 x CTN, 2 x Box (الإجمالي: 13 طرد)');
    });

    test('Packing List Summary By Package Type aggregates packages, weights, and CBM accurately', () {
      final List<PackingListItemModel> packingItems = [
        PackingListItemModel(
          itemCode: 'P1',
          hsCode: '1111',
          packageType: 'Pallet',
          qtyPkg: 2.0,
          totalNetWeightKg: 500.0,
          totalGrossWeightKg: 550.0,
          totalCbm: 4.5,
        ),
        PackingListItemModel(
          itemCode: 'P2',
          hsCode: '1111',
          packageType: 'Pallet',
          qtyPkg: 1.0,
          totalNetWeightKg: 250.0,
          totalGrossWeightKg: 280.0,
          totalCbm: 2.0,
        ),
        PackingListItemModel(
          itemCode: 'C1',
          hsCode: '2222',
          packageType: 'Carton',
          qtyPkg: 5.0,
          totalNetWeightKg: 50.0,
          totalGrossWeightKg: 55.0,
          totalCbm: 0.5,
        ),
      ];

      final summaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(packingItems);

      expect(summaryMap.containsKey('Pallet'), isTrue);
      expect(summaryMap.containsKey('Carton'), isTrue);

      final palletSummary = summaryMap['Pallet']!;
      expect(palletSummary['qty_pkg'], 3);
      expect(palletSummary['total_net'], 750.0);
      expect(palletSummary['total_gross'], 830.0);
      expect(palletSummary['total_cbm'], 6.5);

      final cartonSummary = summaryMap['Carton']!;
      expect(cartonSummary['qty_pkg'], 5);
      expect(cartonSummary['total_net'], 50.0);
      expect(cartonSummary['total_gross'], 55.0);
      expect(cartonSummary['total_cbm'], 0.5);
    });

    test('High-precision fractional weight calculation: 144 ctns / 10510 kg sums to exact 10510 kg without 72.99 rounding corruption', () {
      const double totalCertGross = 10510.0;
      const double totalPackages = 144.0;
      const double unitGross = totalCertGross / totalPackages; // 72.98611111111111
      const double unitNet = 70.0;

      final itemCodes = ['YH-652', 'YH-644', 'YH-610', 'YH-612', 'YH-646', 'YH-656', 'YH-658'];
      final packageCounts = [20.0, 20.0, 24.0, 20.0, 20.0, 20.0, 20.0]; // Sum = 144.0

      final List<POLineItemModel> poItems = [
        for (int i = 0; i < itemCodes.length; i++)
          POLineItemModel(
            itemCode: itemCodes[i],
            mainDescription: 'Acoustic Panels',
            descriptionAr: 'بانوهات صوتية',
            hsCode: '5602290000',
            quantity: packageCounts[i] * 5,
            unitOfMeasure: 'PCS',
            unitPrice: 60.7,
            totalPrice: packageCounts[i] * 5 * 60.7,
          ),
      ];

      final List<PackingListItemModel> packingItems = [
        for (int i = 0; i < itemCodes.length; i++)
          PackingListItemModel(
            itemCode: itemCodes[i],
            hsCode: '5602290000',
            qtyPkg: packageCounts[i],
            netWeightUnitKg: unitNet,
            grossWeightUnitKg: unitGross,
            totalNetWeightKg: packageCounts[i] * unitNet,
            totalGrossWeightKg: packageCounts[i] * unitGross,
            totalCbm: 9.221,
          ),
      ];

      final resolved = PoPackingMatcher.resolvePoItemMetrics(
        items: poItems,
        packingListItems: packingItems,
        isPalletized: false,
      );

      expect(resolved.length, 7);

      // Verify each 20-carton item gross weight is unrounded ~1459.722222
      for (int i = 0; i < 7; i++) {
        if (i == 2) {
          // 24 cartons
          expect(resolved[i].grossWeightKg, closeTo(1751.666666, 1e-4));
        } else {
          // 20 cartons
          expect(resolved[i].grossWeightKg, closeTo(1459.722222, 1e-4));
        }
      }

      // Verify HS Code summary totals snap exactly to 10510.0 and NOT 10510.56 or 10509.99
      final hsSummary = PoPackingMatcher.buildPoHsSummaryMap(resolved);
      expect(hsSummary.containsKey('5602290000'), isTrue);
      expect(hsSummary['5602290000']!['total_gross'], 10510.0);
      expect(hsSummary['5602290000']!['total_net'], 10080.0);
      expect(hsSummary['5602290000']!['qty_pkg'], 144);

      // Verify Package Type summary totals
      final pkgSummary = PoPackingMatcher.buildPackingTypeSummaryMap(packingItems);
      expect(pkgSummary['Carton']!['total_gross'], 10510.0);
      expect(pkgSummary['Carton']!['total_net'], 10080.0);
      expect(pkgSummary['Carton']!['qty_pkg'], 144);
    });

    test('PoPackingMatcher.formatWeight truncates display to 3 decimal places and trims trailing zeros', () {
      expect(PoPackingMatcher.formatWeight(72.98611111), '72.986');
      expect(PoPackingMatcher.formatWeight(1459.722222), '1459.722');
      expect(PoPackingMatcher.formatWeight(1751.666667), '1751.667');
      expect(PoPackingMatcher.formatWeight(10510.0), '10510');
      expect(PoPackingMatcher.formatWeight(1400.0), '1400');
      expect(PoPackingMatcher.formatWeight(10509.999999), '10510');
      expect(PoPackingMatcher.formatWeight(0.0), '0');
      expect(PoPackingMatcher.formatWeight(50.5), '50.5');
      expect(PoPackingMatcher.formatWeight(50.50), '50.5');
      expect(PoPackingMatcher.formatWeight(50.555), '50.555');
    });
  });
}
