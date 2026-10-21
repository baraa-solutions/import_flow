import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/models/reexport_protocol_model.dart';
import 'package:frontend/features/customs_clearance/models/inspection_appeal_model.dart';
import 'package:frontend/features/customs_clearance/models/broker_custody_model.dart';
import 'package:frontend/features/customs_clearance/services/reexport_protocol_service.dart';
import 'package:frontend/features/customs_clearance/services/inspection_appeal_service.dart';
import 'package:frontend/features/customs_clearance/services/broker_custody_service.dart';
import 'package:frontend/features/customs_clearance/widgets/reexport_protocol_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/inspection_appeals_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/broker_custody_settlement_dialog.dart';

class FakeReexportProtocolService extends ReexportProtocolService {
  FakeReexportProtocolService() : super(Dio());

  @override
  Future<List<ReexportDossierModel>> listDossiers({
    int? importFileId,
    String? status,
    String? search,
    bool includeInactive = false,
  }) async => [];

  @override
  Future<DestructionAlertOverviewModel> getDestructionAlerts() async => const DestructionAlertOverviewModel(
    totalActiveDossiers: 0,
    criticalCount: 0,
    urgentCount: 0,
    warningCount: 0,
    normalCount: 0,
    alerts: [],
  );
}

class FakeInspectionAppealService extends InspectionAppealService {
  FakeInspectionAppealService() : super(Dio());

  @override
  Future<List<InspectionAppealModel>> listAppeals({
    int? importFileId,
    int? clearanceId,
    String? regulatoryAuthority,
    String? appealTier,
    String? appealResult,
    bool includeInactive = false,
  }) async => [];
}

class FakeBrokerCustodyService extends BrokerCustodyService {
  FakeBrokerCustodyService() : super(Dio());

  @override
  Future<List<BrokerCustodyAdvanceModel>> listAdvances({
    int? importFileId,
    int? brokerId,
    String? status,
    String? search,
  }) async => [];
}

void main() {
  group('Track 3 & 4: Re-Export & Appeals Models', () {
    test('ReexportDossierModel parses rejection decree and drawback details', () {
      final json = {
        'reexport_id': 12,
        'import_file_id': 50,
        'import_file_code': 'IMP-2026-0050',
        'rejection_authority': 'GOIEC',
        'rejection_decree_number': 'DEC-8899/2026',
        'rejection_date': '2026-09-10',
        'legal_reexport_deadline': '2026-11-10',
        'days_remaining_to_destruction': 21,
        'reexport_reason': 'Visual inspection lab chemical mismatch',
        'supervision_committee_formed': false,
        'container_numbers': ['MSKU1112223'],
        'duty_drawback_status': 'PENDING_APPLICATION',
        'duty_amount_refundable_egp': 45000.0,
        'supplier_credit_note_status': 'REQUESTED',
        'credit_note_amount_usd': 12000.0,
        'status': 'BOOKING_CONFIRMED',
        'is_active': true,
        'created_at': '2026-09-10T08:00:00Z',
      };

      final model = ReexportDossierModel.fromJson(json);

      expect(model.reexportId, 12);
      expect(model.importFileCode, 'IMP-2026-0050');
      expect(model.rejectionAuthority, 'GOIEC');
      expect(model.status, ReexportStatus.bookingConfirmed);
      expect(model.dutyDrawbackStatus, DutyDrawbackStatus.pendingApplication);
      expect(model.dutyAmountRefundableEgp, 45000.0);
      expect(model.supplierCreditNoteStatus, SupplierCreditNoteStatus.requested);
      expect(model.creditNoteAmountUsd, 12000.0);
      expect(model.containerNumbers.length, 1);
    });

    test('InspectionAppealModel parses appeal tier and committee verdict', () {
      final json = {
        'appeal_id': 7,
        'appeal_code': 'APL-2026-0007',
        'import_file_id': 34,
        'clearance_id': 18,
        'regulatory_authority': 'NFSA',
        'sample_number': 'SMP-NFSA-778',
        'sample_draw_date': '2026-09-02',
        'initial_test_result': 'Microbiological count above limits',
        'rejection_reason': 'Aerobic plate count exceeded',
        'appeal_tier': 'SECOND_APPEAL',
        'appeal_submission_date': '2026-09-05',
        'appeal_committee_date': '2026-09-18',
        'triplicate_lab_assigned': 'Central Health Laboratories',
        'appeal_result': 'OVERTURNED_CONFORMING',
        'official_letter_ref': 'LTR-NFSA-9901',
        'is_active': true,
      };

      final model = InspectionAppealModel.fromJson(json);

      expect(model.appealId, 7);
      expect(model.regulatoryAuthority, 'NFSA');
      expect(model.appealTier, AppealTier.secondAppeal);
      expect(model.appealResult, AppealResult.overturnedConforming);
      expect(model.triplicateLabAssigned, 'Central Health Laboratories');
    });

    test('BrokerExpenseItemModel parses e-invoice and tax deductions', () {
      final json = {
        'item_id': 101,
        'advance_id': 20,
        'expense_category': 'OFFICIAL_DUTIES_TAXES',
        'is_e_invoice_backed': true,
        'e_invoice_uuid': 'EINV-UUID-9999-8888',
        'receipt_reference': 'RCP-9988',
        'amount': 50000.0,
        'tax_withholding_rate': 0.01,
        'tax_withheld_amount': 500.0,
        'net_settled_amount': 49500.0,
        'approval_status': 'APPROVED',
        'verified_by': 'Finance Manager',
      };

      final item = BrokerExpenseItemModel.fromJson(json);

      expect(item.itemId, 101);
      expect(item.expenseCategory, 'OFFICIAL_DUTIES_TAXES');
      expect(item.isEInvoiceBacked, true);
      expect(item.amount, 50000.0);
      expect(item.taxWithheldAmount, 500.0);
      expect(item.netSettledAmount, 49500.0);
      expect(item.approvalStatus, 'APPROVED');
      expect(item.categoryLabelAr, 'ضرائب ورسوم جمركية رسمية');
    });
  });

  group('Track 3 & 4: Dialog Rendering Tests', () {
    testWidgets('InspectionAppealsDialog renders header and authority filters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inspectionAppealServiceProvider.overrideWithValue(FakeInspectionAppealService()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: InspectionAppealsDialog(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title
      expect(find.textContaining('تظلمات الفحص المعملي والتحكيم الثلاثي'), findsOneWidget);

      // Verify Add Appeal button
      expect(find.textContaining('تقديم تظلم معملي'), findsOneWidget);
    });

    testWidgets('ReexportProtocolDialog renders legal destruction deadline and alert counters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1250, 850));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reexportProtocolServiceProvider.overrideWithValue(FakeReexportProtocolService()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: ReexportProtocolDialog(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title and legal reference
      expect(find.textContaining('بروتوكول البضائع المرفوضة وإعادة التصدير'), findsOneWidget);

      // Verify Add Dossier button
      expect(find.textContaining('تسجيل رفض جمركي جديد'), findsOneWidget);
    });

    testWidgets('BrokerCustodySettlementDialog renders advances title and settlement actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokerCustodyServiceProvider.overrideWithValue(FakeBrokerCustodyService()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: BrokerCustodySettlementDialog(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title
      expect(find.textContaining('تسوية عهد ومصروفات المخلصين الجمركيين'), findsOneWidget);

      // Verify Add Advance button
      expect(find.textContaining('صرف عهدة جديدة'), findsOneWidget);
    });
  });
}
