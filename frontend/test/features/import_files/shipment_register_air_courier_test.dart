import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/widgets/file_details/shipment_acid_status_badge.dart';
import 'package:frontend/features/import_files/widgets/file_details/courier_tracking_action_button.dart';
import 'package:frontend/features/import_files/widgets/milestone_tracker/smart_stage_skip_indicator.dart';
import 'package:frontend/features/import_files/widgets/shipment_milestone_tracker.dart';

Widget createTestWidget(Widget child, {Locale locale = const Locale('ar')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AppLocalizationsProvider(
      locale: locale,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ImportFileModel Air Freight & Courier Fields', () {
    test('Correctly deserializes courier fields and defaults', () {
      final json = {
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-AIR-001',
        'company_name': 'Sorour Logistics',
        'supplier_name': 'Shenzhen Tech Ltd',
        'shipment_mode': 'Air Freight',
        'shipment_sub_mode': 'Courier Express',
        'courier_operator': 'DHL',
        'chargeable_divisor': 5000,
        'acid_requirement': 'EXEMPT_POSTAL',
        'acid_exemption_reason': 'Postal parcel under 50kg and \$2000',
        'courier_tracking_no': 'DHL-9876543210',
        'current_module': 'STEP_06',
        'current_stage': 'Phase 4',
        'next_action': 'Track Courier',
        'created_at': '2026-11-03T00:00:00Z',
        'updated_at': '2026-11-03T00:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.shipmentSubMode, 'Courier Express');
      expect(file.courierOperator, 'DHL');
      expect(file.chargeableDivisor, 5000);
      expect(file.acidRequirement, 'EXEMPT_POSTAL');
      expect(file.acidExemptionReason, 'Postal parcel under 50kg and \$2000');
      expect(file.courierTrackingNo, 'DHL-9876543210');
      expect(file.isCourier, isTrue);
      expect(file.isAcidExempt, isTrue);

      final outJson = file.toJson();
      expect(outJson['shipment_sub_mode'], 'Courier Express');
      expect(outJson['courier_operator'], 'DHL');
      expect(outJson['chargeable_divisor'], 5000);
      expect(outJson['acid_requirement'], 'EXEMPT_POSTAL');
      expect(outJson['acid_exemption_reason'], 'Postal parcel under 50kg and \$2000');
      expect(outJson['courier_tracking_no'], 'DHL-9876543210');
    });

    test('Falls back to standard defaults when fields are absent', () {
      final json = {
        'import_file_id': 102,
        'import_file_code': 'IMP-2026-SEA-001',
        'company_name': 'Sorour Logistics',
        'supplier_name': 'Global Trading',
        'current_module': 'STEP_01',
        'current_stage': 'Phase 1',
        'next_action': 'Plan',
        'created_at': '2026-11-03T00:00:00Z',
        'updated_at': '2026-11-03T00:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.shipmentSubMode, 'General Air Cargo');
      expect(file.courierOperator, isNull);
      expect(file.chargeableDivisor, 6000);
      expect(file.acidRequirement, 'MANDATORY');
      expect(file.acidExemptionReason, isNull);
      expect(file.courierTrackingNo, isNull);
      expect(file.isCourier, isFalse);
      expect(file.isAcidExempt, isFalse);
    });
  });

  group('ShipmentAcidStatusBadge Widget Tests', () {
    testWidgets('Renders EXEMPT_POSTAL badge with correct Arabic label and tooltip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ShipmentAcidStatusBadge(
            acidRequirement: 'EXEMPT_POSTAL',
            acidExemptionReason: 'طرد بريدي أقل من 50 كجم',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طرد بريدي معفى من التسجيل المسبق'), findsOneWidget);
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets('Renders MANDATORY with ACID issued', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ShipmentAcidStatusBadge(
            acidRequirement: 'MANDATORY',
            acidNumber: '5281534391025810014',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('رقم القيد الجمركي المبدئي: '), findsOneWidget);
      expect(find.text('5281534391025810014'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('Renders MANDATORY with missing ACID (action required)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const ShipmentAcidStatusBadge(
            acidRequirement: 'MANDATORY',
            acidNumber: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تسجيل مسبق إلزامي (مطلوب قبل الشحن)'), findsOneWidget);
    });
  });

  group('CourierTrackingActionButton Widget Tests', () {
    testWidgets('Renders Courier tracking details with operator icon and copy button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const CourierTrackingActionButton(
            courierOperator: 'DHL',
            courierTrackingNo: '1234567890',
            shipmentMode: 'Air Freight',
            shipmentSubMode: 'Courier Express',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('البريد السريع دي إتش إل'), findsOneWidget);
      expect(find.text('1234567890'), findsOneWidget);
      expect(find.text('نسخ'), findsOneWidget);
      expect(find.text('تتبع الشحنة'), findsOneWidget);
    });

    testWidgets('Hides cleanly when not a courier shipment', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const CourierTrackingActionButton(
            courierOperator: null,
            courierTrackingNo: null,
            shipmentMode: 'Sea FCL',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تتبع الشحنة'), findsNothing);
    });
  });

  group('SmartStageSkipIndicator & Milestone Tracker Tests', () {
    test('Accurately matches skipped steps and phases', () {
      final skipped = ['STEP_05', 'STEP_10', 'STEP_12'];

      expect(SmartStageSkipIndicator.isStepSkipped(skipped, 'STEP_05'), isTrue);
      expect(SmartStageSkipIndicator.isStepSkipped(skipped, 'STEP_10'), isTrue);
      expect(SmartStageSkipIndicator.isStepSkipped(skipped, 'STEP_12'), isTrue);
      expect(SmartStageSkipIndicator.isStepSkipped(skipped, 'STEP_01'), isFalse);

      expect(SmartStageSkipIndicator.isPhaseSkipped(skipped, 3), isTrue); // Phase 3 Docs & ACID
      expect(SmartStageSkipIndicator.isPhaseSkipped(skipped, 5), isTrue); // Phase 5 CargoX
      expect(SmartStageSkipIndicator.isPhaseSkipped(skipped, 1), isFalse);
    });

    testWidgets('Renders smart stage skip indicator widget with pure Arabic phrasing', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const SmartStageSkipIndicator(
            stepCode: 'STEP_05',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('رقم القيد الجمركي المبدئي'), findsOneWidget);
      expect(find.text('• معفى نظامياً (طرد بريدي)'), findsOneWidget);
    });

    testWidgets('ShipmentMilestoneTracker displays skipped stages as exempt', (tester) async {
      final file = ImportFileModel(
        importFileId: 201,
        importFileCode: 'IMP-2026-COURIER-001',
        companyName: 'Sorour Logistics',
        supplierName: 'Fast Express Co',
        shipmentMode: 'Air Freight',
        shipmentSubMode: 'Courier Express',
        acidRequirement: 'EXEMPT_POSTAL',
        skippedStages: ['STEP_05', 'STEP_10'],
        currentModule: 'STEP_06',
        currentStage: 'Phase 4',
        nextAction: 'Proceed with booking',
        createdAt: '2026-11-03T00:00:00Z',
        updatedAt: '2026-11-03T00:00:00Z',
      );

      await tester.pumpWidget(
        createTestWidget(
          SingleChildScrollView(
            child: ShipmentMilestoneTracker(importFile: file),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Universal SelectionArea wraps it
      expect(find.byType(SelectionArea), findsWidgets);
      // Verify skip badge is rendered for Phase 3
      expect(find.text('معفى نظامياً'), findsWidgets);
    });
  });
}
