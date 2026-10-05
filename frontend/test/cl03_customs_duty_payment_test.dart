import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_duty_payment_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CL-03: Customs Duty Payment Model & Serialization Tests', () {
    test('CustomsClearanceModel parses and serializes CL-03 duty payment fields correctly', () {
      final json = {
        'customs_clearance_id': 503,
        'clearance_code': 'CLR-2026-0503',
        'import_file_id': 95,
        'declaration_46_no': '46-2026-DKH-9988',
        'nafeza_claim_number': 'CLM-MTS-2026-771122',
        'actual_duty_total': 165801.50,
        'total_duty_payable': 165801.50,
        'duty_paid_amount': 165801.50,
        'sadad_number': 'SADAD-2026-998811',
        'payment_method': 'E-Finance / Sadad',
        'bank_receipt_no': 'REC-EFIN-8877123',
        'receipt_file_url': '/uploads/receipts/sadad_998811.pdf',
        'payment_status': 'Paid & Verified',
        'status': 'Duties Paid',
        'owner': 'Kamal',
        'is_active': true,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T13:00:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 503);
      expect(record.clearanceCode, 'CLR-2026-0503');
      expect(record.importFileId, 95);
      expect(record.sadadNumber, 'SADAD-2026-998811');
      expect(record.paymentMethod, 'E-Finance / Sadad');
      expect(record.dutyPaidAmount, 165801.50);
      expect(record.bankReceiptNo, 'REC-EFIN-8877123');
      expect(record.receiptFileUrl, '/uploads/receipts/sadad_998811.pdf');
      expect(record.paymentStatus, 'Paid & Verified');

      final serialized = record.toJson();
      expect(serialized['sadad_number'], 'SADAD-2026-998811');
      expect(serialized['payment_method'], 'E-Finance / Sadad');
      expect(serialized['duty_paid_amount'], 165801.50);
      expect(serialized['receipt_file_url'], '/uploads/receipts/sadad_998811.pdf');
      expect(serialized['bank_receipt_no'], 'REC-EFIN-8877123');
    });

    test('ImportFileModel parses and serializes CL-03 duty payment fields correctly', () {
      final json = {
        'import_file_id': 95,
        'import_file_code': 'IMP-2026-0095',
        'custom_file_number': 'Machinery Line',
        'company_id': 1,
        'company_name': 'Delta Industrial Machinery LLC',
        'supplier_id': 2,
        'supplier_name': 'Bavaria Tech GmbH',
        'current_module': 'Phase 7 - Customs Clearance & Inspection',
        'current_stage': 'Stage 7 - Customs Clearance',
        'progress_percent': 92.0,
        'next_action': 'استلام إذن الإفراج النهائي (CL-04) - جاري إنهاء إجراءات الإفراج الجمركي الأخضر',
        'customs_duty_paid_amount': 165801.50,
        'customs_duty_receipt_no': 'REC-EFIN-8877123',
        'customs_duty_sadad_no': 'SADAD-2026-998811',
        'customs_duty_payment_date': '2026-09-18T13:00:00Z',
        'customs_duty_payment_status': 'Paid',
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T13:00:00Z',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.importFileId, 95);
      expect(file.customsDutyPaidAmount, 165801.50);
      expect(file.customsDutyReceiptNo, 'REC-EFIN-8877123');
      expect(file.customsDutySadadNo, 'SADAD-2026-998811');
      expect(file.customsDutyPaymentDate, '2026-09-18T13:00:00Z');
      expect(file.customsDutyPaymentStatus, 'Paid');

      final serialized = file.toJson();
      expect(serialized['customs_duty_paid_amount'], 165801.50);
      expect(serialized['customs_duty_receipt_no'], 'REC-EFIN-8877123');
      expect(serialized['customs_duty_sadad_no'], 'SADAD-2026-998811');
      expect(serialized['customs_duty_payment_date'], '2026-09-18T13:00:00Z');
      expect(serialized['customs_duty_payment_status'], 'Paid');
    });
  });

  group('CL-03: CustomsDutyPaymentDialog Widget Tests', () {
    testWidgets('Renders CustomsDutyPaymentDialog with Sadad number, receipt, payment method, bank, and submit button', (tester) async {
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
        currentModule: 'Phase 7 - Customs Clearance & Inspection',
        currentStage: 'Customs Duties Assessed - Ready for Payment',
        progressPercent: 90.0,
        nextAction: 'سداد الرسوم الجمركية بسداد (CL-03)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T12:00:00Z',
      );

      final clearanceRecord = CustomsClearanceModel(
        customsClearanceId: 503,
        clearanceCode: 'CLR-2026-0503',
        importFileId: 95,
        declaration46No: 'DEC-2026-DKH-5511',
        declaration46Date: '2026-09-18T10:00:00Z',
        customsOfficeName: 'El Dekheila Port Customs',
        channelType: 'Red Channel',
        nafezaClaimNumber: 'CLM-MTS-2026-987654',
        actualDutyTotal: 165801.50,
        totalDutyPayable: 165801.50,
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T12:00:00Z',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: MaterialApp(
              locale: const Locale('ar'),
              home: Scaffold(
                body: CustomsDutyPaymentDialog(
                  file: sampleFile,
                  clearanceRecord: clearanceRecord,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Shipment Context
      expect(find.text('سداد الرسوم والضرائب الجمركية عبر سداد / E-Finance (CL-03)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0095'), findsWidgets);
      expect(find.textContaining('DEC-2026-DKH-5511'), findsWidgets);
      expect(find.textContaining('CLM-MTS-2026-987654'), findsWidgets);

      // Verify Financial Banner
      expect(find.text('إجمالي الرسوم المعتمدة بمطالبة نافذة MTS'), findsOneWidget);
      expect(find.text('165,801.50 ج.م'), findsOneWidget);

      // Verify Form Section
      expect(find.text('بيانات السداد الإلكتروني والبنكي'), findsOneWidget);
      expect(find.byKey(const Key('sadadNumberField')), findsOneWidget);
      expect(find.byKey(const Key('dutyReceiptNumberField')), findsOneWidget);
      expect(find.byKey(const Key('dutyPaidAmountField')), findsOneWidget);
      expect(find.byKey(const Key('paymentMethodField')), findsOneWidget);
      expect(find.byKey(const Key('bankNameField')), findsOneWidget);
      expect(find.byKey(const Key('dutyPaymentDatePicker')), findsOneWidget);

      // Verify Attachment & Notes
      expect(find.byKey(const Key('receiptFileUrlField')), findsOneWidget);
      expect(find.byKey(const Key('dutyPaymentNotesField')), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.byKey(const Key('submitDutyPaymentBtn')), findsOneWidget);
      expect(find.text('تأكيد وتسجيل سداد الرسوم (CL-03)'), findsOneWidget);
    });
  });
}
