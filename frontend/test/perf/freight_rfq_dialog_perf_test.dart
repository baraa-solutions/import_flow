@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/widgets/freight_rfq_dialog.dart';

class _MockRfqHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;

    if (path.contains('freight-rfq')) {
      final rfqPayload = {
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-0001',
        'custom_file_number': 'Customs-File-2026-001',
        'company_name': 'El Ezz Steel Import Co.',
        'supplier_name': 'Shanghai Global Metals Ltd.',
        'incoterm_code': 'FOB',
        'commodity': 'Steel Coils & Sheets',
        'hs_codes_str': '7210.49.00',
        'shipment_mode': 'Sea FCL',
        'is_air': false,
        'recommended_containers': '2 x 40HC',
        'total_cbm': 48.5,
        'gross_weight_kg': 18500.0,
        'net_weight_kg': 18200.0,
        'volumetric_weight_kg': 8083.3,
        'chargeable_weight_kg': 18500.0,
        'total_packages': 120,
        'packages_breakdown': '20 Pallets (120 Cartons)',
        'stackability': 'Stackable',
        'pickup_address': 'No. 88 Logistics Park, Pudong, Shanghai',
        'port_of_loading': 'Shanghai Port, China',
        'port_of_discharge': 'El Dekheila Port, Alexandria, Egypt',
        'cargo_ready_date': '2026-09-15',
        'target_free_days': 21,
        'service_type': 'Direct Liner',
        'special_requirements': 'Provide 21 free demurrage detention days at POD',
        'email_subject': 'RFQ: Ocean Freight 2x40HC Shanghai to Alexandria - IMP-2026-0001',
        'email_body_template': 'Dear Shipping Line Team,\nPlease provide your best freight rate...',
        'whatsapp_text_template': 'Salam, RFQ Shanghai -> Alexandria 2x40HC ready 15 Sep',
      };
      return ResponseBody.fromString(
        jsonEncode(rfqPayload),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (path.contains('external-service-providers')) {
      final partners = [
        {
          'provider_id': 1,
          'provider_code': 'PART-001',
          'partner_name': 'Maersk Line Egypt',
          'partner_type': 'Shipping Line',
          'contact_person': 'Sherif',
          'phone': '01001234567',
          'email': 'maersk@example.com',
          'is_active': true,
        },
        {
          'provider_id': 2,
          'provider_code': 'PART-002',
          'partner_name': 'Kuehne + Nagel Logistics',
          'partner_type': 'Freight Forwarder',
          'contact_person': 'Tarek',
          'phone': '01009876543',
          'email': 'kn@example.com',
          'is_active': true,
        },
      ];
      return ResponseBody.fromString(
        jsonEncode(partners),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockRfqHttpAdapter();
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modal Dialog: FreightRfqDialog Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testDio = _createTestDio();

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      // Warm-up run to eliminate cold JIT compilation overhead
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(testDio),
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
          ],
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: FreightRfqDialog(
                  importFileId: 101,
                  importFileCode: 'IMP-2026-0001',
                  customFileNumber: 'Customs-File-2026-001',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Empty Destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 1; i <= 3; i++) {
        final navWatch = Stopwatch()..start();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(testDio),
              localeProvider.overrideWith((ref) {
                final n = LocaleNotifier();
                n.setLocale(const Locale('ar'));
                return n;
              }),
            ],
            child: const MaterialApp(
              home: AppLocalizationsProvider(
                locale: Locale('ar'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: FreightRfqDialog(
                    importFileId: 101,
                    importFileCode: 'IMP-2026-0001',
                    customFileNumber: 'Customs-File-2026-001',
                  ),
                ),
              ),
            ),
          ),
        );

        final firstFrameMs = navWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);

        await tester.pumpAndSettle();
        navWatch.stop();
        final settledMs = navWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);

        final outWatch = Stopwatch()..start();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Empty Destination')),
            ),
          ),
        );

        await tester.pumpAndSettle();
        outWatch.stop();
        final navOutMs = outWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);

        debugPrint('Run #$i: Nav-IN (First Frame): ${firstFrameMs}ms | Nav-IN (Settled): ${settledMs}ms | Nav-OUT: ${navOutMs}ms');
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) ~/ navInFirstFrameTimes.length;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) ~/ navInSettledTimes.length;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) ~/ navOutTimes.length;

      debugPrint('==================================================');
      debugPrint('MODAL (FreightRfqDialog) BENCHMARK RESULTS:');
      debugPrint('Average Nav-IN First Frame: ${avgFirstFrame}ms');
      debugPrint('Average Nav-IN Settled:     ${avgSettled}ms');
      debugPrint('Average Nav-OUT (Disposal): ${avgNavOut}ms');
      debugPrint('==================================================');

      expect(avgFirstFrame, lessThanOrEqualTo(300));
      expect(avgSettled, lessThanOrEqualTo(350));
      expect(avgNavOut, lessThanOrEqualTo(150));
    });
  });
}
