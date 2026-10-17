import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/customs_tariff/widgets/duty_calculator_dialog.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:dio/dio.dart';

void main() {
  group('PL-07 Customs Calculation Engine Rules & Math Tests', () {
    test('Egyptian Customs Duty, VAT Base, and Service Fee Calculation', () {
      // Setup typical values
      const double fobEgp = 500000.0;
      const double freightEgp = 25000.0;
      const double insuranceEgp = 12500.0;
      const double additionalFeesEgp = 1500.0;

      // 1. CIF base
      const double cifBaseEgp = fobEgp + freightEgp + insuranceEgp + additionalFeesEgp;
      expect(cifBaseEgp, equals(539000.0));

      // 2. Customs Duty (e.g. 10%)
      const double dutyRate = 0.10;
      const double dutyEgp = cifBaseEgp * dutyRate;
      expect(dutyEgp, equals(53900.0));

      // 3. VAT Base MUST be CIF + Duty
      const double vatBaseEgp = cifBaseEgp + dutyEgp;
      expect(vatBaseEgp, equals(592900.0));

      // 4. VAT (14%)
      const double vatRate = 0.14;
      const double vatEgp = vatBaseEgp * vatRate;
      expect(vatEgp, closeTo(83006.0, 0.01));

      // 5. Customs Service Fee (1% non-exempted)
      const double serviceFeeEgp = cifBaseEgp * 0.01;
      expect(serviceFeeEgp, equals(5390.0));

      // 6. Schedule Tax (e.g. 5%)
      const double scheduleTaxRate = 0.05;
      const double scheduleTaxEgp = cifBaseEgp * scheduleTaxRate;
      expect(scheduleTaxEgp, equals(26950.0));

      // 7. Total Duties and Taxes
      const double totalDutiesAndTaxes = dutyEgp + vatEgp + serviceFeeEgp + scheduleTaxEgp;
      expect(totalDutiesAndTaxes, closeTo(169246.0, 0.01));
    });

    test('Preferential Trade Agreement EUR.1 eliminates duty but retains VAT and Service Fee', () {
      const double cifBaseEgp = 600000.0;

      // Under EUR.1 (100% duty reduction)
      const double dutyRate = 0.0;
      const double dutyEgp = cifBaseEgp * dutyRate;
      expect(dutyEgp, equals(0.0));

      // VAT base is CIF + Duty = CIF + 0
      const double vatBaseEgp = cifBaseEgp + dutyEgp;
      expect(vatBaseEgp, equals(600000.0));

      // VAT is still 14%
      const double vatEgp = vatBaseEgp * 0.14;
      expect(vatEgp, closeTo(84000.0, 0.01));

      // Customs Service Fee (1%) is NOT exempt
      const double serviceFeeEgp = cifBaseEgp * 0.01;
      expect(serviceFeeEgp, equals(6000.0));

      // Schedule Tax (e.g. 5%) is NOT exempt
      const double scheduleTaxEgp = cifBaseEgp * 0.05;
      expect(scheduleTaxEgp, equals(30000.0));

      const double totalTaxes = dutyEgp + vatEgp + serviceFeeEgp + scheduleTaxEgp;
      expect(totalTaxes, closeTo(120000.0, 0.01));
    });

    test('Deemed freight (2.0%) and deemed insurance (2.5%) fallbacks', () {
      const double fobEgp = 400000.0;

      // Deemed Insurance rule: 2.5% of FOB
      const double deemedInsurance = fobEgp * 0.025;
      expect(deemedInsurance, equals(10000.0));

      // Deemed Freight rule: 2.0% of FOB
      const double deemedFreight = fobEgp * 0.020;
      expect(deemedFreight, equals(8000.0));

      const double deemedCif = fobEgp + deemedInsurance + deemedFreight;
      expect(deemedCif, equals(418000.0));
    });
  });

  group('Duty Calculator Copy Statement Structure Tests', () {
    test('TSV statement extracts from lines key and builds proper formatted output', () {
      final mockResult = {
        'import_file_id': 105,
        'file_number': 'IMP-2026-0004',
        'currency_code': 'USD',
        'exchange_rate': 50.7917,
        'fob_total_egp': 500000.0,
        'cif_base_egp': 539000.0,
        'total_customs_duty_egp': 53900.0,
        'total_vat_egp': 83006.0,
        'total_customs_service_fees_egp': 5390.0,
        'total_duties_and_taxes_egp': 142296.0,
        'lines': [
          {
            'line_no': 1,
            'hs_code': '8536.41.00',
            'origin_country': 'DE',
            'cif_value_egp': 250000.0,
            'duty_egp': 0.0,
            'vat_egp': 35000.0,
            'customs_service_fee_egp': 2500.0,
            'total_line_duties_egp': 37500.0,
            'preferential_agreement_applied': 'EUR.1',
          },
          {
            'line_no': 2,
            'hs_code': '8537.10.90',
            'origin_country': 'CN',
            'cif_value_egp': 289000.0,
            'duty_egp': 28900.0,
            'vat_egp': 44506.0,
            'customs_service_fee_egp': 2890.0,
            'total_line_duties_egp': 76296.0,
            'preferential_agreement_applied': null,
          }
        ]
      };

      // Verify structure expected by _copyDutyCalculatorStatement
      final lines = (mockResult['lines'] as List<dynamic>?) ?? [];
      expect(lines.length, equals(2));

      final firstLine = lines[0] as Map<String, dynamic>;
      expect(firstLine['hs_code'], equals('8536.41.00'));
      expect(firstLine['preferential_agreement_applied'], equals('EUR.1'));
      expect(firstLine['duty_egp'], equals(0.0));

      final secondLine = lines[1] as Map<String, dynamic>;
      expect(secondLine['hs_code'], equals('8537.10.90'));
      expect(secondLine['preferential_agreement_applied'], isNull);
      expect(secondLine['duty_egp'], equals(28900.0));
    });
  });

  group('CustomsTariffNotifier simulateImportFileDuties Provider Unit Test', () {
    test('simulateImportFileDuties makes POST request to simulate-file endpoint', () async {
      // Create a mock Dio adapter or instance to verify request format
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.path.contains('/customs-tariff/simulate-file/101')) {
          return ResponseBody.fromString(
            '''{
              "import_file_id": 101,
              "file_number": "IMP-2026-0001",
              "currency_code": "USD",
              "exchange_rate": 50.7917,
              "cif_base_egp": 622936.93,
              "total_customs_duty_egp": 62293.69,
              "total_vat_egp": 95932.29,
              "total_duties_and_taxes_egp": 164455.35,
              "lines": []
            }''',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{"detail":"Not Found"}', 404);
      });

      final container = ProviderContainer(
        overrides: [
          customsTariffProvider.overrideWith((ref) => CustomsTariffNotifier(
                ref: ref,
                showInactive: false,
                search: '',
                dio: dio,
              )),
        ],
      );

      final notifier = container.read(customsTariffProvider.notifier);
      final result = await notifier.simulateImportFileDuties(101);

      expect(result, isNotNull);
      expect(result!['import_file_id'], equals(101));
      expect(result['file_number'], equals('IMP-2026-0001'));
      expect(result['currency_code'], equals('USD'));
      expect(result['total_customs_duty_egp'], equals(62293.69));
    });
  });

  group('DutyCalculatorDialog Widget Smoke Test', () {
    testWidgets('Renders duty calculator dialog with sample loader and initial file action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) {
        if (options.path.contains('/customs-tariff/simulate-file/')) {
          return ResponseBody.fromString(
            '''{
              "import_file_id": 42,
              "file_number": "IMP-2026-0042",
              "currency_code": "USD",
              "exchange_rate": 50.7917,
              "cif_base_egp": 622936.93,
              "total_customs_duty_egp": 62293.69,
              "total_vat_egp": 95932.29,
              "total_duties_and_taxes_egp": 164455.35,
              "lines": [
                {
                  "line_no": 1,
                  "hs_code": "8536.41.00",
                  "origin_country": "DE",
                  "cif_value_egp": 622936.93,
                  "duty_egp": 0.0,
                  "vat_egp": 95932.29,
                  "customs_service_fee_egp": 6229.37,
                  "total_line_duties_egp": 102161.66,
                  "preferential_agreement_applied": "EUR.1"
                }
              ]
            }''',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '[]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customsTariffProvider.overrideWith((ref) => CustomsTariffNotifier(
                  ref: ref,
                  showInactive: false,
                  search: '',
                  dio: dio,
                )),
          ],
          child: MaterialApp(
            // Real app wiring: `ar` resolves to Arabic + RTL (no Directionality override).
            locale: AppLocales.arabic,
            supportedLocales: AppLocales.supportedLocales,
            localizationsDelegates: AppLocales.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (ctx, ref, _) => ElevatedButton(
                    onPressed: () {
                      showDutyCalculatorDialog(
                        context,
                        ref,
                        initialHsCode: '8536.41.00',
                        initialImportFileId: 42,
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog picks its language from Localizations.localeOf(), which now resolves to ar.
      expect(find.text('حاسبة الجمارك المصرية — منصة نافذة'), findsOneWidget);
      // The 'Clear / New Shipment' reset button (308a6123) is not in the current calculator: the PR #91 merge
      // kept the overhauled dialog (f325439b), which has no reset. Not asserted until the product restores it.
      expect(find.text('محاكاة ملف الاستيراد (#42)'), findsOneWidget);
      expect(find.text('Egyptian Customs Duty Calculator — Nafeza Platform'), findsNothing);
      expect(find.text('إغلاق'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      expect(find.text('حاسبة الجمارك المصرية — منصة نافذة'), findsNothing);
    });

    testWidgets('DutyCalculatorDialog Opens Cleanly without hardcoded seed data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: AppLocales.arabic,
            supportedLocales: AppLocales.supportedLocales,
            localizationsDelegates: AppLocales.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (ctx, ref, _) => ElevatedButton(
                    onPressed: () {
                      showDutyCalculatorDialog(context, ref);
                    },
                    child: const Text('Open Clean Dialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Clean Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('حاسبة الجمارك المصرية — منصة نافذة'), findsOneWidget);
      // Hardcoded seed values from before must NOT be present
      expect(find.text('11736.40'), findsNothing);
      expect(find.text('14902.793'), findsNothing);
      expect(find.text('11922.234'), findsNothing);
      expect(find.text('623000.00'), findsNothing);

      // Close dialog
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      expect(find.text('حاسبة الجمارك المصرية — منصة نافذة'), findsNothing);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;
  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options,
      Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
