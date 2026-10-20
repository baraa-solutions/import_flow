import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/services/po_export_helper.dart';

Widget _buildTestWidget({required Widget Function(BuildContext) builder}) {
  return MaterialApp(
    home: AppLocalizationsProvider(
      locale: const Locale('en'),
      child: Builder(builder: builder),
    ),
  );
}

void main() {
  group('FE01-T05: buildPoExportRows and buildPoExportHeaders tests', () {
    testWidgets('assert columns, ordering, and that missing names render "—"', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(
        _buildTestWidget(
          builder: (ctx) {
            testContext = ctx;
            return const SizedBox();
          },
        ),
      );

      final l = testContext.l10n;
      final headers = buildPoExportHeaders(l);

      expect(headers, [
        l.poReferenceCol,
        l.foreignSupplier,
        l.projectsAndCostCenters,
        l.totalFobMetric,
        l.totalCargoCbmMetric,
        l.totalGrossWeightMetric,
        l.statusCol,
      ]);

      final orders = <PurchaseOrderModel>[
        PurchaseOrderModel(
          poNumber: 'PO-2026-001',
          supplierName: 'Global Turbines Ltd',
          projectName: 'Suez Expansion',
          projectId: 1,
          companyId: 1,
          supplierId: 1,
          incotermId: 1,
          currencyId: 1,
          totalAmountFob: 15450.50,
          totalCbm: 12.34,
          totalGrossWeightKg: 850.5,
          status: 'APPROVED',
        ),
        PurchaseOrderModel(
          poNumber: '', // Empty reference
          supplierName: null, // Missing supplier
          projectName: null, // Missing project
          projectId: 2,
          companyId: 1,
          supplierId: 2,
          incotermId: 1,
          currencyId: 1,
          totalAmountFob: 0.0,
          totalCbm: 0.0,
          totalGrossWeightKg: 0.0,
          status: 'DRAFT',
        ),
      ];

      final rows = buildPoExportRows(orders, l);

      expect(rows.length, 2);

      // Row 1 assertions (all fields present)
      final row1 = rows[0];
      expect(row1[0], 'PO-2026-001');
      expect(row1[1], 'Global Turbines Ltd');
      expect(row1[2], 'Suez Expansion');
      expect(row1[3], '15450.50');
      expect(row1[4], '12.34 m³');
      expect(row1[5], '850.5 kg');
      expect(row1[6], 'Approved');

      // Row 2 assertions (missing fields render "—")
      final row2 = rows[1];
      expect(row2[0], '—');
      expect(row2[1], '—');
      expect(row2[2], '—');
      expect(row2[3], '0.00');
      expect(row2[4], '0.00 m³');
      expect(row2[5], '0.0 kg');
      expect(row2[6], 'Draft');
    });
  });
}
