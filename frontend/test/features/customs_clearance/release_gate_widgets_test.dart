import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/approval_status_row.dart';
import 'package:frontend/features/customs_clearance/widgets/release_gate_summary_card.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_requirements/models/import_requirement_model.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  group('ApprovalStatusRow Widget Tests', () {
    testWidgets('renders title, authority, reference number, and status correctly', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          ApprovalStatusRow(
            title: 'موافقة الهيئة العامة للرقابة على الصادرات والواردات',
            status: 'Approved',
            authorityOrBody: 'GOEIC',
            referenceNumber: 'PERMIT-2026-9911',
            isRequired: true,
            notes: 'تم فحص المستندات والمطابقة واعتماد الطلب',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('موافقة الهيئة العامة للرقابة على الصادرات والواردات'), findsOneWidget);
      expect(find.text('GOEIC'), findsOneWidget);
      expect(find.text('PERMIT-2026-9911'), findsOneWidget);
      expect(find.text('تم فحص المستندات والمطابقة واعتماد الطلب'), findsOneWidget);
      expect(find.text('مستوفى'), findsOneWidget);
      expect(find.text('معتمد (Approved)'), findsOneWidget);

      await tester.tap(find.byType(ApprovalStatusRow));
      expect(tapped, isTrue);
    });

    testWidgets('renders pending state with mandatory warning indicator when required', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ApprovalStatusRow(
            title: 'فحص ومعاينة البضاعة',
            status: 'Pending',
            authorityOrBody: 'SGS Inspection',
            isRequired: true,
          ),
        ),
      );

      expect(find.text('فحص ومعاينة البضاعة'), findsOneWidget);
      expect(find.text('شرط إلزامي'), findsOneWidget);
      expect(find.text('قيد الاعتماد (Pending)'), findsOneWidget);
    });
  });

  group('ReleaseGateSummaryCard Widget Tests', () {
    testWidgets('blocks release and shows warning banner when regulatory permit is pending', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final file = ImportFileModel.fromJson({
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-0101',
        'company_name': 'Delta Machinery LLC',
        'supplier_name': 'Bavaria Tech GmbH',
        'acid_number': '1234567890123456789',
        'acid_expiry_date': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
        'customs_duty_paid_amount': 50000.0,
        'customs_duty_payment_status': 'PAID',
      });

      final clearance = CustomsClearanceModel(
        customsClearanceId: 201,
        clearanceCode: 'CLR-2026-0201',
        importFileId: 101,
        customsOfficeName: 'Dekheila Customs',
        channelType: 'Red Channel',
        actualDutyTotal: 50000.0,
        dutyPaidAmount: 50000.0,
        paymentStatus: 'Paid & Verified',
        status: 'Duty Paid - Ready for Final Release',
        owner: 'Kamal',
        createdAt: '2026-09-01T00:00:00Z',
        updatedAt: '2026-09-01T00:00:00Z',
      );

      final assessment = ImportRequirementModel.fromJson({
        'assessment_code': 'BP011-2026-0001',
        'import_file_id': 101,
        'import_permit_required': true,
        'permit_issuing_authority': 'الهيئة القومية لسلامة الغذاء (NFSA)',
        'permit_status': 'Pending',
        'inspection_required': false,
        'inspection_status': 'Not Required',
      });

      await tester.pumpWidget(
        _wrap(
          ReleaseGateSummaryCard(
            file: file,
            clearanceRecord: clearance,
            assessment: assessment,
            onIssueRelease: () {},
          ),
        ),
      );

      // Card Header & Overall Status
      expect(find.text('بوابة التحقق من متطلبات الإفراج الجمركي (Release Gate)'), findsOneWidget);
      expect(find.text('الإفراج معلق / محظور'), findsOneWidget);

      // Warning banner present
      expect(find.textContaining('حظر الإفراج الجمركي'), findsOneWidget);
      expect(find.textContaining('موافقة الجهات الرقابية'), findsWidgets);

      // Gate rows
      expect(find.text('سداد الرسوم والضرائب الجمركية (CL-03)'), findsOneWidget);
      expect(find.text('موافقة جهات العرض والرقابة النوعية (GOEIC / سلامة الغذاء)'), findsOneWidget);
      expect(find.text('معاينة وفحص البضاعة والتحفظ المعملي'), findsOneWidget);
      expect(find.text('الرقم التعريفي المبدئي للشحنة (ACID Number)'), findsOneWidget);

      // Button is disabled when release is gated
      final buttonFinder = find.widgetWithText(ElevatedButton, 'إصدار الإفراج الجمركي (CL-04)');
      if (buttonFinder.evaluate().isNotEmpty) {
        final button = tester.widget<ElevatedButton>(buttonFinder);
        expect(button.onPressed, isNull);
      }
    });

    testWidgets('allows release when all gates (financial, regulatory, inspection, ACID) pass', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool releaseTriggered = false;

      final file = ImportFileModel.fromJson({
        'import_file_id': 102,
        'import_file_code': 'IMP-2026-0102',
        'company_name': 'Delta Machinery LLC',
        'supplier_name': 'Bavaria Tech GmbH',
        'acid_number': '9988776655443322110',
        'acid_expiry_date': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'customs_duty_paid_amount': 85000.0,
        'customs_duty_payment_status': 'PAID',
      });

      final clearance = CustomsClearanceModel(
        customsClearanceId: 202,
        clearanceCode: 'CLR-2026-0202',
        importFileId: 102,
        customsOfficeName: 'Alexandria Customs',
        channelType: 'Green Channel',
        actualDutyTotal: 85000.0,
        dutyPaidAmount: 85000.0,
        paymentStatus: 'Paid & Verified',
        status: 'Duty Paid - Ready for Final Release',
        owner: 'Kamal',
        createdAt: '2026-09-01T00:00:00Z',
        updatedAt: '2026-09-01T00:00:00Z',
      );

      final assessment = ImportRequirementModel.fromJson({
        'assessment_code': 'BP011-2026-0002',
        'import_file_id': 102,
        'import_permit_required': true,
        'permit_issuing_authority': 'GOEIC',
        'permit_number': 'PERMIT-GOEIC-2026-88',
        'permit_status': 'Approved',
        'inspection_required': true,
        'inspection_body': 'SGS',
        'inspection_report_no': 'REP-SGS-99',
        'inspection_status': 'Completed',
      });

      await tester.pumpWidget(
        _wrap(
          ReleaseGateSummaryCard(
            file: file,
            clearanceRecord: clearance,
            assessment: assessment,
            onIssueRelease: () => releaseTriggered = true,
          ),
        ),
      );

      // Card Header shows ready
      expect(find.text('جاهز للإفراج النهائي'), findsOneWidget);
      expect(find.textContaining('كافة متطلبات الإفراج الجمركي مستوفاة'), findsOneWidget);

      // Tap the release action button
      final buttonFinder = find.widgetWithText(ElevatedButton, 'إصدار الإفراج الجمركي (CL-04)');
      expect(buttonFinder, findsOneWidget);
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(releaseTriggered, isTrue);
    });
  });
}
