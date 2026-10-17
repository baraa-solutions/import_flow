import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_declaration_46_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CS-03: Customs Declaration 46 Registration Model & Serialization Tests', () {
    test('CustomsClearanceModel parses and serializes declaration 46 fields correctly', () {
      final json = {
        'customs_clearance_id': 303,
        'clearance_code': 'CLR-2026-0303',
        'import_file_id': 88,
        'declaration_46_no': '46-2026-ALX-98124',
        'declaration_46_date': '2026-09-18T10:00:00Z',
        'customs_office_name': 'Alexandria Port Customs',
        'channel_type': 'Red Channel',
        'regulatory_bodies': ['GOEIC', 'Food Safety Authority'],
        'mts_certificate_number': 'MTS-2026-EG-44910',
        'customs_tariff_items_count': 3,
        'inspection_notes': 'معاينة كاملة وسحب عينات للبندين 1 و 3',
        'status': 'Under Customs Clearance',
        'owner': 'Kamal',
        'is_active': true,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T10:00:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 303);
      expect(record.clearanceCode, 'CLR-2026-0303');
      expect(record.importFileId, 88);
      expect(record.declaration46No, '46-2026-ALX-98124');
      expect(record.declaration46Date, '2026-09-18T10:00:00Z');
      expect(record.customsOfficeName, 'Alexandria Port Customs');
      expect(record.channelType, 'Red Channel');
      expect(record.regulatoryBodies, contains('GOEIC'));
      expect(record.regulatoryBodies, contains('Food Safety Authority'));
      expect(record.mtsCertificateNumber, 'MTS-2026-EG-44910');
      expect(record.customsTariffItemsCount, 3);
      expect(record.status, 'Under Customs Clearance');
      expect(record.inspectionNotes, contains('معاينة كاملة'));

      final serialized = record.toJson();
      expect(serialized['declaration_46_no'], '46-2026-ALX-98124');
      expect(serialized['declaration_46_date'], '2026-09-18T10:00:00Z');
      expect(serialized['channel_type'], 'Red Channel');
      expect(serialized['mts_certificate_number'], 'MTS-2026-EG-44910');
      expect(serialized['customs_tariff_items_count'], 3);
      expect(serialized['status'], 'Under Customs Clearance');
    });

    test('ImportFileModel parses and serializes form 46 tracking fields correctly', () {
      final json = {
        'import_file_id': 88,
        'import_file_code': 'IMP-2026-0088',
        'custom_file_number': 'Petrochemical Polymers',
        'company_name': 'El-Delta Petrochemicals',
        'supplier_name': 'Global Polymers Ltd',
        'bl_number': 'MSK99112233',
        'form46_no': '46-2026-ALX-98124',
        'form46_date': '2026-09-18T10:00:00Z',
        'form46_status': 'REGISTERED',
        'current_module': 'Phase 7 - Customs Clearance',
        'current_stage': 'Under Customs Clearance (تحت التخليص والكشف 46)',
        'progress_percent': 86.0,
        'next_action': 'تسجيل الكشف والمعاينة وسحب العينات (CL-01)',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T10:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.importFileId, 88);
      expect(file.form46No, '46-2026-ALX-98124');
      expect(file.form46Date, '2026-09-18T10:00:00Z');
      expect(file.form46Status, 'REGISTERED');
      expect(file.progressPercent, 86.0);
      expect(file.nextAction, contains('CL-01'));

      final serialized = file.toJson();
      expect(serialized['form46_no'], '46-2026-ALX-98124');
      expect(serialized['form46_date'], '2026-09-18T10:00:00Z');
      expect(serialized['form46_status'], 'REGISTERED');
    });
  });

  group('CS-03: CustomsDeclaration46Dialog Widget Tests', () {
    testWidgets('Renders CustomsDeclaration46Dialog with form fields, channel selector, and buttons', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 88,
        importFileCode: 'IMP-2026-0088',
        customFileNumber: 'Petrochemical Polymers',
        companyName: 'El-Delta Petrochemicals',
        supplierName: 'Global Polymers Ltd',
        portOfDischarge: 'Alexandria Port',
        deliveryOrderNo: 'DO-2026-MSK-7711',
        currentModule: 'Phase 6 - Customs Preparation',
        currentStage: 'Delivery Order Paid & Received',
        progressPercent: 83.0,
        nextAction: 'قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)',
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
                body: CustomsDeclaration46Dialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Shipment Details
      expect(find.text('قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0088'), findsWidgets);
      expect(find.textContaining('El-Delta Petrochemicals'), findsOneWidget);
      expect(find.textContaining('Petrochemical Polymers'), findsOneWidget);
      expect(find.textContaining('Global Polymers Ltd'), findsOneWidget);

      // Verify Form Fields
      expect(find.byKey(const Key('declaration46NoField')), findsOneWidget);
      expect(find.byKey(const Key('generateDeclaration46Btn')), findsNothing);
      expect(find.byKey(const Key('customsOfficeDropdown')), findsOneWidget);
      expect(find.byKey(const Key('tariffCountField')), findsOneWidget);
      expect(find.byKey(const Key('submitDeclaration46Btn')), findsOneWidget);

      // Verify no invented numbers are present
      expect(find.textContaining('46-20'), findsNothing);
      expect(find.textContaining('MTS-'), findsNothing);
      final declField = tester.widget<TextFormField>(find.byKey(const Key('declaration46NoField')));
      expect(declField.controller?.text, isEmpty);

      // Verify Channel Options
      expect(find.text('المسار الأحمر'), findsOneWidget);
      expect(find.text('المسار الأصفر'), findsOneWidget);
      expect(find.text('المسار الأخضر'), findsOneWidget);

      // Verify Regulatory Body Chips (value is the GOEIC code, label is localized)
      expect(find.text('الهيئة العامة للرقابة على الصادرات والواردات'), findsOneWidget);

      // Verify validation triggers on empty submit
      await tester.tap(find.byKey(const Key('submitDeclaration46Btn')));
      await tester.pumpAndSettle();
      expect(find.text('رقم الإقرار الجمركي مطلوب'), findsOneWidget);
    });
  });
}
