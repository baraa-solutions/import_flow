import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/services/final_duty_payment_export_service.dart';

void main() {
  group('FinalDutyPaymentExportService Unit Tests', () {
    final sampleRecords = [
      CustomsClearanceModel(
        customsClearanceId: 101,
        clearanceCode: 'CLR-2026-0001',
        importFileId: 10,
        declaration46No: 'DEC-46-8899',
        customsOfficeName: 'Alexandria Port Customs',
        channelType: 'Green Channel',
        actualDutyTotal: 154200.0,
        estimatedDutyTotal: 150000.0,
        dutyVarianceAmount: 4200.0,
        dutyVariancePercentage: 2.8,
        paymentStatus: 'Paid & Verified',
        bankReceiptNo: 'RCP-BNK-9901',
        releasePermitNo: 'REL-2026-001',
        status: 'Final Release Granted',
        createdAt: '2026-09-01T10:00:00Z',
        updatedAt: '2026-09-02T12:00:00Z',
      ),
      CustomsClearanceModel(
        customsClearanceId: 102,
        clearanceCode: 'CLR-2026-0002',
        importFileId: 12,
        declaration46No: 'DEC-46-9900',
        customsOfficeName: 'Dekheila Port Customs',
        channelType: 'Red Channel',
        nafezaClaimNumber: 'CLM-NFZ-7781',
        totalDutyPayable: 210000.0,
        actualDutyTotal: 0.0,
        estimatedDutyTotal: 215000.0,
        dutyVarianceAmount: -5000.0,
        dutyVariancePercentage: -2.3,
        paymentStatus: 'Pending Payment',
        status: 'Duty Requested',
        createdAt: '2026-09-03T10:00:00Z',
        updatedAt: '2026-09-03T12:00:00Z',
      ),
    ];

    Widget buildTestWidget({Locale locale = const Locale('ar')}) {
      return MaterialApp(
        home: AppLocalizationsProvider(
          locale: locale,
          child: const Scaffold(body: SizedBox()),
        ),
      );
    }

    testWidgets('exportFinalDutyToTsv formats UTF-8 BOM and correct tab columns', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      final context = tester.element(find.byType(SizedBox));

      final tsv = FinalDutyPaymentExportService.exportFinalDutyToTsv(context, sampleRecords);
      expect(tsv.startsWith('\uFEFF'), isTrue, reason: 'Must include UTF-8 BOM');
      expect(tsv.contains('CLR-2026-0001'), isTrue);
      expect(tsv.contains('DEC-46-8899'), isTrue);
      expect(tsv.contains('RCP-BNK-9901'), isTrue);
      expect(tsv.contains('REL-2026-001'), isTrue);
      expect(tsv.contains('CLR-2026-0002'), isTrue);
      expect(tsv.contains('DEC-46-9900'), isTrue);

      final lines = tsv.trim().split('\n');
      expect(lines.length, equals(3)); // 1 header + 2 records
    });

    testWidgets('exportFinalDutyToCsv formats UTF-8 BOM and standard RFC 4180 CSV', (tester) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      final context = tester.element(find.byType(SizedBox));

      final csv = FinalDutyPaymentExportService.exportFinalDutyToCsv(context, sampleRecords);
      expect(csv.startsWith('\uFEFF'), isTrue, reason: 'Must include UTF-8 BOM');
      expect(csv.contains('CLR-2026-0001'), isTrue);
      expect(csv.contains('DEC-46-8899'), isTrue);
      expect(csv.contains('Alexandria Port Customs'), isTrue);
      expect(csv.contains('Paid & Verified'), isTrue);
    });

    testWidgets('buildFinalDutyDossier formats structured summary and KPIs', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      final context = tester.element(find.byType(SizedBox));

      final dossier = FinalDutyPaymentExportService.buildFinalDutyDossier(
        context: context,
        records: sampleRecords,
      );
      expect(dossier, isNotEmpty);
      expect(dossier.contains('CLR-2026-0001'), isTrue);
      expect(dossier.contains('RCP-BNK-9901'), isTrue);
      expect(dossier.contains('CLR-2026-0002'), isTrue);
      // KPIs (FE07-T07): paid = 154200.00; outstanding = assessed unpaid duty (claim number set) = 210000.00
      expect(dossier.contains('154200.00'), isTrue);
      expect(dossier.contains('210000.00'), isTrue);
    });

    testWidgets('Empty records list is handled gracefully without errors', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      final context = tester.element(find.byType(SizedBox));

      final tsv = FinalDutyPaymentExportService.exportFinalDutyToTsv(context, []);
      expect(tsv.startsWith('\uFEFF'), isTrue);

      final csv = FinalDutyPaymentExportService.exportFinalDutyToCsv(context, []);
      expect(csv.startsWith('\uFEFF'), isTrue);

      final dossier = FinalDutyPaymentExportService.buildFinalDutyDossier(
        context: context,
        records: [],
      );
      expect(dossier.contains('لا توجد مطالبات سداد'), isTrue);
    });
  });
}
