import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/demurrage_detention/models/customs_abandonment_model.dart';
import 'package:frontend/features/demurrage_detention/models/port_storage_model.dart';
import 'package:frontend/features/demurrage_detention/models/container_deposit_model.dart';
import 'package:frontend/features/demurrage_detention/services/customs_abandonment_service.dart';
import 'package:frontend/features/demurrage_detention/services/port_storage_service.dart';
import 'package:frontend/features/demurrage_detention/services/container_deposit_service.dart';
import 'package:frontend/features/demurrage_detention/widgets/customs_abandonment_radar_dialog.dart';
import 'package:frontend/features/demurrage_detention/widgets/port_terminal_storage_dialog.dart';
import 'package:frontend/features/demurrage_detention/widgets/container_deposit_ledger_dialog.dart';

import 'package:frontend/features/customs_clearance/models/reexport_protocol_model.dart';
import 'package:frontend/features/customs_clearance/models/inspection_appeal_model.dart';
import 'package:frontend/features/customs_clearance/models/broker_custody_model.dart';
import 'package:frontend/features/customs_clearance/services/reexport_protocol_service.dart';
import 'package:frontend/features/customs_clearance/services/inspection_appeal_service.dart';
import 'package:frontend/features/customs_clearance/services/broker_custody_service.dart';
import 'package:frontend/features/customs_clearance/widgets/reexport_protocol_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/inspection_appeals_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/broker_custody_settlement_dialog.dart';

class FakeCustomsAbandonmentService extends CustomsAbandonmentService {
  FakeCustomsAbandonmentService() : super(Dio());

  @override
  Future<List<CustomsAbandonmentRadarModel>> listRadars({
    String? riskLevel,
    String? portType,
    String? abandonmentStatus,
    String? search,
  }) async => [];

  @override
  Future<CustomsAbandonmentSummaryModel> getSummary() async =>
      CustomsAbandonmentSummaryModel(
        totalRadars: 0,
        normalCount: 0,
        warning15DaysCount: 0,
        critical7DaysCount: 0,
        underInventoryCount: 0,
        extensionPendingCount: 0,
        movedToWarehouseCount: 0,
        auctionScheduledCount: 0,
        resolvedReleasedCount: 0,
        seaportCount: 0,
        dryPortCount: 0,
        airportCount: 0,
      );
}

class FakePortStorageService extends PortStorageService {
  FakePortStorageService() : super(Dio());

  @override
  Future<PortStorageBreakdownModel> calculateStorage({
    required String terminalCode,
    String containerSize = '20ft',
    bool isReefer = false,
    required String gateInDate,
    required String currentOrGateOutDate,
    String? customsReleaseDate,
    bool includeXray = true,
    bool includeScale = true,
  }) async =>
      PortStorageBreakdownModel(
        terminalCode: 'ACCHCO',
        terminalName: 'شركة الإسكندرية لتداول الحاويات',
        containerSize: '20ft',
        isReefer: false,
        gateInDate: '2026-10-01',
        endDate: '2026-10-10',
        totalDays: 10,
        freeDaysAllowed: 3,
        chargeableDays: 7,
        tier1Days: 5,
        tier1Rate: 100.0,
        tier1Amount: 500.0,
        tier2Days: 2,
        tier2Rate: 200.0,
        tier2Amount: 400.0,
        penalDays: 0,
        penalRate: 400.0,
        penalAmount: 0.0,
        storageChargesEgp: 900.0,
        reeferPluggingChargesEgp: 0.0,
        xrayScanFeeEgp: 300.0,
        scaleFeeEgp: 150.0,
        totalPortStorageEgp: 1350.0,
      );
}

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
  Future<DestructionAlertOverviewModel> getDestructionAlerts() async =>
      const DestructionAlertOverviewModel(
        totalActiveDossiers: 0,
        criticalCount: 0,
        urgentCount: 0,
        warningCount: 0,
        normalCount: 0,
        alerts: [],
      );
}

class FakeContainerDepositService extends ContainerDepositService {
  FakeContainerDepositService() : super(Dio());

  @override
  Future<List<ContainerDepositModel>> listDeposits({
    int? importFileId,
    String? carrierName,
    String? refundStatus,
    String? containerNumber,
    bool includeInactive = false,
  }) async => [];

