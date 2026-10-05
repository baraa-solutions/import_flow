import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/widgets/warehouse_inspection_dialog.dart';

void main() {
  group('TR-04: Warehouse Inspection & Discrepancy Protocol Models Tests', () {
    test('WarehouseReceivingModel handles TR-04 inspection protocol fields correctly', () {
      final json = {
        'receiving_id': 99,
        'grn_code': 'GRN-2026-0099',
        'import_file_id': 105,
        'warehouse_name': 'Main Warehouse - Cairo (6th of October)',
        'arrival_datetime': '2026-09-18T12:00:00Z',
        'truck_plate_number': 'ط د ر 7541',
        'driver_name': 'Mohamed Ahmed',
        'seal_number': 'SEAL-8899',
        'seal_intact': true,
        'grn_items': [
          {
            'item_code': 'ITM-01',
            'item_name': 'Servers',
            'invoiced_qty': 100,
            'accepted_qty': 97,
            'shortage_qty': 1,
            'damaged_qty': 2,
            'quarantine_flag': false,
          },
          {
            'item_code': 'ITM-02',
            'item_name': 'Cables',
            'invoiced_qty': 50,
            'accepted_qty': 50,
            'shortage_qty': 0,
            'damaged_qty': 0,
            'quarantine_flag': false,
          },
        ],
        'total_invoiced_qty': 150,
        'total_accepted_qty': 147,
        'total_shortage_qty': 1,
        'total_damaged_qty': 2,
        'discrepancy_type': 'Shortage & Damaged',
        'discrepancy_notes': 'Damage during port handling',
        'quarantine_zone_assigned': false,
        'insurance_claim_filed': true,
        'insurance_claim_ref': 'CLM-2026-INS-0099',
        'inspection_date': '2026-09-18T13:00:00Z',
        'inspection_committee': 'لجنة الفحص الهندسي والمخزني',
        'inspection_protocol_number': 'INSP-2026-0099',
        'inspection_verdict': 'ACCEPTED_WITH_DISCREPANCY',
        'root_cause': 'Port Mishandling & Rough Transit Shock',
        'supplier_claim_filed': true,
        'supplier_claim_ref': 'CN-REQ-BAV-0099',
        'claim_amount_estimated': 35000.0,
        'claim_currency': 'EGP',
        'discrepancy_rate_percent': 2.0,
        'status': 'Discrepancy Reported',
        'inspector_name': 'Eng. Kamal',
        'notes': 'QC protocol approved',
        'is_active': true,
        'created_at': '2026-09-18T12:00:00Z',
        'updated_at': '2026-09-18T13:00:00Z',
      };

      final model = WarehouseReceivingModel.fromJson(json);

      expect(model.receivingId, 99);
      expect(model.grnCode, 'GRN-2026-0099');
      expect(model.inspectionProtocolNumber, 'INSP-2026-0099');
      expect(model.inspectionVerdict, 'ACCEPTED_WITH_DISCREPANCY');
      expect(model.rootCause, 'Port Mishandling & Rough Transit Shock');
      expect(model.supplierClaimFiled, isTrue);
      expect(model.supplierClaimRef, 'CN-REQ-BAV-0099');
      expect(model.claimAmountEstimated, 35000.0);
      expect(model.claimCurrency, 'EGP');
      expect(model.discrepancyRatePercent, 2.0);

      final serialized = model.toJson();
      expect(serialized['inspection_protocol_number'], 'INSP-2026-0099');
      expect(serialized['supplier_claim_filed'], isTrue);
      expect(serialized['discrepancy_rate_percent'], 2.0);
    });

    test('Discrepancy rate calculation check', () {
      const invoiced = 200;
      const shortage = 4;
      const damaged = 6;
      const totalDiscrepancy = shortage + damaged;
      const rate = (totalDiscrepancy / invoiced) * 100.0;

      expect(rate, equals(5.0));
    });
  });

  group('TR-04: Warehouse Inspection Dialog Widget Tests', () {
    testWidgets('Renders WarehouseInspectionDialog with KPIs and action buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleRecord = WarehouseReceivingModel(
        receivingId: 99,
        grnCode: 'GRN-2026-0099',
        importFileId: 105,
        warehouseName: 'Main Warehouse - Cairo',
        arrivalDatetime: '2026-09-18T12:00:00Z',
        truckPlateNumber: 'ط د ر 7541',
        driverName: 'Mohamed Ahmed',
        grnItems: [
          GrnItemModel(
            itemCode: 'SRV-01',
            itemName: 'Servers',
            invoicedQty: 100,
            acceptedQty: 97,
            shortageQty: 1,
            damagedQty: 2,
          ),
        ],
        totalInvoicedQty: 100,
        totalAcceptedQty: 97,
        totalShortageQty: 1,
        totalDamagedQty: 2,
        inspectionProtocolNumber: 'INSP-2026-0099',
        inspectionVerdict: 'ACCEPTED_WITH_DISCREPANCY',
        rootCause: 'Port Handling & Rough Unloading',
        discrepancyRatePercent: 3.0,
        status: 'Discrepancy Reported',
        inspectorName: 'Kamal',
        createdAt: '2026-09-18T12:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: WarehouseInspectionDialog(
                  record: sampleRecord,
                  importFileCode: 'IMP-2026-0099',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Dialog Title
      expect(find.text('محضر الفحص الفني ومطابقة العجز والتالف (TR-04)'), findsOneWidget);

      // Check Export Button
      expect(find.byKey(const Key('exportInspectionProtocolBtn')), findsOneWidget);

      // Check Certify Button
      expect(find.byKey(const Key('certifyInspectionProtocolBtn')), findsOneWidget);

      // Check KPI Metric Strip
      // l10n migration: the strip uses the shared warehouseReceivingMetric* keys
      // (short labels that also appear elsewhere, so scope to the strip).
      final strip = find.byKey(const Key('inspectionMetricStrip'));
      Finder inStrip(String text) => find.descendant(of: strip, matching: find.text(text));
      expect(strip, findsOneWidget);
      expect(inStrip('الفاتورة'), findsOneWidget); // warehouseReceivingMetricInvoiced
      expect(inStrip('المقبول'), findsOneWidget); // warehouseReceivingMetricAccepted
      expect(inStrip('العجز'), findsOneWidget); // warehouseReceivingMetricShortage
      expect(inStrip('التلف'), findsOneWidget); // warehouseReceivingMetricDamaged
      expect(inStrip('نسبة الفروقات'), findsOneWidget); // wrInspMetricRate

      // Check Item In Table
      expect(find.text('SRV-01'), findsOneWidget);
      expect(find.text('Servers'), findsOneWidget);

      // Check Claims Header
      expect(find.text('إجراءات المطالبات والتعويضات والعزل:'), findsOneWidget);
    });
  });
}
