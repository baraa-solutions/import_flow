import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/demurrage_detention/models/customs_abandonment_model.dart';
import 'package:frontend/features/demurrage_detention/models/port_storage_model.dart';
import 'package:frontend/features/demurrage_detention/models/container_deposit_model.dart';
import 'package:frontend/features/demurrage_detention/services/customs_abandonment_service.dart';
import 'package:frontend/features/demurrage_detention/services/port_storage_service.dart';
import 'package:frontend/features/demurrage_detention/widgets/customs_abandonment_radar_dialog.dart';
import 'package:frontend/features/demurrage_detention/widgets/port_terminal_storage_dialog.dart';

class FakeCustomsAbandonmentService extends CustomsAbandonmentService {
  FakeCustomsAbandonmentService() : super(Dio());

  @override
  Future<List<CustomsAbandonmentRadarModel>> listRadars({
    String? riskLevel,
    String? portType,
    String? abandonmentStatus,
    String? search,
  }) async {
    return [];
  }

  @override
  Future<CustomsAbandonmentSummaryModel> getSummary() async {
    return CustomsAbandonmentSummaryModel(
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
  }) async {
    return PortStorageBreakdownModel(
      terminalCode: terminalCode,
      terminalName: 'Test Terminal',
      containerSize: containerSize,
      isReefer: isReefer,
      gateInDate: gateInDate,
      endDate: currentOrGateOutDate,
      totalDays: 10,
      freeDaysAllowed: 5,
      chargeableDays: 5,
      tier1Days: 5,
      tier1Rate: 100.0,
      tier1Amount: 500.0,
      tier2Days: 0,
      tier2Rate: 0.0,
      tier2Amount: 0.0,
      penalDays: 0,
      penalRate: 0.0,
      penalAmount: 0.0,
      storageChargesEgp: 500.0,
      reeferPluggingChargesEgp: 0.0,
      xrayScanFeeEgp: 0.0,
      scaleFeeEgp: 0.0,
      totalPortStorageEgp: 500.0,
    );
  }
}