  @override
  Future<ContainerDepositOverviewModel> getOverviewAndAlerts() async =>
      const ContainerDepositOverviewModel(
        totalActiveDeposits: 0,
        totalDepositAmountEgp: 0.0,
        pendingReturnCount: 0,
        claimSubmittedCount: 0,
        overdue30DaysCount: 0,
        overdueDepositAmountEgp: 0.0,
        refundedFullCount: 0,
        refundedPartialCount: 0,
        totalRefundedAmountEgp: 0.0,
        totalDeductionsEgp: 0.0,
        carrierBreakdown: {},
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
  group('Operational Models Serialization Tests', () {
    test('CustomsAbandonmentRadarModel fromJson should parse correctly', () {
      final json = {
        'radar_id': 1,
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-001',
        'port_type': 'SEAPORT',
        'port_name': 'ميناء الإسكندرية',
        'arrival_date': '2026-09-01',
        'max_legal_days': 60,
        'days_in_port': 55,
        'days_remaining': 5,
        'risk_level': 'CRITICAL_7_DAYS',
        'extension_requested': true,
        'extension_granted_until': '2026-11-01',
        'abandonment_status': 'EXTENSION_PENDING',
        'cargo_description': 'خط إنتاج معقم',
      };
      final model = CustomsAbandonmentRadarModel.fromJson(json);
      expect(model.radarId, 1);
      expect(model.daysRemaining, 5);
      expect(model.riskLevel, 'CRITICAL_7_DAYS');
      expect(model.extensionRequested, true);
    });

    test('PortStorageBreakdownModel fromJson should parse tier breakdown', () {
      final json = {
        'terminal_code': 'ACCHCO',
        'terminal_name': 'شركة الإسكندرية لتداول الحاويات',
        'container_size': '40ft',
        'is_reefer': true,
        'gate_in_date': '2026-10-01',
        'end_date': '2026-10-20',
        'total_days': 20,
        'free_days_allowed': 3,
        'chargeable_days': 17,
        'tier1_days': 5,
        'tier1_rate': 150.0,
        'tier1_amount': 750.0,
        'tier2_days': 7,
        'tier2_rate': 300.0,
        'tier2_amount': 2100.0,
        'penal_days': 5,
        'penal_rate': 600.0,
        'penal_amount': 3000.0,
        'storage_charges_egp': 5850.0,
        'reefer_plugging_charges_egp': 4000.0,
        'xray_scan_fee_egp': 500.0,
        'scale_fee_egp': 200.0,
        'total_port_storage_egp': 10550.0,
      };
      final model = PortStorageBreakdownModel.fromJson(json);
      expect(model.totalDays, 20);
      expect(model.freeDaysAllowed, 3);
      expect(model.chargeableDays, 17);
      expect(model.totalPortStorageEgp, 10550.0);
    });

    test('ReexportDossierModel fromJson should parse Egyptian Law 207/2020 fields', () {
      final json = {
        'reexport_id': 10,
        'import_file_id': 202,
        'import_file_code': 'IMP-REEXP-001',
        'rejection_authority': 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)',
        'rejection_decree_number': 'DEC-889',
        'rejection_date': '2026-10-01',
        'legal_reexport_deadline': '2026-10-31',
        'days_remaining_to_destruction': 10,
        'reexport_reason': 'عدم مطابقة الشحنة للمواصفات القياسية المصرية',
        'customs_outbound_declaration_no': 'DECL-OUT-445',
        'supervision_committee_formed': true,
        'customs_officer_in_charge': 'مأمور جمرك أحمد مصطفى',
        'return_booking_number': 'BKG-REV-99',
        'container_numbers': ['MSKU1112223', 'MSKU4445556'],
        'duty_drawback_status': 'PENDING_APPLICATION',
        'duty_amount_refundable_egp': 250000.0,
        'supplier_credit_note_status': 'RECEIVED',
        'credit_note_amount_usd': 45000.0,
        'status': 'CUSTOMS_INSPECTED',
        'is_active': true,
        'created_at': '2026-10-01T12:00:00',
      };
      final model = ReexportDossierModel.fromJson(json);
      expect(model.reexportId, 10);
      expect(model.daysRemainingToDestruction, 10);
      expect(model.containerNumbers.length, 2);
      expect(model.status, ReexportStatus.customsInspected);
      expect(model.dutyDrawbackStatus, DutyDrawbackStatus.pendingApplication);
      expect(model.supplierCreditNoteStatus, SupplierCreditNoteStatus.received);
    });

    test('ContainerDepositModel fromJson should parse EIR tracking details', () {
      final json = {
        'deposit_id': 5,
        'import_file_id': 303,
        'carrier_name': 'Maersk Line',
        'container_number': 'MSKU9988776',
        'container_type': '40HC',
        'deposit_amount_egp': 30000.0,
        'payment_date': '2026-09-15',
        'eir_return_number': 'EIR-100234',
        'eir_return_date': '2026-09-25',
        'container_condition': 'SOUND_CLEAN',
        'deduction_amount_egp': 0.0,
        'refund_status': 'OVERDUE_30_DAYS',
        'days_overdue': 12,
        'dispute_history': [],
        'is_active': true,
        'created_at': '2026-09-15T10:00:00',
      };
      final model = ContainerDepositModel.fromJson(json);
      expect(model.depositId, 5);
      expect(model.carrierName, 'Maersk Line');
      expect(model.depositAmountEgp, 30000.0);
      expect(model.refundStatus, DepositRefundStatus.overdue30Days);
      expect(model.daysOverdue, 12);
    });

    test('InspectionAppealModel fromJson should parse lab progression tiers', () {
      final json = {
        'appeal_id': 7,
        'appeal_code': 'APP-2026-0007',
        'import_file_id': 404,
        'regulatory_authority': 'NFSA',
        'sample_number': 'SMP-NFSA-55',
        'initial_test_result': 'NON_CONFORMING_MICROBIAL',
        'appeal_tier': 'TRIPLICATE_SAMPLE',
        'triplicate_lab_assigned': 'المعمل المركزي لجامعة القاهرة',
        'appeal_result': 'PENDING',
        'is_active': true,
      };
      final model = InspectionAppealModel.fromJson(json);
      expect(model.appealId, 7);
      expect(model.regulatoryAuthority, 'NFSA');
      expect(model.appealTier, AppealTier.triplicateSample);
      expect(model.triplicateLabAssigned, 'المعمل المركزي لجامعة القاهرة');
      expect(model.appealResult, AppealResult.pending);
    });

    test('BrokerCustodyAdvanceModel and SettlementReconciliationModel should parse', () {
      final json = {
        'advance_id': 12,
        'advance_code': 'CUSTODY-2026-0012',
        'import_file_id': 505,
        'broker_id': 2,
        'broker_name': 'مكتب السويس للتخليص الجمركي',
        'advance_amount': 50000.0,
        'disbursement_date': '2026-10-10',
        'payment_method': 'BANK_TRANSFER',
        'status': 'PARTIALLY_SETTLED',
        'settled_amount': 35000.0,
        'remaining_balance': 15000.0,
        'expense_items': [
          {
            'item_id': 1,
            'advance_id': 12,
            'expense_category': 'OFFICIAL_DUTIES_TAXES',
            'is_e_invoice_backed': true,
            'amount': 30000.0,
            'tax_withholding_rate': 0.0,
            'tax_withheld_amount': 0.0,
            'net_settled_amount': 30000.0,
            'approval_status': 'APPROVED',
          },
          {
            'item_id': 2,
            'advance_id': 12,
            'expense_category': 'HANDLING_AND_PORTERAGE',
            'is_e_invoice_backed': false,
            'amount': 5000.0,
            'tax_withholding_rate': 0.01,
            'tax_withheld_amount': 50.0,
            'net_settled_amount': 4950.0,
            'approval_status': 'APPROVED',
          }
        ],
      };
      final model = BrokerCustodyAdvanceModel.fromJson(json);
      expect(model.advanceId, 12);
      expect(model.advanceAmount, 50000.0);
      expect(model.remainingBalance, 15000.0);
      expect(model.expenseItems.length, 2);
      expect(model.expenseItems[1].taxWithheldAmount, 50.0);
    });
  });

