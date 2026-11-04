import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/page_header.dart';
import 'package:frontend/features/freight_quotations/models/freight_quotation_model.dart';
import 'package:frontend/features/freight_quotations/screens/freight_quotations_comparison_screen.dart';
import 'package:frontend/features/freight_quotations/widgets/rfq_benchmark_dialog.dart';
import 'package:frontend/features/freight_quotations/services/freight_quotations_export_service.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('benchmark')) {
      final jsonStr = jsonEncode({
        'rfq_id': 101,
        'rfq_code': 'RFQ-2026-001',
        'title': 'مقارنة عروض الشحن',
        'top_three_quotes': [
          {
            'rank': 1,
            'quotation_id': 2,
            'provider_name': 'MSC Mediterranean Shipping',
            'total_cost': 3250.0,
            'transit_days': 20,
            'free_days_at_pod': 21,
            'cost_score': 50.0,
            'free_days_score': 18.8,
            'transit_score': 15.0,
            'reliability_score': 8.5,
            'composite_score': 92.3,
            'key_advantages': ['أقل سعر إجمالي شامل'],
          }
        ],
        'all_ranked_quotes': [],
        'executive_recommendation_ar': 'التوصية التنفيذية للاعتماد: يوصى بحجز الشحنة على العرض التنافسي الأول [MSC Mediterranean Shipping].',
      });
      return ResponseBody.fromString(jsonStr, 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpClientAdapter();
  return dio;
}

