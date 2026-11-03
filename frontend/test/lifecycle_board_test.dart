import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/lifecycle_board/models/lifecycle_board_model.dart';
import 'package:frontend/features/lifecycle_board/providers/lifecycle_board_provider.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';

void main() {
  group('Lifecycle Board Model Tests', () {
    test('PhaseSummaryModel and LifecycleBoardSummaryModel JSON parsing', () {
      final json = {
        'phases': [
          {
            'phase_id': 1,
            'title_en': '1. Pre-Planning & Studies',
            'title_ar': 'المرحلة الأولى: التخطيط والدراسات المسبقة',
            'color_hex': '#D97706',
            'step_codes': ['STEP_01', 'STEP_02', 'STEP_03'],
            'total_active_shipments': 2,
            'step_counts': {'STEP_01': 1, 'STEP_02': 1, 'STEP_03': 0},
            'pending_shipments_count': 3,
            'delayed_shipments_count': 1,
          }
        ],
        'total_active_files': 1,
        'all_shipments': [
          {
            'import_file_code': 'IMP-2026-0001',
            'company_name': 'Al-Ahram Industrial',
            'supplier_name': 'Global Steel Italy',
            'po_number': 'PO-2026-101',
            'shipment_mode': 'Sea FCL',
            'incoterm_code': 'FOB',
            'priority': 'High',
            'estimated_cost': 45000.0,
            'estimated_cost_currency': 'USD',
            'step_code': 'STEP_02',
            'step_name_en': 'Customs Studies',
            'step_name_ar': 'الدراسات والاستشارات الجمركية',
            'previous_step_code': 'STEP_01',
            'previous_step_name_en': 'Freight Studies',
            'previous_step_name_ar': 'دراسات ومفاضلة نولون الشحن',
            'next_step_code': 'STEP_03',
            'next_step_name_en': 'Import Regulatory Requirements',
            'next_step_name_ar': 'متطلبات واشتراطات الاستيراد للشحنة',
            'status': 'In-Progress',
            'started_at': '2026-08-17 12:00:00',
            'notes': 'Comparing freight rates',
            'pending_step_codes': ['STEP_02', 'STEP_03'],
            'skipped_step_codes': ['STEP_01'],
            'kpi_metrics': {
              'health_score': 85.5,
              'free_time_burn_pct': 42.0,
              'free_days_remaining': 8,
              'overdue_steps_count': 2,
              'cost_variance_pct': 5.2,
              'risk_level': 'WARNING',
            },
          }
        ],
      };

      final model = LifecycleBoardSummaryModel.fromJson(json);
      expect(model.phases.length, 1);
      expect(model.phases[0].phaseId, 1);
      expect(model.phases[0].totalActiveShipments, 2);
      expect(model.phases[0].pendingShipmentsCount, 3);
      expect(model.phases[0].delayedShipmentsCount, 1);
      expect(model.totalActiveFiles, 1);
      expect(model.allShipments.length, 1);
      expect(model.allShipments[0].importFileCode, 'IMP-2026-0001');
      expect(model.allShipments[0].estimatedCost, 45000.0);
      expect(model.allShipments[0].stepCode, 'STEP_02');
      expect(model.allShipments[0].previousStepCode, 'STEP_01');
      expect(model.allShipments[0].previousStepNameAr, 'دراسات ومفاضلة نولون الشحن');
      expect(model.allShipments[0].nextStepCode, 'STEP_03');
      expect(model.allShipments[0].nextStepNameAr, 'متطلبات واشتراطات الاستيراد للشحنة');

      // Check new fields
      expect(model.allShipments[0].pendingStepCodes, ['STEP_02', 'STEP_03']);
      expect(model.allShipments[0].skippedStepCodes, ['STEP_01']);
      expect(model.allShipments[0].kpiMetrics, isNotNull);
      expect(model.allShipments[0].kpiMetrics!.healthScore, 85.5);
      expect(model.allShipments[0].kpiMetrics!.freeTimeBurnPct, 42.0);
      expect(model.allShipments[0].kpiMetrics!.freeDaysRemaining, 8);
      expect(model.allShipments[0].kpiMetrics!.overdueStepsCount, 2);
      expect(model.allShipments[0].kpiMetrics!.costVariancePct, 5.2);
      expect(model.allShipments[0].kpiMetrics!.riskLevel, 'WARNING');
    });

    test('ShipmentKpiMetricsModel toJson and fromJson round-trip', () {
      final metrics = ShipmentKpiMetricsModel(
        healthScore: 92.0,
        freeTimeBurnPct: 15.5,
        freeDaysRemaining: 12,
        overdueStepsCount: 0,
        costVariancePct: -2.3,
        riskLevel: 'SAFE',
      );

      final json = metrics.toJson();
      expect(json['health_score'], 92.0);
      expect(json['free_time_burn_pct'], 15.5);
      expect(json['free_days_remaining'], 12);
      expect(json['overdue_steps_count'], 0);
      expect(json['cost_variance_pct'], -2.3);
      expect(json['risk_level'], 'SAFE');

      final reconstructed = ShipmentKpiMetricsModel.fromJson(json);
      expect(reconstructed.healthScore, metrics.healthScore);
      expect(reconstructed.freeTimeBurnPct, metrics.freeTimeBurnPct);
      expect(reconstructed.freeDaysRemaining, metrics.freeDaysRemaining);
      expect(reconstructed.overdueStepsCount, metrics.overdueStepsCount);
      expect(reconstructed.costVariancePct, metrics.costVariancePct);
      expect(reconstructed.riskLevel, metrics.riskLevel);
    });

    test('PhaseSummaryModel defaults pending and delayed counts to 0', () {
      final json = {
        'phase_id': 2,
        'title_en': '2. Origin Customs',
        'title_ar': 'المرحلة الثانية',
        'color_hex': '#10B981',
        'step_codes': ['STEP_04'],
        'total_active_shipments': 0,
        'step_counts': {},
      };

      final phase = PhaseSummaryModel.fromJson(json);
      expect(phase.pendingShipmentsCount, 0);
      expect(phase.delayedShipmentsCount, 0);
    });
  });

  group('Lifecycle Board Localization Tests', () {
    test('Arabic localization keys are pure without English parentheses', () {
      const ar = AppLocalizationsAr();
      expect(ar.kpiHealthScore, 'معدل الإنجاز');
      expect(ar.kpiFreeTimeBurn, 'استهلاك السماح');
      expect(ar.kpiDaysLeft, 'أيام متبقية');
      expect(ar.kpiOverdueSteps, 'خطوات متأخرة');
      expect(ar.kpiCostVariance, 'انحراف التكلفة');
      expect(ar.kpiRiskSafe, 'آمن');
      expect(ar.kpiRiskWarning, 'تحذير');
      expect(ar.kpiRiskCritical, 'حرج');
      expect(ar.phasePendingCount, 'شحنات معلقة');
      expect(ar.phaseDelayedCount, 'شحنات متأخرة');

      // Check no English parentheses
      final values = [
        ar.kpiHealthScore,
        ar.kpiFreeTimeBurn,
        ar.kpiDaysLeft,
        ar.kpiOverdueSteps,
        ar.kpiCostVariance,
        ar.kpiRiskSafe,
        ar.kpiRiskWarning,
        ar.kpiRiskCritical,
        ar.phasePendingCount,
        ar.phaseDelayedCount,
      ];
      for (final v in values) {
        expect(v.contains('('), isFalse);
        expect(v.contains(')'), isFalse);
      }
    });

    test('English localization keys are pure without Arabic text', () {
      const en = AppLocalizationsEn();
      expect(en.kpiHealthScore, 'Completion Rate');
      expect(en.kpiFreeTimeBurn, 'Free Time Burn');
      expect(en.kpiDaysLeft, 'Days Remaining');
      expect(en.kpiOverdueSteps, 'Overdue Steps');
      expect(en.kpiCostVariance, 'Cost Variance');
      expect(en.kpiRiskSafe, 'Safe');
      expect(en.kpiRiskWarning, 'Warning');
      expect(en.kpiRiskCritical, 'Critical');
      expect(en.phasePendingCount, 'Pending Shipments');
      expect(en.phaseDelayedCount, 'Delayed Shipments');
    });

    test('ARB files match required keys and valid JSON', () {
      final arFile = File('lib/core/localization/app_ar.arb');
      expect(arFile.existsSync(), isTrue);
      final arMap = json.decode(arFile.readAsStringSync()) as Map<String, dynamic>;
      expect(arMap['kpiHealthScore'], 'معدل الإنجاز');
      expect(arMap['kpiFreeTimeBurn'], 'استهلاك السماح');
      expect(arMap['kpiDaysLeft'], 'أيام متبقية');
      expect(arMap['kpiOverdueSteps'], 'خطوات متأخرة');
      expect(arMap['kpiCostVariance'], 'انحراف التكلفة');
      expect(arMap['kpiRiskSafe'], 'آمن');
      expect(arMap['kpiRiskWarning'], 'تحذير');
      expect(arMap['kpiRiskCritical'], 'حرج');
      expect(arMap['phasePendingCount'], 'شحنات معلقة');
      expect(arMap['phaseDelayedCount'], 'شحنات متأخرة');

      final enFile = File('lib/core/localization/app_en.arb');
      expect(enFile.existsSync(), isTrue);
      final enMap = json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;
      expect(enMap['kpiHealthScore'], 'Completion Rate');
      expect(enMap['kpiFreeTimeBurn'], 'Free Time Burn');
      expect(enMap['kpiDaysLeft'], 'Days Remaining');
      expect(enMap['kpiOverdueSteps'], 'Overdue Steps');
      expect(enMap['kpiCostVariance'], 'Cost Variance');
      expect(enMap['kpiRiskSafe'], 'Safe');
      expect(enMap['kpiRiskWarning'], 'Warning');
      expect(enMap['kpiRiskCritical'], 'Critical');
      expect(enMap['phasePendingCount'], 'Pending Shipments');
      expect(enMap['phaseDelayedCount'], 'Delayed Shipments');
    });
  });

  group('Lifecycle Board Filter Provider Tests', () {
    test('Filter providers have correct default values and can be updated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hasPendingInPhaseFilterProvider), isFalse);
      expect(container.read(riskLevelFilterProvider), isNull);

      container.read(hasPendingInPhaseFilterProvider.notifier).state = true;
      expect(container.read(hasPendingInPhaseFilterProvider), isTrue);

      container.read(riskLevelFilterProvider.notifier).state = 'CRITICAL';
      expect(container.read(riskLevelFilterProvider), 'CRITICAL');
    });
  });
}