  group('Operational Dialogs Smoke Rendering Tests', () {
    testWidgets('CustomsAbandonmentRadarDialog renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsAbandonmentServiceProvider.overrideWithValue(FakeCustomsAbandonmentService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomsAbandonmentRadarDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomsAbandonmentRadarDialog), findsOneWidget);
    });

    testWidgets('PortTerminalStorageDialog renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portStorageServiceProvider.overrideWithValue(FakePortStorageService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PortTerminalStorageDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PortTerminalStorageDialog), findsOneWidget);
    });

    testWidgets('ReexportProtocolDialog renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reexportProtocolServiceProvider.overrideWithValue(FakeReexportProtocolService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReexportProtocolDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReexportProtocolDialog), findsOneWidget);
    });

    testWidgets('ContainerDepositLedgerDialog renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            containerDepositServiceProvider.overrideWithValue(FakeContainerDepositService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ContainerDepositLedgerDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ContainerDepositLedgerDialog), findsOneWidget);
    });

    testWidgets('InspectionAppealsDialog renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inspectionAppealServiceProvider.overrideWithValue(FakeInspectionAppealService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InspectionAppealsDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InspectionAppealsDialog), findsOneWidget);
    });

    testWidgets('BrokerCustodySettlementDialog renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brokerCustodyServiceProvider.overrideWithValue(FakeBrokerCustodyService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BrokerCustodySettlementDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrokerCustodySettlementDialog), findsOneWidget);
    });
  });
}
