import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/final_duty_payment_tab.dart';

void main() {
  group('Screen 62: FinalDutyPaymentTab Widget Tests', () {
    final mockRecords = [
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

    Widget createTestWidget({
      List<CustomsClearanceModel>? records,
      Locale locale = const Locale('ar'),
      void Function(CustomsClearanceModel)? onPay,
      void Function(CustomsClearanceModel)? onRelease,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: AppLocalizationsProvider(
            locale: locale,
            child: Scaffold(
              body: FinalDutyPaymentTab(
                records: records ?? mockRecords,
                onPay: onPay,
                onRelease: onRelease,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders within root SelectionArea', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
    });

    testWidgets('Renders responsive header banner and 4-action export toolbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('منظومة سداد الرسوم والضرائب الجمركية وإذن الإفراج النهائي'), findsOneWidget);
      expect(find.text('تصدير جدول'), findsOneWidget);
      expect(find.text('تصدير إكسل'), findsOneWidget);
      expect(find.text('طباعة تقرير'), findsOneWidget);
      expect(find.text('نسخ الحافظة'), findsOneWidget);
    });

    testWidgets('Renders 4 KPI summary cards with computed financial totals', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Design refresh: currency moved into the KPI titles; KPI values use
      // CcFormat.money (thousands separators, no currency suffix).
      expect(find.text('إجمالي الرسوم المطلوبة (جنيه)'), findsOneWidget);
      expect(find.text('إجمالي الرسوم المسددة (جنيه)'), findsOneWidget);
      expect(find.text('مطالبات قيد السداد'), findsOneWidget);
      expect(find.text('صافي الفروقات الجمركية (جنيه)'), findsOneWidget);

      // Total payable = 154200 + 210000 = 364,200.00
      expect(find.text('364,200.00'), findsOneWidget);
      // Total paid appears in the KPI card and (with currency) in row 1
      expect(find.text('154,200.00'), findsOneWidget);
      expect(find.text('154,200.00 جنيه مصري'), findsOneWidget);
      // Pending count = 1
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Renders DataTable rows with badges and copyable cells', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('CLR-2026-0001'), findsOneWidget);
      expect(find.text('DEC-46-8899'), findsOneWidget);
      expect(find.text('Alexandria Port Customs'), findsOneWidget);
      expect(find.text('RCP-BNK-9901'), findsOneWidget);
      expect(find.text('REL-2026-001'), findsOneWidget);

      expect(find.text('CLR-2026-0002'), findsOneWidget);
      expect(find.text('DEC-46-9900'), findsOneWidget);
      expect(find.text('Dekheila Port Customs'), findsOneWidget);
    });

    testWidgets('Search input filters table records', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('CLR-2026-0001'), findsOneWidget);
      expect(find.text('CLR-2026-0002'), findsOneWidget);

      // Enter search query for Alexandria
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Alexandria');
      await tester.pumpAndSettle();

      expect(find.text('CLR-2026-0001'), findsOneWidget);
      expect(find.text('CLR-2026-0002'), findsNothing);
    });

    testWidgets('Filter chips filter records by status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap "تم السداد" chip
      await tester.tap(find.text('تم السداد'));
      await tester.pumpAndSettle();

      expect(find.text('CLR-2026-0001'), findsOneWidget);
      expect(find.text('CLR-2026-0002'), findsNothing);

      // Tap "قيد السداد" chip
      await tester.tap(find.text('قيد السداد'));
      await tester.pumpAndSettle();

      expect(find.text('CLR-2026-0001'), findsNothing);
      expect(find.text('CLR-2026-0002'), findsOneWidget);
    });

    testWidgets('Triggers onPay and onRelease callbacks correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      CustomsClearanceModel? paidRecord;
      CustomsClearanceModel? releasedRecord;

      await tester.pumpWidget(createTestWidget(
        onPay: (r) => paidRecord = r,
        onRelease: (r) => releasedRecord = r,
      ));
      await tester.pumpAndSettle();

      // Scroll to Pay button in horizontally scrollable table
      final payBtn = find.text('تفاصيل السداد');
      await tester.ensureVisible(payBtn);
      await tester.pumpAndSettle();
      await tester.tap(payBtn);
      await tester.pumpAndSettle();
      expect(paidRecord, isNotNull);
      expect(paidRecord!.clearanceCode, equals('CLR-2026-0001'));

      // Scroll to Final Release button for record 1
      final releaseBtns = find.text('الإفراج النهائي');
      await tester.ensureVisible(releaseBtns.first);
      await tester.pumpAndSettle();
      await tester.tap(releaseBtns.first);
      await tester.pumpAndSettle();
      expect(releasedRecord, isNotNull);
      expect(releasedRecord!.clearanceCode, equals('CLR-2026-0001'));
    });

    testWidgets('Renders cleanly in English locale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Final Customs Duty Payment & Release Hub'), findsOneWidget);
      expect(find.text('Total Duties Payable (EGP)'), findsOneWidget);
      expect(find.text('Total Duties Paid (EGP)'), findsOneWidget);
      expect(find.text('Pending Settlements'), findsOneWidget);
      expect(find.text('Net Duty Variance (EGP)'), findsOneWidget);
      expect(find.text('Export TSV'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
      expect(find.text('Print PDF'), findsOneWidget);
      expect(find.text('Copy Dossier'), findsOneWidget);
    });
  });
}
