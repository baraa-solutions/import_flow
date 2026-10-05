import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/widgets/final_duty_assessment_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';

void main() {
  group('CL-02: Final Duty & Tax Assessment Model & Serialization Tests', () {
    test('CustomsClearanceModel correctly serializes and parses CL-02 duty breakdown & Nafeza claim fields', () {
      final json = {
        'customs_clearance_id': 502,
        'clearance_code': 'CLR-2026-0502',
        'import_file_id': 95,
        'declaration_46_no': '46-2026-DKH-99881',
        'declaration_46_date': '2026-09-18T10:00:00Z',
        'customs_office_name': 'El Dekheila Port Customs',
        'channel_type': 'Red Channel',
        'cif_base_amount': 623000.0,
        'customs_exchange_rate': 48.50,
        'import_duty_amount': 62300.0,
        'vat_amount': 95942.0,
        'schedule_tax_amount': 6230.0,
        'development_fee_amount': 1500.0,
        'customs_service_fees': 78286.90,
        'wht_amount': 2500.0,
        'lab_service_fees': 1200.0,
        'total_duty_payable': 247958.90,
        'estimated_duty_total': 150000.0,
        'actual_duty_total': 247958.90,
        'duty_variance_amount': 97958.90,
        'duty_variance_percentage': 65.31,
        'duty_variance_reason': 'تعديل بند التعريفة وإضافة رسوم خدمات كشف بالأشعة',
        'nafeza_claim_number': 'CLM-MTS-2026-987654',
        'nafeza_claim_date': '2026-09-18T14:00:00Z',
        'assessment_status': 'Assessed',
        'status': 'Customs Duties Assessed - Ready for Payment',
        'owner': 'Kamal',
        'is_active': true,
        'created_at': '2026-09-18T08:00:00Z',
        'updated_at': '2026-09-18T14:00:00Z',
      };

      final record = CustomsClearanceModel.fromJson(json);

      expect(record.customsClearanceId, 502);
      expect(record.clearanceCode, 'CLR-2026-0502');
      expect(record.importFileId, 95);
      expect(record.cifBaseAmount, 623000.0);
      expect(record.customsExchangeRate, 48.50);
      expect(record.importDutyAmount, 62300.0);
      expect(record.vatAmount, 95942.0);
      expect(record.scheduleTaxAmount, 6230.0);
      expect(record.developmentFeeAmount, 1500.0);
      expect(record.customsServiceFees, 78286.90);
      expect(record.whtAmount, 2500.0);
      expect(record.labServiceFees, 1200.0);
      expect(record.totalDutyPayable, 247958.90);
      expect(record.estimatedDutyTotal, 150000.0);
      expect(record.actualDutyTotal, 247958.90);
      expect(record.dutyVarianceAmount, 97958.90);
      expect(record.dutyVariancePercentage, 65.31);
      expect(record.dutyVarianceReason, 'تعديل بند التعريفة وإضافة رسوم خدمات كشف بالأشعة');
      expect(record.nafezaClaimNumber, 'CLM-MTS-2026-987654');
      expect(record.nafezaClaimDate, '2026-09-18T14:00:00Z');
      expect(record.assessmentStatus, 'Assessed');
      expect(record.status, 'Customs Duties Assessed - Ready for Payment');

      final serialized = record.toJson();
      expect(serialized['cif_base_amount'], 623000.0);
      expect(serialized['customs_exchange_rate'], 48.50);
      expect(serialized['import_duty_amount'], 62300.0);
      expect(serialized['vat_amount'], 95942.0);
      expect(serialized['schedule_tax_amount'], 6230.0);
      expect(serialized['development_fee_amount'], 1500.0);
      expect(serialized['customs_service_fees'], 78286.90);
      expect(serialized['wht_amount'], 2500.0);
      expect(serialized['lab_service_fees'], 1200.0);
      expect(serialized['total_duty_payable'], 247958.90);
      expect(serialized['nafeza_claim_number'], 'CLM-MTS-2026-987654');
      expect(serialized['assessment_status'], 'Assessed');
    });
  });

  group('CL-02: FinalDutyAssessmentDialog Widget Tests', () {
    testWidgets('Renders FinalDutyAssessmentDialog with breakdown sections, variance card, and form validation', (tester) async {
      final sampleFile = ImportFileModel(
        importFileId: 95,
        importFileCode: 'IMP-2026-0095',
        customFileNumber: 'Delta Industrial Machinery',
        companyName: 'Delta Industrial Machinery LLC',
        supplierName: 'Bavaria Tech GmbH',
        portOfDischarge: 'El Dekheila Port',
        deliveryOrderNo: 'DO-2026-HPL-4433',
        form46No: '46-2026-DKH-99881',
        form46Date: '2026-09-18T10:00:00Z',
        form46Status: 'REGISTERED',
        currentModule: 'Phase 7 - Customs Clearance & Inspection',
        currentStage: 'Customs Inspection & Sampling Completed (تم الكشف وسحب العينات)',
        progressPercent: 88.0,
        nextAction: 'احتساب الرسوم والضرائب الجمركية النهائية (CL-02)',
        createdAt: '2026-09-18T08:00:00Z',
        updatedAt: '2026-09-18T12:00:00Z',
      );

      final sampleClearance = CustomsClearanceModel(
        customsClearanceId: 502,
        clearanceCode: 'CLR-2026-0502',
        importFileId: 95,
        estimatedDutyTotal: 150000.0,
        cifBaseAmount: 623000.0,
        customsExchangeRate: 48.50,
        importDutyAmount: 62300.0,
        vatAmount: 95942.0,
        nafezaClaimNumber: 'CLM-MTS-2026-987654',
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
                body: FinalDutyAssessmentDialog(
                  file: sampleFile,
                  clearanceRecord: sampleClearance,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & File Badge
      expect(find.text('احتساب الرسوم والضرائب الجمركية النهائية (CL-02)'), findsOneWidget);
      expect(find.textContaining('IMP-2026-0095'), findsWidgets);
      expect(find.textContaining('MTS'), findsWidgets);

      // Verify Sections
      expect(find.text('بيانات المطالبة الجمركية بنظام نافذة MTS'), findsOneWidget);
      expect(find.text('تفصيل بنود الرسوم والضرائب الجمركية (HS Code Duty Breakdown)'), findsOneWidget);
      expect(find.text('مطابقة الرسوم الفعلية مع التقديرية (Variance Analysis)'), findsOneWidget);

      // Verify Duty Item Labels
      expect(find.text('ضريبة الوارد الجمركية (Import Duty) *'), findsOneWidget);
      expect(find.text('ضريبة القيمة المضافة (VAT) *'), findsOneWidget);
      expect(find.text('ضريبة الجدول (Schedule Tax)'), findsOneWidget);
      expect(find.text('رسم التنمية (Development Fee)'), findsOneWidget);
      expect(find.text('رسوم الخدمات الجمركية وأ.ت.ص'), findsOneWidget);
      expect(find.text('أرباح تجارية وصناعية (WHT)'), findsOneWidget);
      expect(find.text('رسوم التحاليل والمعامل'), findsOneWidget);

      // Verify Variance Card Content
      expect(find.text('الرسوم التقديرية المبدئية'), findsOneWidget);
      expect(find.textContaining('150,000.00 ج.م'), findsOneWidget);
      expect(find.text('إجمالي المطالبة الفعلية'), findsOneWidget);

      // Verify Action Button
      expect(find.text('اعتماد واحتساب الرسوم (CL-02)'), findsOneWidget);
    });
  });
}
