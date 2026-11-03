import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/demurrage_detention/widgets/dual_clock_radar_dialog.dart';
import 'package:frontend/features/suppliers/widgets/route_intelligence_dialog.dart';
import 'package:frontend/features/suppliers/widgets/goeic_verification_dialog.dart';
import 'package:frontend/features/freight_quotations/widgets/rfq_benchmark_dialog.dart';
import 'package:frontend/features/purchase_orders/widgets/po_balance_ledger_dialog.dart';
import 'package:frontend/features/external_service_providers/widgets/partner_scorecard_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/under_bond_release_dialog.dart';
import 'package:frontend/features/customs_tariff/widgets/nafeza_tariff_sync_dialog.dart';

class _MockDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    Map<String, dynamic> responseData = {};

    if (path.contains('dual-clock')) {
      responseData = {
        'carrier_clock': {
          'carrier_name': 'MSC',
          'total_accrued_demurrage_usd': 450.0,
          'demurrage_free_days': 14,
          'demurrage_overdue_days': 3,
          'daily_rate_usd': 150.0,
          'is_demurrage_overdue': true,
          'free_days_remaining': 0,
        },
        'port_storage_clock': {
          'total_accrued_storage_egp': 8500.0,
          'port_storage_free_days': 5,
          'storage_overdue_days': 2,
          'current_tier_rate_egp': 4250.0,
          'current_tier_name': 'الشريحة الأولى',
          'is_storage_overdue': true,
          'warning_72h_active': true,
          'urgent_advice_ar': 'تحذير: سيتم مضاعفة الشريحة خلال 48 ساعة',
        },
      };
    } else if (path.contains('route-intelligence')) {
      responseData = {
        'supplier_id': 1,
        'supplier_name': 'Shanghai Machinery',
        'country_name': 'China',
        'country_code': 'CN',
        'average_cycle_days': 38,
        'executive_recommendation_ar': 'مورد موثوق وأسعاره تنافسية',
        'historical_prices': [],
        'recent_freight': {'freight_cost_usd': 3200},
        'customs_clearance': {'clearance_fee_egp': 4500},
        'operational_notes': [],
      };
    } else if (path.contains('goeic')) {
      responseData = {
        'overall_compliance_verdict': 'CLEARED_FOR_IMPORT',
        'is_decree_43_mandated': true,
        'is_factory_registered': true,
        'factory_registration_number': 'GOEIC-REG-9912',
        'recommended_action_ar': 'مطابق لكافة الاشتراطات',
      };
    } else if (path.contains('benchmark')) {
      responseData = {
        'rfq_id': 1,
        'rfq_code': 'RFQ-2026-001',
        'ranked_quotes': [
          {
            'rank': 1,
            'forwarder_name': 'Panalpina Egypt',
            'total_cost_usd': 2800.0,
            'free_days_pod': 21,
            'transit_days': 24,
            'composite_score': 94.5,
            'is_winner': true,
            'strengths': ['أقل سعر شحن', 'أطول فترة سماح'],
          },
        ],
        'executive_recommendation_ar': 'يوصى بالترسية على شركة Panalpina',
      };
    } else if (path.contains('balance')) {
      responseData = {
        'po_id': 1,
        'po_code': 'PO-2026-001',
        'total_ordered_quantity': 1000.0,
        'total_shipped_quantity': 750.0,
        'total_remaining_quantity': 250.0,
        'total_ordered_fob_usd': 50000.0,
        'total_shipped_fob_usd': 37500.0,
        'total_remaining_fob_usd': 12500.0,
        'fulfillment_percentage': 75.0,
        'is_fully_shipped': false,
        'line_items': [],
      };
    } else if (path.contains('scorecard')) {
      responseData = {
        'provider_id': 1,
        'company_name': 'Al-Buraq',
        'provider_type': 'Customs Broker',
        'composite_score': 92.0,
        'performance_tier': 'Platinum A+',
        'star_rating': 4.8,
        'total_jobs_evaluated': 15,
        'evaluation_summary_ar': 'أداء متميز في التخليص الجمركي',
        'metrics': {
          'avg_clearance_turnaround_days': 3.2,
          'green_channel_rate_pct': 85.0,
        },
        'strengths': ['سرعة الإفراج الجمركي'],
        'improvement_areas': [],
      };
    }

    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Dio createMockDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080'));
    dio.httpClientAdapter = _MockDioAdapter();
    return dio;
  }

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(createMockDio()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  Future<void> pumpDesktop(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(createTestWidget(child));
    await tester.pumpAndSettle();
  }

  group('Frontend Additions UI Tests', () {
    testWidgets('DualClockRadarDialog renders properly', (tester) async {
      await pumpDesktop(
        tester,
        const DualClockRadarDialog(
          trackingId: 1,
          billOfLadingNo: 'BL-TEST-99',
          carrierName: 'MSC',
        ),
      );

      expect(find.byType(DualClockRadarDialog), findsOneWidget);
      expect(find.textContaining('رادار المتابعة المزدوج'), findsOneWidget);
      expect(find.textContaining('غرامات التوكيل'), findsOneWidget);
      expect(find.textContaining('أرضيات هيئة الميناء'), findsOneWidget);
    });

    testWidgets('RouteIntelligenceDialog renders properly', (tester) async {
      await pumpDesktop(
        tester,
        const RouteIntelligenceDialog(
          supplierId: 1,
          supplierName: 'Shanghai Industrial Machinery',
        ),
      );

      expect(find.byType(RouteIntelligenceDialog), findsOneWidget);
      expect(find.textContaining('بطاقة ذكاء المسار'), findsOneWidget);
      expect(find.textContaining('توصية الذكاء الاصطناعي'), findsOneWidget);
    });

    testWidgets('GOEICVerificationDialog renders properly', (tester) async {
      await pumpDesktop(
        tester,
        const GOEICVerificationDialog(
          supplierId: 1,
          supplierName: 'Shanghai Industrial Machinery',
        ),
      );

      expect(find.byType(GOEICVerificationDialog), findsOneWidget);
      expect(find.textContaining('بوابة فحص الرقابة على الصادرات والواردات'), findsOneWidget);
      // Clean initial state: no fabricated execution or verdict before user input
      expect(find.textContaining('مصرح بالشحن'), findsNothing);

      // Enter HS code and check compliance
      await tester.enterText(find.byType(TextFormField).first, '8415820010');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.textContaining('مصرح بالشحن'), findsOneWidget);
    });

    testWidgets('RFQBenchmarkDialog renders properly', (tester) async {
      await pumpDesktop(
        tester,
        const RFQBenchmarkDialog(
          rfqId: 1,
          rfqCode: 'RFQ-2026-001',
        ),
      );

      expect(find.byType(RFQBenchmarkDialog), findsOneWidget);
      expect(find.textContaining('Freight Forwarder Benchmarking'), findsOneWidget);
      expect(find.textContaining('Panalpina Egypt'), findsWidgets);
    });


    testWidgets('POBalanceLedgerDialog renders properly', (tester) async {
      await pumpDesktop(
        tester,
        const POBalanceLedgerDialog(
          poId: 1,
          poCode: 'PO-2026-001',
        ),
      );

      expect(find.byType(POBalanceLedgerDialog), findsOneWidget);
      // Title is pure Arabic now (anti-stacking): no English suffix in parentheses.
      expect(find.text(const AppLocalizationsAr().poBalanceLedgerTitle), findsOneWidget);
      expect(find.textContaining('75.0%'), findsWidgets);
    });

    testWidgets('PartnerScorecardDialog renders properly', (tester) async {
      await pumpDesktop(
        tester,
        const PartnerScorecardDialog(
          providerId: 1,
          providerName: 'Al-Buraq Customs Clearance',
          providerType: 'Customs Broker',
        ),
      );

      expect(find.byType(PartnerScorecardDialog), findsOneWidget);
      expect(find.textContaining('بطاقة تقييم أداء'), findsOneWidget);
      expect(find.textContaining('Platinum A+'), findsOneWidget);
      expect(find.textContaining('92.0 / 100'), findsOneWidget);
    });

    testWidgets('UnderBondReleaseDialog renders properly with segments', (tester) async {
      await pumpDesktop(
        tester,
        const UnderBondReleaseDialog(
          clearanceId: 1,
          declarationNo: 'DEC-46-2026-888',
        ),
      );

      expect(find.byType(UnderBondReleaseDialog), findsOneWidget);
      expect(find.textContaining('مسار الإفراج تحت التحفظ'), findsOneWidget);
      expect(find.text('سحب على عهدة (تحت التحفظ)'), findsOneWidget);
    });

    testWidgets('NafezaTariffSyncDialog renders properly with paste box', (tester) async {
      await pumpDesktop(
        tester,
        const NafezaTariffSyncDialog(),
      );

      expect(find.byType(NafezaTariffSyncDialog), findsOneWidget);
      expect(find.text('Smart Nafeza Tariff & FX Gateway'), findsOneWidget);
    });
  });
}