void main() {
  final sampleRfqJson = {
    'rfq_id': 101,
    'rfq_code': 'RFQ-2026-001',
    'title': 'طلب عروض أسعار لنقل معدات وخطوط إنتاج',
    'import_file_id': 501,
    'import_file_code': 'IMP-2026-0099',
    'shipping_method': 'Ocean FCL',
    'crd_date': '2026-10-01',
    'pol_id': 10,
    'pol_name': 'Ningbo Port (CN NGB)',
    'pod_id': 20,
    'pod_name': 'Alexandria Port (EG ALX)',
    'total_cbm': 120.0,
    'total_gross_weight_kg': 45000.0,
    'chargeable_weight_kg': 45000.0,
    'status': 'Awarded',
    'selected_quotation_id': 2,
    'awarded_provider_name': 'MSC Mediterranean Shipping',
    'total_quotations_count': 2,
    'lowest_freight_cost': 3250.0,
    'average_freight_cost': 3500.0,
    'fastest_transit_days': 20,
    'average_transit_days': 22.0,
    'created_at': '2026-09-17T12:00:00Z',
    'updated_at': '2026-09-17T12:05:00Z',
    'quotations': [
      {
        'quotation_id': 1,
        'rfq_id': 101,
        'provider_id': 1,
        'provider_name': 'Maersk Line',
        'vessel_name': 'MAERSK KINLOSS',
        'currency_code': 'USD',
        'ocean_freight_cost': 3200.0,
        'local_charges_cost': 350.0,
        'inland_cost': 200.0,
        'total_cost': 3750.0,
        'sailing_date': '2026-10-05',
        'estimated_arrival_date': '2026-10-29',
        'transit_days': 24,
        'free_days_at_pod': 14,
        'is_awarded': false,
      },
      {
        'quotation_id': 2,
        'rfq_id': 101,
        'provider_id': 2,
        'provider_name': 'MSC Mediterranean Shipping',
        'vessel_name': 'MSC OSCAR',
        'currency_code': 'USD',
        'ocean_freight_cost': 2750.0,
        'local_charges_cost': 300.0,
        'inland_cost': 200.0,
        'total_cost': 3250.0,
        'sailing_date': '2026-10-06',
        'estimated_arrival_date': '2026-10-26',
        'transit_days': 20,
        'free_days_at_pod': 21,
        'is_awarded': true,
      },
    ],
  };

  group('PL-06: Freight RFQ Models & Serialization Tests', () {
    test('FreightRFQRequestModel parses accurately with quotation items', () {
      final model = FreightRFQRequestModel.fromJson(sampleRfqJson);

      expect(model.rfqId, 101);
      expect(model.rfqCode, 'RFQ-2026-001');
      expect(model.title, 'طلب عروض أسعار لنقل معدات وخطوط إنتاج');
      expect(model.importFileId, 501);
      expect(model.importFileCode, 'IMP-2026-0099');
      expect(model.status, 'Awarded');
      expect(model.selectedQuotationId, 2);
      expect(model.awardedProviderName, 'MSC Mediterranean Shipping');
      expect(model.lowestFreightCost, 3250.0);
      expect(model.fastestTransitDays, 20);
      expect(model.quotations.length, 2);

      final q1 = model.quotations[0];
      expect(q1.providerName, 'Maersk Line');
      expect(q1.totalCost, 3750.0);
      expect(q1.isAwarded, false);

      final q2 = model.quotations[1];
      expect(q2.providerName, 'MSC Mediterranean Shipping');
      expect(q2.totalCost, 3250.0);
      expect(q2.isAwarded, true);
      expect(q2.freeDaysAtPod, 21);

      final json = model.toJson();
      expect(json['rfq_id'], 101);
      expect(json['rfq_code'], 'RFQ-2026-001');
      expect((json['quotations'] as List).length, 2);
    });

    test('FreightQuotationItemModel copyWith updates fields correctly', () {
      final item = FreightQuotationItemModel.fromJson((sampleRfqJson['quotations'] as List)[0] as Map<String, dynamic>);
      final updated = item.copyWith(
        isAwarded: true,
        totalCost: 3500.0,
      );

      expect(updated.isAwarded, true);
      expect(updated.totalCost, 3500.0);
      expect(updated.providerName, 'Maersk Line');
    });
  });

  group('PL-06: AI-BENCH-007 Benchmark Scoring & Recommendation Parsing', () {
    final benchmarkSampleJson = {
      'rfq_id': 101,
      'rfq_code': 'RFQ-2026-001',
      'title': 'مقارنة وتقييم عروض شحن',
      'route': 'Ningbo Port (CN NGB) ──> Alexandria Port (EG ALX)',
      'total_quotes_analyzed': 2,
      'average_cost_usd': 3500.0,
      'executive_recommendation_ar':
          'التوصية التنفيذية للاعتماد: يوصى بحجز الشحنة على العرض التنافسي الأول [MSC Mediterranean Shipping] بإجمالي تكلفة \$3,250.00 USD.',
      'top_three_quotes': [
        {
          'rank': 1,
          'quotation_id': 2,
          'provider_id': 2,
          'provider_name': 'MSC Mediterranean Shipping',
          'vessel_name': 'MSC OSCAR',
          'total_cost': 3250.0,
          'currency_code': 'USD',
          'transit_days': 20,
          'free_days_at_pod': 21,
          'cost_score': 50.0,
          'free_days_score': 18.8,
          'transit_score': 15.0,
          'reliability_score': 8.5,
          'composite_score': 92.3,
          'cost_saving_vs_average': 250.0,
          'key_advantages': ['أقل سعر إجمالي شامل', 'أسرع زمن ترانزيت (20 يوماً)', 'وفر مالي بقيمة \$250.00'],
        },
        {
          'rank': 2,
          'quotation_id': 1,
          'provider_id': 1,
          'provider_name': 'Maersk Line',
          'vessel_name': 'MAERSK KINLOSS',
          'total_cost': 3750.0,
          'currency_code': 'USD',
          'transit_days': 24,
          'free_days_at_pod': 14,
          'cost_score': 0.0,
          'free_days_score': 12.5,
          'transit_score': 0.0,
          'reliability_score': 8.5,
          'composite_score': 21.0,
          'cost_saving_vs_average': -250.0,
          'key_advantages': ['فترة سماح قياسية (14 يوماً)'],
        },
      ],
      'all_ranked_quotes': [],
    };

    test('Validates multi-criteria scoring calculations and weights', () {
      final topQuote = (benchmarkSampleJson['top_three_quotes'] as List)[0];
      expect(topQuote['rank'], 1);
      expect(topQuote['provider_name'], 'MSC Mediterranean Shipping');
      expect(topQuote['cost_score'], 50.0);
      expect(topQuote['transit_score'], 15.0);
      expect(topQuote['composite_score'], 92.3);
      expect((topQuote['key_advantages'] as List).contains('أقل سعر إجمالي شامل'), true);
      expect(benchmarkSampleJson['executive_recommendation_ar'].toString(), contains('MSC Mediterranean Shipping'));
    });
  });

  group('PL-06: Freight Quotations Comparison Screen UI Tests', () {
    testWidgets('FreightQuotationsComparisonScreen renders selector, app bar, and empty prompt', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final testDio = _createTestDio();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(testDio),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: FreightQuotationsComparisonScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar title (canonical PageHeader replaced the plain AppBar)
      expect(find.byType(FreightQuotationsComparisonScreen), findsOneWidget);
      expect(find.byType(PageHeader), findsOneWidget);

      // Import File selection area
      expect(find.byType(SelectionArea), findsOneWidget);
    });
  });

  group('PL-06: RFQ Benchmark Dialog & Award Button Tests', () {
    testWidgets('RFQBenchmarkDialog renders header and interactive layout', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 750));
      final testDio = _createTestDio();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(testDio),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: RFQBenchmarkDialog(rfqId: 101, rfqCode: 'RFQ-2026-001'),
                ),
              ),
            ),
          ),
        ),
      );

      // Settle network future with mock adapter
      await tester.pumpAndSettle();

      expect(find.byType(RFQBenchmarkDialog), findsOneWidget);
      expect(find.textContaining('المفاضلة التنافسية'), findsOneWidget);
      expect(find.textContaining('التوصية التنفيذية لاعتماد العرض الفائز'), findsOneWidget);
      expect(find.byKey(const Key('awardWinnerBtn')), findsOneWidget);
      expect(find.text('اعتماد هذا العرض الفائز 🎯'), findsOneWidget);
    });
  });

  group('PL-06: Freight Quotations Multi-Format Exports Tests', () {
    testWidgets('FreightQuotationsExportService builds comprehensive Dossier text', (WidgetTester tester) async {
      final sampleQuotes = (sampleRfqJson['quotations'] as List).map((q) => q as Map<String, dynamic>).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (context) {
                  final dossier = FreightQuotationsExportService.buildDossierText(
                    context: context,
                    quotations: sampleQuotes,
                    importFileCode: 'IMP-2026-0099',
                    supplierName: 'Global Machinery Ltd.',
                  );

                  expect(dossier, isNotEmpty);
                  expect(dossier, contains('IMP-2026-0099'));
                  expect(dossier, contains('MSC Mediterranean Shipping'));
                  expect(dossier, contains('Maersk Line'));

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
    });
  });
}