void main() {
  group('Track 1 & 2: Customs Abandonment & Port Storage Models', () {
    test('CustomsAbandonmentRadarModel parses radar item and risk tiers correctly', () {
      final json = {
        'radar_id': 1,
        'import_file_id': 10,
        'import_file_code': 'IMP-2026-0010',
        'port_type': 'SEAPORT',
        'port_name': 'Alexandria Port',
        'arrival_date': '2026-09-01',
        'max_legal_days': 60,
        'days_in_port': 48,
        'days_remaining': 12,
        'risk_level': 'WARNING_15_DAYS',
        'extension_requested': false,
        'official_letter_issued': false,
        'abandonment_status': 'ACTIVE_CLEARING',
        'importer_name': 'Al-Sorour Logistics',
        'cargo_description': 'Machinery Spare Parts',
        'container_numbers': ['MSKU1234567', 'MSKU7654321'],
        'is_active': true,
      };

      final model = CustomsAbandonmentRadarModel.fromJson(json);

      expect(model.radarId, 1);
      expect(model.importFileCode, 'IMP-2026-0010');
      expect(model.portType, 'SEAPORT');
      expect(model.daysInPort, 48);
      expect(model.daysRemaining, 12);
      expect(model.riskLevel, 'WARNING_15_DAYS');
      expect(model.containerNumbers.length, 2);
      expect(model.containerNumbers.first, 'MSKU1234567');
      expect(model.isActive, true);
    });

    test('CustomsAbandonmentSummaryModel aggregates risk counters accurately', () {
      final json = {
        'total_radars': 25,
        'normal_count': 18,
        'warning_15_days_count': 4,
        'critical_7_days_count': 2,
        'under_inventory_count': 1,
        'extension_pending_count': 2,
        'moved_to_warehouse_count': 0,
        'auction_scheduled_count': 0,
        'resolved_released_count': 0,
        'seaport_count': 20,
        'dry_port_count': 5,
        'airport_count': 0,
      };

      final summary = CustomsAbandonmentSummaryModel.fromJson(json);

      expect(summary.totalRadars, 25);
      expect(summary.warning15DaysCount, 4);
      expect(summary.critical7DaysCount, 2);
      expect(summary.underInventoryCount, 1);
      expect(summary.extensionPendingCount, 2);
    });

    test('PortStorageBreakdownModel parses tier calculations and ancillary fees', () {
      final json = {
        'terminal_code': 'ALEX_ACCHCO',
        'terminal_name': 'Alexandria Container Terminal',
        'container_size': '40ft',
        'is_reefer': true,
        'gate_in_date': '2026-10-01',
        'end_date': '2026-10-18',
        'total_days': 17,
        'free_days_allowed': 5,
        'chargeable_days': 12,
        'tier1_days': 5,
        'tier1_rate': 200.0,
        'tier1_amount': 1000.0,
        'tier2_days': 7,
        'tier2_rate': 400.0,
        'tier2_amount': 2800.0,
        'penal_days': 0,
        'penal_rate': 0.0,
        'penal_amount': 0.0,
        'storage_charges_egp': 3800.0,
        'reefer_plugging_charges_egp': 1700.0,
        'xray_scan_fee_egp': 350.0,
        'scale_fee_egp': 150.0,
        'total_port_storage_egp': 6000.0,
        'currency': 'EGP',
        'tier_details': [
          {
            'tier_name': 'الشريحة الأولى (6-10 أيام)',
            'days': 5,
            'rate_per_day': 200.0,
            'total_amount': 1000.0,
          },
          {
            'tier_name': 'الشريحة الثانية (11-17 يوم)',
            'days': 7,
            'rate_per_day': 400.0,
            'total_amount': 2800.0,
          },
        ],
      };

      final breakdown = PortStorageBreakdownModel.fromJson(json);

      expect(breakdown.terminalCode, 'ALEX_ACCHCO');
      expect(breakdown.containerSize, '40ft');
      expect(breakdown.isReefer, true);
      expect(breakdown.chargeableDays, 12);
      expect(breakdown.storageChargesEgp, 3800.0);
      expect(breakdown.reeferPluggingChargesEgp, 1700.0);
      expect(breakdown.xrayScanFeeEgp, 350.0);
      expect(breakdown.scaleFeeEgp, 150.0);
      expect(breakdown.totalPortStorageEgp, 6000.0);
      expect(breakdown.tierDetails.length, 2);
      expect(breakdown.tierDetails.first.ratePerDay, 200.0);
    });

    test('ContainerDepositModel parses deposit, deductions, and balance', () {
      final json = {
        'deposit_id': 5,
        'import_file_id': 12,
        'carrier_id': 2,
        'carrier_name': 'CMA CGM',
        'container_number': 'CMAU9876543',
        'container_type': '40HC',
        'deposit_amount_egp': 25000.0,
        'payment_reference': 'DEP-REF-2026-05',
        'payment_date': '2026-09-15',
        'refund_status': 'CLAIM_SUBMITTED',
        'deduction_amount_egp': 1500.0,
        'deduction_reason': 'Minor floor scratch',
        'days_overdue': 0,
        'is_active': true,
        'created_at': '2026-09-15T10:00:00Z',
      };

      final model = ContainerDepositModel.fromJson(json);

      expect(model.depositId, 5);
      expect(model.carrierName, 'CMA CGM');
      expect(model.containerNumber, 'CMAU9876543');
      expect(model.depositAmountEgp, 25000.0);
      expect(model.deductionAmountEgp, 1500.0);
      expect(model.refundStatus, DepositRefundStatus.claimSubmitted);
      expect(model.daysOverdue, 0);
    });
  });

  group('Track 1 & 2: Widget Rendering Tests', () {
    testWidgets('CustomsAbandonmentRadarDialog renders header and risk filters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsAbandonmentServiceProvider.overrideWithValue(FakeCustomsAbandonmentService()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: CustomsAbandonmentRadarDialog(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify radar header and legal notice
      expect(find.textContaining('رادار المهمل الجمركي'), findsOneWidget);
      expect(find.textContaining('مادة 67'), findsOneWidget);

      // Verify action buttons
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('PortTerminalStorageDialog renders terminal options and date inputs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 750));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portStorageServiceProvider.overrideWithValue(FakePortStorageService()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: PortTerminalStorageDialog(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header title
      expect(find.textContaining('حاسبة ومحرك أرضيات محطات الموانئ المصرية'), findsOneWidget);

      // Verify form sections and terminal dropdown
      expect(find.textContaining('بيانات الحاوية والمحطة'), findsOneWidget);
      expect(find.textContaining('الإسكندرية'), findsWidgets);

      // Verify calculate button
      expect(find.textContaining('إعادة احتساب الرسوم'), findsOneWidget);
    });
  });
}
