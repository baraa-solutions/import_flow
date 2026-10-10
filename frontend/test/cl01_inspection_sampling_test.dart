import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_inspection_sampling_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CL-01: Customs Inspection & Sampling Model & Serialization Tests', () {
    test('CustomsClearanceModel parses and serializes inspection & sampling fields correctly', () {
      final json = {
        'customs_clearance_id': 401,
        'clearance_code': 'CLR-2026-0401',
        'import_file_id': 92,
        'declaration_46_no': '46-2026-ALX-11223',
        'declaration_46_date': '2026-09-18T10:00:00Z',
        'customs_office_name': 'Alexandria Port Customs',
        'channel_type': 'Red Channel',
        'inspection_date': '2026-09-18T11:00:00Z',
        'inspection_type': 'Physical & Sampling',
        'inspection_yard': 'ساحة الفحص المشترك - رصيف 42',
        'inspector_name': 'م. إبراهيم خليل - رئيس لجنة الفحص',
        'inspection_result': 'Conforming',
        'is_sample_drawn': true,
        'sampling_date': '2026-09-18T11:30:00Z',
        'sampling_record_no': 'SMP-2026-ALX-8822',
        'sample_test_status': 'Samples Under Testing',
        'sampled_regulatory_bodies': ['GOEIC', 'Radiation Safety'],
        'goeic_certificate_no': 'GOEIC-INSP-2026-5544',
        'regulatory_bodies': ['GOEIC', 'Radiation Safety'],
        'lab_service_fees': 1250.0,
        'inspection_notes': 'معاينة تامة وسحب عدد 3 عينات للتحليل',
        'status': 'Inspection & Sampling Recorded',
        'owner': 'Kamal',
        'is_active': true,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T11:30:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 401);
      expect(record.clearanceCode, 'CLR-2026-0401');
      expect(record.importFileId, 92);
      expect(record.declaration46No, '46-2026-ALX-11223');
      expect(record.inspectionType, 'Physical & Sampling');
      expect(record.inspectionYard, 'ساحة الفحص المشترك - رصيف 42');
      expect(record.inspectorName, 'م. إبراهيم خليل - رئيس لجنة الفحص');
      expect(record.inspectionResult, 'Conforming');
      expect(record.isSampleDrawn, true);
      expect(record.samplingRecordNo, 'SMP-2026-ALX-8822');
      expect(record.sampleTestStatus, 'Samples Under Testing');
      expect(record.sampledRegulatoryBodies, contains('GOEIC'));
      expect(record.sampledRegulatoryBodies, contains('Radiation Safety'));
      expect(record.goeicCertificateNo, 'GOEIC-INSP-2026-5544');
      expect(record.labServiceFees, 1250.0);
      expect(record.status, 'Inspection & Sampling Recorded');
      expect(record.inspectionNotes, contains('معاينة تامة'));

      final serialized = record.toJson();
      expect(serialized['inspection_type'], 'Physical & Sampling');
      expect(serialized['inspection_yard'], 'ساحة الفحص المشترك - رصيف 42');
      expect(serialized['inspector_name'], 'م. إبراهيم خليل - رئيس لجنة الفحص');
      expect(serialized['inspection_result'], 'Conforming');
      expect(serialized['is_sample_drawn'], true);
      expect(serialized['sampling_record_no'], 'SMP-2026-ALX-8822');
      expect(serialized['goeic_certificate_no'], 'GOEIC-INSP-2026-5544');
      expect(serialized['status'], 'Inspection & Sampling Recorded');
    });
  });

  group('CL-01: CustomsInspectionSamplingDialog Widget Tests', () {
    testWidgets('Renders CustomsInspectionSamplingDialog with form fields, inspection types, and regulatory chips', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 92,
        importFileCode: 'IMP-2026-0092',
        customFileNumber: 'Industrial Chemicals',
        companyName: 'Alexandria Chemicals Ltd',
        supplierName: 'Global Chem Corp',
        portOfDischarge: 'Alexandria Port',
        deliveryOrderNo: 'DO-2026-MSK-9900',
        form46No: '46-2026-ALX-11223',
        form46Date: '2026-09-18T10:00:00Z',
        form46Status: 'REGISTERED',
        currentModule: 'Phase 7 - Customs Clearance',
        currentStage: 'Under Customs Clearance (تحت التخليص والكشف 46)',
        progressPercent: 86.0,
        nextAction: 'تسجيل الكشف والمعاينة وسحب العينات (CL-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsInspectionSamplingDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Shipment Details
      expect(find.text('تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة (CL-01)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0092'), findsWidgets);
      expect(find.textContaining('Alexandria Chemicals Ltd'), findsOneWidget);
      expect(find.textContaining('46-2026-ALX-11223'), findsWidgets);

      // Verify no invented sampling record or committee inspector
      expect(find.textContaining('SMP-'), findsNothing);
      expect(find.text('Joint Customs Inspection Committee'), findsNothing);

      // Verify Channel fallback is '—'
      expect(find.text('—'), findsWidgets);

      // Verify Form Sections & Key Dropdowns
      expect(find.byKey(const Key('inspectionYardDropdown')), findsOneWidget);
      expect(find.text('نوع وطريقة الكشف والمعاينة:'), findsOneWidget);
      expect(find.text('كشف فعلي وسحب عينات'), findsOneWidget);
      expect(find.text('تفريغ وكشف كلي 100%'), findsOneWidget);

      // Verify Inspection Result Options
      expect(find.text('مطابقة تامة (Conforming)'), findsOneWidget);
      expect(find.text('وجود عجز (Shortage)'), findsOneWidget);
      expect(find.text('وجود زيادة (Surplus)'), findsOneWidget);

      // Verify Sampling Section & Regulatory Bodies
      expect(find.text('تم سحب عينات للفحص والتحليل المعملي للجهات الرقابية'), findsOneWidget);
      expect(find.textContaining('GOEIC'), findsWidgets);
      expect(find.textContaining('حفظ واعتماد الكشف وسحب العينات (CL-01)'), findsOneWidget);
    });

    testWidgets('Submitting empty inspection dialog triggers validation errors for yard and verdict, and bodies/record when sampling is enabled', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 92,
        importFileCode: 'IMP-2026-0092',
        customFileNumber: 'Industrial Chemicals',
        companyName: 'Alexandria Chemicals Ltd',
        supplierName: 'Global Chem Corp',
        currentModule: 'Phase 7 - Customs Clearance',
        currentStage: 'Under Customs Clearance (تحت التخليص والكشف 46)',
        nextAction: 'تسجيل الكشف والمعاينة وسحب العينات (CL-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
        form46No: '46-2026-ALX-11223',
        form46Date: '2026-09-18T10:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Builder(
                builder: (context) {
                  capturedContext = context;
                  return Scaffold(
                    body: CustomsInspectionSamplingDialog(file: sampleFile),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final l = capturedContext.l10n;

      // Tap Confirm/Save button with sampling disabled by default
      final saveBtn = find.text(l.ccInsConfirm);
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify validation error messages for yard and verdict
      expect(find.text(l.ccInsYardRequired), findsOneWidget);
      expect(find.text(l.ccInsResultRequired), findsOneWidget);
      expect(find.text(l.ccInsBodiesRequired), findsNothing);
      expect(find.text(l.ccInsSamplingNoRequired), findsNothing);

      // Toggle sampling ON to verify regulatory bodies & sampling record validation
      final samplingSwitch = find.byType(SwitchListTile);
      expect(samplingSwitch, findsOneWidget);
      await tester.ensureVisible(samplingSwitch);
      await tester.pumpAndSettle();
      await tester.tap(samplingSwitch);
      await tester.pumpAndSettle();

      // Submit again with sampling ON
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text(l.ccInsBodiesRequired), findsOneWidget);
      expect(find.text(l.ccInsSamplingNoRequired), findsOneWidget);
    });

    testWidgets('Prefills from clearanceRecord and displays Green Channel badge', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 92,
        importFileCode: 'IMP-2026-0092',
        customFileNumber: 'Industrial Chemicals',
        companyName: 'Alexandria Chemicals Ltd',
        supplierName: 'Global Chem Corp',
        currentModule: 'Phase 7 - Customs Clearance',
        currentStage: 'Under Customs Clearance (تحت التخليص والكشف 46)',
        nextAction: 'تسجيل الكشف والمعاينة وسحب العينات (CL-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
        form46No: '46-2026-ALX-11223',
        form46Date: '2026-09-18T10:00:00Z',
      );

      final existingRecord = CustomsClearanceModel(
        customsClearanceId: 401,
        clearanceCode: 'CLR-2026-0401',
        importFileId: 92,
        declaration46No: '46-2026-ALX-11223',
        customsOfficeName: 'Alexandria Port Customs',
        channelType: 'Green Channel',
        inspectionDate: '2026-09-18T11:00:00Z',
        inspectionType: 'Physical & Sampling',
        inspectionYard: 'ساحة الفحص المشترك - رصيف 42',
        inspectorName: 'م. إبراهيم خليل',
        inspectionResult: 'Conforming',
        isSampleDrawn: true,
        samplingDate: '2026-09-18T11:30:00Z',
        samplingRecordNo: 'SMP-2026-ALX-8822',
        sampleTestStatus: 'Samples Under Testing',
        sampledRegulatoryBodies: ['GOEIC'],
        goeicCertificateNo: 'GOEIC-2026-99',
        labServiceFees: 1250.0,
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T11:30:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Builder(
                builder: (context) {
                  capturedContext = context;
                  return Scaffold(
                    body: CustomsInspectionSamplingDialog(
                      file: sampleFile,
                      clearanceRecord: existingRecord,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final l = capturedContext.l10n;

      // Verify Green Channel badge is rendered
      expect(find.text(l.customsClearanceChannelGreen), findsOneWidget);

      // Verify prefilled inspector and sampling record
      expect(find.text('م. إبراهيم خليل'), findsOneWidget);
      expect(find.text('SMP-2026-ALX-8822'), findsOneWidget);
      expect(find.text('GOEIC-2026-99'), findsOneWidget);
    });

    testWidgets('Form 46 registered record without prior inspection (inspectionDate null) opens with unselected verdict, Green channel badge, and fails validation if submitted empty', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 92,
        importFileCode: 'IMP-2026-0092',
        customFileNumber: 'Industrial Chemicals',
        companyName: 'Alexandria Chemicals Ltd',
        supplierName: 'Global Chem Corp',
        currentModule: 'Phase 7 - Customs Clearance',
        currentStage: 'Under Customs Clearance (تحت التخليص والكشف 46)',
        nextAction: 'تسجيل الكشف والمعاينة وسحب العينات (CL-01)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
        form46No: '46-2026-ALX-11223',
        form46Date: '2026-09-18T10:00:00Z',
      );

      // Record created by CS-03: declaration registered, channel assigned, but inspection has not occurred.
      // inspectionResult in CustomsClearanceModel defaults to 'Conforming', inspectionDate is null.
      final declarationOnlyRecord = CustomsClearanceModel(
        customsClearanceId: 401,
        clearanceCode: 'CLR-2026-0401',
        importFileId: 92,
        declaration46No: '46-2026-ALX-11223',
        customsOfficeName: 'Alexandria Port Customs',
        channelType: 'Green Channel',
        inspectionDate: null,
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T10:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Builder(
                builder: (context) {
                  capturedContext = context;
                  return Scaffold(
                    body: CustomsInspectionSamplingDialog(
                      file: sampleFile,
                      clearanceRecord: declarationOnlyRecord,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final l = capturedContext.l10n;

      // 1. Assert Green Channel badge is rendered
      expect(find.text(l.customsClearanceChannelGreen), findsOneWidget);

      // 2. Assert no verdict error initially
      expect(find.text(l.ccInsResultRequired), findsNothing);

      // 3. Tap Confirm/Save button
      final saveBtn = find.text(l.ccInsConfirm);
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 4. Assert verdict validation error is triggered because no verdict was prefilled
      expect(find.text(l.ccInsResultRequired), findsOneWidget);
    });
  });
}
