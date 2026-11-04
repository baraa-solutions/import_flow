import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_final_release_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CL-04: Final Customs Release Model & Serialization Tests', () {
    test('CustomsClearanceModel parses and serializes CL-04 release fields correctly', () {
      final json = {
        'customs_clearance_id': 504,
        'clearance_code': 'CLR-2026-0504',
        'import_file_id': 95,
        'declaration_46_no': '46-2026-DKH-9988',
        'nafeza_claim_number': 'CLM-MTS-2026-771122',
        'actual_duty_total': 165801.50,
        'duty_paid_amount': 165801.50,
        'sadad_number': 'SADAD-2026-998811',
        'payment_status': 'Paid & Verified',
        'release_permit_no': 'REL-2026-DKH-0044',
        'release_date': '2026-09-18T14:00:00Z',
        'release_officer_name': 'مأمور الجمرك مصطفى النجار',
        'release_type': 'نهائي وبات (Final Green Release)',
        'release_document_url': '/uploads/releases/rel_0044.pdf',
        'gate_pass_number': 'GP-2026-DKH-5599',
        'demurrage_storage_fees': 450.00,
        'dispatch_authorized': true,
        'dispatch_date': '2026-09-18T14:30:00Z',
        'transport_instructions': 'التسليم لمخازن العاشر من رمضان رصيف تفريغ 2',
        'status': 'Final Release Granted',
        'owner': 'Kamal',
        'is_active': true,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T14:00:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 504);
      expect(record.clearanceCode, 'CLR-2026-0504');
      expect(record.importFileId, 95);
      expect(record.releasePermitNo, 'REL-2026-DKH-0044');
      expect(record.releaseDate, '2026-09-18T14:00:00Z');
      expect(record.releaseOfficerName, 'مأمور الجمرك مصطفى النجار');
      expect(record.releaseType, 'نهائي وبات (Final Green Release)');
      expect(record.releaseDocumentUrl, '/uploads/releases/rel_0044.pdf');
      expect(record.gatePassNumber, 'GP-2026-DKH-5599');
      expect(record.demurrageStorageFees, 450.00);
      expect(record.dispatchAuthorized, true);
      expect(record.transportInstructions, 'التسليم لمخازن العاشر من رمضان رصيف تفريغ 2');
      expect(record.status, 'Final Release Granted');

      final serialized = record.toJson();
      expect(serialized['release_permit_no'], 'REL-2026-DKH-0044');
      expect(serialized['release_officer_name'], 'مأمور الجمرك مصطفى النجار');
      expect(serialized['release_type'], 'نهائي وبات (Final Green Release)');
      expect(serialized['release_document_url'], '/uploads/releases/rel_0044.pdf');
      expect(serialized['gate_pass_number'], 'GP-2026-DKH-5599');
      expect(serialized['demurrage_storage_fees'], 450.00);
      expect(serialized['dispatch_authorized'], true);
      expect(serialized['transport_instructions'], 'التسليم لمخازن العاشر من رمضان رصيف تفريغ 2');
    });

    test('ImportFileModel parses and serializes CL-04 release fields correctly', () {
      final json = {
        'import_file_id': 95,
        'import_file_code': 'IMP-2026-0095',
        'custom_file_number': 'Machinery Line',
        'company_id': 1,
        'company_name': 'Delta Industrial Machinery LLC',
        'supplier_id': 2,
        'supplier_name': 'Bavaria Tech GmbH',
        'current_module': 'Phase 8 - Inland Transport & Warehouse Delivery',
        'current_stage': 'Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)',
        'progress_percent': 95.0,
        'next_action': 'حجز شاحنات النقل الداخلي (TR-01) ومتابعة خروج الشحنة من بوابة الميناء (TR-02)',
        'customs_duty_paid_amount': 165801.50,
        'customs_duty_receipt_no': 'REC-EFIN-8877123',
        'customs_duty_sadad_no': 'SADAD-2026-998811',
        'is_customs_released': true,
        'customs_released_at': '2026-09-18T14:00:00Z',
        'customs_release_permit_no': 'REL-2026-DKH-0044',
        'customs_release_type': 'نهائي وبات (Final Green Release)',
        'customs_release_officer': 'مأمور الجمرك مصطفى النجار',
        'customs_gate_pass_no': 'GP-2026-DKH-5599',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T14:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.importFileId, 95);
      expect(file.isCustomsReleased, true);
      expect(file.customsReleasedAt, '2026-09-18T14:00:00Z');
      expect(file.customsReleasePermitNo, 'REL-2026-DKH-0044');
      expect(file.customsReleaseType, 'نهائي وبات (Final Green Release)');
      expect(file.customsReleaseOfficer, 'مأمور الجمرك مصطفى النجار');
      expect(file.customsGatePassNo, 'GP-2026-DKH-5599');
      expect(file.progressPercent, 95.0);

      final serialized = file.toJson();
      expect(serialized['is_customs_released'], true);
      expect(serialized['customs_released_at'], '2026-09-18T14:00:00Z');
      expect(serialized['customs_release_permit_no'], 'REL-2026-DKH-0044');
      expect(serialized['customs_release_type'], 'نهائي وبات (Final Green Release)');
      expect(serialized['customs_release_officer'], 'مأمور الجمرك مصطفى النجار');
      expect(serialized['customs_gate_pass_no'], 'GP-2026-DKH-5599');
    });
  });

  group('CL-04: CustomsFinalReleaseDialog Widget Tests', () {
    testWidgets('Renders CustomsFinalReleaseDialog with release fields, auto-generators, and submit button', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 95,
        importFileCode: 'IMP-2026-0095',
        customFileNumber: 'Industrial Machinery',
        companyName: 'Delta Industrial Machinery LLC',
        supplierName: 'Bavaria Tech GmbH',
        portOfDischarge: 'El Dekheila Port',
        deliveryOrderNo: 'DO-2026-HAPAG-5511',
        form46No: 'DEC-2026-DKH-5511',
        form46Date: '2026-09-18T10:00:00Z',
        form46Status: 'REGISTERED',
        customsDutySadadNo: 'SADAD-2026-998811',
        customsDutyPaidAmount: 165801.50,
        currentModule: 'Phase 7 - Customs Clearance & Inspection',
        currentStage: 'Customs Duties Paid - Awaiting Final Release',
        progressPercent: 92.0,
        nextAction: 'صدور إذن الإفراج النهائي (CL-04)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      final clearanceRecord = CustomsClearanceModel(
        customsClearanceId: 504,
        clearanceCode: 'CLR-2026-0504',
        importFileId: 95,
        declaration46No: 'DEC-2026-DKH-5511',
        declaration46Date: '2026-09-18T10:00:00Z',
        customsOfficeName: 'El Dekheila Port Customs',
        channelType: 'Red Channel',
        nafezaClaimNumber: 'CLM-MTS-2026-987654',
        actualDutyTotal: 165801.50,
        totalDutyPayable: 165801.50,
        dutyPaidAmount: 165801.50,
        sadadNumber: 'SADAD-2026-998811',
        paymentStatus: 'Paid & Verified',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsFinalReleaseDialog(
                  file: sampleFile,
                  clearanceRecord: clearanceRecord,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Context
      expect(find.text('صدور إذن الإفراج الجمركي الأخضر وبدء النقل (CL-04)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0095'), findsWidgets);
      expect(find.textContaining('DEC-2026-DKH-5511'), findsWidgets);

      // Verify Summary Banner
      expect(find.text('رقم سداد الرسوم'), findsOneWidget);
      expect(find.text('SADAD-2026-998811'), findsWidgets);
      expect(find.text('165,801.50 ج.م'), findsOneWidget);

      // Verify Form Section Headers
      expect(find.text('بيانات إذن الإفراج الجمركي الأخضر'), findsOneWidget);
      expect(find.text('تصريح خروج البوابة وإجراءات النقل الداخلي'), findsOneWidget);

      // Verify Text Fields
      expect(find.byKey(const Key('releasePermitNoField')), findsOneWidget);
      expect(find.byKey(const Key('releaseOfficerField')), findsOneWidget);
      expect(find.byKey(const Key('gatePassNoField')), findsOneWidget);
      expect(find.byKey(const Key('demurrageFeesField')), findsOneWidget);
      expect(find.byKey(const Key('documentUrlField')), findsOneWidget);
      expect(find.byKey(const Key('transportInstructionsField')), findsOneWidget);
      expect(find.byKey(const Key('notesField')), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.byKey(const Key('customsFinalReleaseSubmitBtn')), findsOneWidget);
      expect(find.text('إصدار إذن الإفراج النهائي وتفويض النقل'), findsOneWidget);

      // Verify no auto-generator buttons exist
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
    });

    testWidgets('CL-04 starts with empty permit, gate pass, demurrage and unset gate out date, requires permit on submit', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 95,
        importFileCode: 'IMP-2026-0095',
        customFileNumber: 'Industrial Machinery',
        companyName: 'Delta Industrial Machinery LLC',
        supplierName: 'Bavaria Tech GmbH',
        portOfDischarge: 'El Dekheila Port',
        deliveryOrderNo: 'DO-2026-HAPAG-5511',
        form46No: 'DEC-2026-DKH-5511',
        form46Date: '2026-09-18T10:00:00Z',
        form46Status: 'REGISTERED',
        customsDutySadadNo: 'SADAD-2026-998811',
        customsDutyPaidAmount: 165801.50,
        customsReleasePermitNo: null,
        customsGatePassNo: null,
        currentModule: 'Phase 7 - Customs Clearance & Inspection',
        currentStage: 'Customs Duties Paid - Awaiting Final Release',
        progressPercent: 92.0,
        nextAction: 'صدور إذن الإفراج النهائي (CL-04)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      final clearanceRecord = CustomsClearanceModel(
        customsClearanceId: 504,
        clearanceCode: 'CLR-2026-0504',
        importFileId: 95,
        declaration46No: 'DEC-2026-DKH-5511',
        declaration46Date: '2026-09-18T10:00:00Z',
        customsOfficeName: 'El Dekheila Port Customs',
        channelType: 'Red Channel',
        nafezaClaimNumber: 'CLM-MTS-2026-987654',
        actualDutyTotal: 165801.50,
        totalDutyPayable: 165801.50,
        dutyPaidAmount: 165801.50,
        sadadNumber: 'SADAD-2026-998811',
        paymentStatus: 'Paid & Verified',
        releasePermitNo: null,
        gatePassNumber: null,
        demurrageStorageFees: null,
        portGateOutDate: null,
        dispatchAuthorized: false,
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsFinalReleaseDialog(
                  file: sampleFile,
                  clearanceRecord: clearanceRecord,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify fields start empty and no invented references with file ID
      final permitField = tester.widget<TextFormField>(find.byKey(const Key('releasePermitNoField')));
      expect(permitField.controller?.text, isEmpty);
      expect(permitField.controller?.text.contains('0095'), isFalse);

      final gatePassField = tester.widget<TextFormField>(find.byKey(const Key('gatePassNoField')));
      expect(gatePassField.controller?.text, isEmpty);
      expect(gatePassField.controller?.text.contains('0095'), isFalse);

      final demurrageField = tester.widget<TextFormField>(find.byKey(const Key('demurrageFeesField')));
      expect(demurrageField.controller?.text, isEmpty);

      // Verify gate-out date is not set
      expect(find.text('غير محدد'), findsOneWidget);

      // Verify submit triggers permit validator
      await tester.tap(find.byKey(const Key('customsFinalReleaseSubmitBtn')));
      await tester.pumpAndSettle();

      expect(find.text('رقم إذن الإفراج إلزامي'), findsOneWidget);
    });

    testWidgets('CL-04: Dialog with previous notes displays them read-only and starts with empty notes controller', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 95,
        importFileCode: 'IMP-2026-0095',
        companyName: 'Delta Industrial Machinery LLC',
        supplierName: 'Bavaria Tech GmbH',
        currentModule: 'Phase 7 - Customs Clearance & Inspection',
        currentStage: 'Stage 7 - Customs Clearance',
        nextAction: 'Action',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      final clearanceRecord = CustomsClearanceModel(
        customsClearanceId: 504,
        clearanceCode: 'CLR-2026-0504',
        importFileId: 95,
        notes: 'R1-PRIOR-NOTES',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T13:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsFinalReleaseDialog(
                  file: sampleFile,
                  clearanceRecord: clearanceRecord,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Read-only previous notes box is visible and contains 'R1-PRIOR-NOTES'
      expect(find.text('R1-PRIOR-NOTES'), findsOneWidget);

      // Notes input field controller starts empty
      final notesFieldFinder = find.byKey(const Key('notesField'));
      expect(notesFieldFinder, findsOneWidget);
      final formField = tester.widget<TextFormField>(notesFieldFinder);
      expect(formField.controller?.text, '');
    });
  });
}

